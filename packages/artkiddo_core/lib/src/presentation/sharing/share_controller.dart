import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contracts/gallery_sharing.dart';
import '../../domain/action_result.dart';
import '../../domain/app_failure.dart';
import '../../domain/child.dart';
import '../async_action.dart';

import '../children/children_providers.dart';

import '../gallery/gallery_providers.dart';
import '../providers/core_providers.dart';

export '../../contracts/gallery_sharing.dart' show ShareLink, SharingService;

/// Provider for [SharingService], defaulting to [NoSharingService].
/// Compositions with [AppCapabilities.webGalleryLinks] must override this provider.
final sharingServiceProvider = Provider<SharingService>((ref) {
  return const NoSharingService();
});

/// Optional backup action supplied by a composition with web gallery links.
typedef ShareBackup = Future<ActionResult<void>> Function(String childId);

final shareBackupProvider = Provider<ShareBackup?>((ref) => null);

/// Clock used to decide whether a previously created link is still usable.
final shareClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Share flow steps.
/// The sharing flow's steps.
enum ShareStep { signedOut, choice, linkReady, error, childMissing }

class ShareArgs {
  final String childId;
  final String childName;
  // The choice screen shows a second, separately-labelled block
  // ("Send this image") only when share was entered from the artwork
  // detail for a specific piece. Non-null exactly in that case.
  final VoidCallback? sendImage;

  const ShareArgs({
    required this.childId,
    required this.childName,
    this.sendImage,
  });

  // Riverpod families key by `==`/`hashCode`. `sendImage` is deliberately
  // excluded: two closures over the same (childId, name) must still hit
  // the same controller instance.
  @override
  bool operator ==(Object other) =>
      other is ShareArgs &&
      other.childId == childId &&
      other.childName == childName;
  @override
  int get hashCode => Object.hash(childId, childName);
}

class ShareState {
  final ShareStep step;
  final List<ShareLink> links;
  final AsyncAction create;
  final AsyncAction revoke;
  final AsyncAction backup;
  final bool childHasSyncedArtworks;
  final bool loading;
  // The sheet must show the *current* child name even when re-opened
  // through a pending intent with an empty placeholder — resolved
  // here from the repository instead of trusting `args.childName`
  // verbatim.
  final String? resolvedChildName;
  final bool offline;
  final bool newLinkIncludeAudio;
  final Set<String> updatingLinkIds;

  const ShareState({
    this.step = ShareStep.signedOut,
    this.links = const [],
    this.create = const ActionIdle(),
    this.revoke = const ActionIdle(),
    this.backup = const ActionIdle(),
    this.childHasSyncedArtworks = true,
    this.loading = true,
    this.resolvedChildName,
    this.offline = false,
    this.newLinkIncludeAudio = false,
    this.updatingLinkIds = const {},
  });

  ShareState copyWith({
    ShareStep? step,
    List<ShareLink>? links,
    AsyncAction? create,
    AsyncAction? revoke,
    AsyncAction? backup,
    bool? childHasSyncedArtworks,
    bool? loading,
    String? resolvedChildName,
    bool? offline,
    bool? newLinkIncludeAudio,
    Set<String>? updatingLinkIds,
  }) {
    return ShareState(
      step: step ?? this.step,
      links: links ?? this.links,
      create: create ?? this.create,
      revoke: revoke ?? this.revoke,
      backup: backup ?? this.backup,
      childHasSyncedArtworks:
          childHasSyncedArtworks ?? this.childHasSyncedArtworks,
      loading: loading ?? this.loading,
      resolvedChildName: resolvedChildName ?? this.resolvedChildName,
      offline: offline ?? this.offline,
      newLinkIncludeAudio: newLinkIncludeAudio ?? this.newLinkIncludeAudio,
      updatingLinkIds: updatingLinkIds ?? this.updatingLinkIds,
    );
  }
}

class ShareController extends Notifier<ShareState> {
  ShareController(this.args);
  final ShareArgs args;

  @override
  ShareState build() {
    Future.microtask(_load);
    return const ShareState();
  }

  Future<void> _load() async {
    // Re-derive the child's current name from the repository — never
    // trust `args.childName` verbatim, which is an empty placeholder when
    // share is reopened via a pending intent (the controller is keyed
    // only by `childId`/`childName`, so a placeholder name at
    // construction never gets corrected otherwise).
    final children = await ref
        .read(childrenRepositoryProvider)
        .watchAll()
        .first;
    final child = children.where((c) => c.id == args.childId).firstOrNull;
    if (child == null) {
      state = state.copyWith(step: ShareStep.childMissing, loading: false);
      return;
    }
    state = state.copyWith(resolvedChildName: child.name);

    final signedIn = ref.read(sessionEmailProvider) != null;
    if (!signedIn) {
      state = state.copyWith(step: ShareStep.signedOut, loading: false);
      return;
    }

    final hasSynced = await _childHasSyncedArtworks();

    final service = ref.read(sharingServiceProvider);
    final result = await service.listLinks(args.childId);
    switch (result) {
      case ActionSuccess(value: final links):
        // The backend keeps a revoked link's row (audit trail) instead of
        // deleting it, so a revoked link is still returned by `listLinks`
        // — filtered out here so the "existing links" panel keeps its
        // intended meaning: only links a member could still use today.
        final now = ref.read(shareClockProvider)();
        final visibleLinks = links
            .where((l) => !l.revoked && l.expiresAt.isAfter(now))
            .toList();
        state = state.copyWith(
          links: visibleLinks,
          childHasSyncedArtworks: hasSynced,
          step: visibleLinks.isNotEmpty
              ? ShareStep.linkReady
              : ShareStep.choice,
          loading: false,
          offline: false,
        );
      case ActionFailed(failure: final f):
        state = state.copyWith(
          step: ShareStep.choice,
          childHasSyncedArtworks: hasSynced,
          loading: false,
          offline: f is NetworkFailure,
        );
      case ActionCancelled():
        state = state.copyWith(step: ShareStep.choice, loading: false);
    }
  }

  void setNewLinkIncludeAudio(bool value) {
    state = state.copyWith(newLinkIncludeAudio: value);
  }

  Future<bool> _childHasSyncedArtworks() async {
    final artworks = await ref
        .read(artworksRepositoryProvider)
        .watch(childId: args.childId)
        .first;
    return artworks.any((artwork) => artwork.syncState == SyncState.synced);
  }

  /// Starts backup and checks this child's persisted sync state afterwards.
  /// A partial household backup may still make this child shareable.
  Future<ActionResult<void>> backupNow() async {
    if (state.backup.isBusy) return const ActionCancelled();
    final backup = ref.read(shareBackupProvider);
    if (backup == null) {
      const failure = UnavailableFailure();
      state = state.copyWith(backup: const ActionError(failure));
      return const ActionFailed(failure);
    }
    state = state.copyWith(backup: const ActionBusy());
    ActionResult<void> result;
    try {
      result = await backup(args.childId);
      final hasSynced = await _childHasSyncedArtworks();
      if (hasSynced) {
        state = state.copyWith(
          backup: const ActionDone(),
          childHasSyncedArtworks: true,
          offline: false,
        );
        return const ActionSuccess(null);
      }
    } catch (error, stack) {
      result = ActionFailed(UnknownFailure(cause: error, stack: stack));
    }
    final failure = switch (result) {
      ActionFailed(failure: final failure) => failure,
      _ => const ServiceFailure(),
    };
    state = state.copyWith(
      backup: ActionError(failure),
      offline: failure is NetworkFailure,
    );
    return ActionFailed(failure);
  }

  Future<ActionResult<ShareLink>> createLink() async {
    // Only `busy` blocks a new command — retry must stay live after a
    // failed create.
    if (state.create.isBusy) return const ActionCancelled();
    if (!state.childHasSyncedArtworks || state.backup.isBusy) {
      return const ActionCancelled();
    }

    state = state.copyWith(create: const ActionBusy());
    final service = ref.read(sharingServiceProvider);
    final result = await service.createLink(
      args.childId,
      includeAudio: state.newLinkIncludeAudio,
    );
    switch (result) {
      case ActionSuccess(value: final link):
        state = state.copyWith(
          create: const ActionDone(),
          // At most 5, most recent first.
          links: [link, ...state.links].take(5).toList(),
          step: ShareStep.linkReady,
        );
      case ActionFailed(failure: final f):
        state = state.copyWith(create: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(create: const ActionIdle());
    }
    return result;
  }

  Future<ActionResult<void>> updateLinkIncludeAudio(
    String linkId,
    bool includeAudio,
  ) async {
    if (state.updatingLinkIds.contains(linkId)) return const ActionCancelled();
    state = state.copyWith(updatingLinkIds: {...state.updatingLinkIds, linkId});
    final service = ref.read(sharingServiceProvider);
    final result = await service.updateIncludeAudio(linkId, includeAudio);
    final nextUpdating = state.updatingLinkIds
        .where((id) => id != linkId)
        .toSet();
    switch (result) {
      case ActionSuccess():
        final updatedLinks = state.links.map((link) {
          if (link.id == linkId) {
            return link.copyWith(includeAudio: includeAudio);
          }
          return link;
        }).toList();
        state = state.copyWith(
          links: updatedLinks,
          updatingLinkIds: nextUpdating,
        );
      case ActionFailed():
        state = state.copyWith(updatingLinkIds: nextUpdating);
      case ActionCancelled():
        state = state.copyWith(updatingLinkIds: nextUpdating);
    }
    return result;
  }

  Future<ActionResult<void>> revokeLink(String linkId) async {
    // Same fix as createLink — a failed revoke must stay retryable.
    if (state.revoke.isBusy) return const ActionCancelled();
    state = state.copyWith(revoke: const ActionBusy());
    final service = ref.read(sharingServiceProvider);
    final result = await service.revokeLink(linkId);
    switch (result) {
      case ActionSuccess():
        // The link is only dropped from the list *after* the service
        // confirms the revoke — never optimistically.
        final remaining = state.links.where((l) => l.id != linkId).toList();
        state = state.copyWith(
          revoke: const ActionDone(),
          links: remaining,
          step: remaining.isEmpty ? ShareStep.choice : ShareStep.linkReady,
        );
      case ActionFailed(failure: final f):
        // The link stays listed, and the failure is now surfaced.
        state = state.copyWith(revoke: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(revoke: const ActionIdle());
    }
    return result;
  }

  void consumeRevokeError() =>
      state = state.copyWith(revoke: const ActionIdle());

  /// Called after coming back signed-in from account settings via a
  /// pending share intent.
  Future<void> refreshAfterSignIn() async {
    state = state.copyWith(loading: true);
    await _load();
  }
}

final shareControllerProvider =
    NotifierProvider.family<ShareController, ShareState, ShareArgs>(
      ShareController.new,
    );
