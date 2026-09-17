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

/// Share flow steps.
enum ShareStep { signedOut, choice, linkReady, error, childMissing }

class ShareArgs {
  final String childId;
  final String childName;
  final VoidCallback? sendImage;

  const ShareArgs({required this.childId, required this.childName, this.sendImage});

  @override
  bool operator ==(Object other) => other is ShareArgs && other.childId == childId && other.childName == childName;
  @override
  int get hashCode => Object.hash(childId, childName);
}

class ShareState {
  final ShareStep step;
  final List<ShareLink> links;
  final AsyncAction create;
  final AsyncAction revoke;
  final bool childHasSyncedArtworks;
  final bool loading;
  final String? resolvedChildName;
  final bool offline;
  final bool newLinkIncludeAudio;
  final Set<String> updatingLinkIds;

  const ShareState({
    this.step = ShareStep.signedOut,
    this.links = const [],
    this.create = const ActionIdle(),
    this.revoke = const ActionIdle(),
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
      childHasSyncedArtworks: childHasSyncedArtworks ?? this.childHasSyncedArtworks,
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
    final children = await ref.read(childrenRepositoryProvider).watchAll().first;
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

    final repo = ref.read(masterpiecesRepositoryProvider);
    final masterpieces = await repo.watch(childId: args.childId).first;
    final hasSynced = masterpieces.any((m) => m.syncState == SyncState.synced);

    final service = ref.read(sharingServiceProvider);
    final result = await service.listLinks(args.childId);
    switch (result) {
      case ActionSuccess(value: final links):
        final visibleLinks = links.where((l) => !l.revoked).toList();
        state = state.copyWith(
          links: visibleLinks,
          childHasSyncedArtworks: hasSynced,
          step: visibleLinks.isNotEmpty ? ShareStep.linkReady : ShareStep.choice,
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

  Future<ActionResult<ShareLink>> createLink() async {
    if (state.create.isBusy) return const ActionCancelled();
    if (!state.childHasSyncedArtworks) return const ActionCancelled();

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
    state = state.copyWith(
      updatingLinkIds: {...state.updatingLinkIds, linkId},
    );
    final service = ref.read(sharingServiceProvider);
    final result = await service.updateIncludeAudio(linkId, includeAudio);
    final nextUpdating = state.updatingLinkIds.where((id) => id != linkId).toSet();
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
    if (state.revoke.isBusy) return const ActionCancelled();
    state = state.copyWith(revoke: const ActionBusy());
    final service = ref.read(sharingServiceProvider);
    final result = await service.revokeLink(linkId);
    switch (result) {
      case ActionSuccess():
        final remaining = state.links.where((l) => l.id != linkId).toList();
        state = state.copyWith(
          revoke: const ActionDone(),
          links: remaining,
          step: remaining.isEmpty ? ShareStep.choice : ShareStep.linkReady,
        );
      case ActionFailed(failure: final f):
        state = state.copyWith(revoke: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(revoke: const ActionIdle());
    }
    return result;
  }

  void consumeRevokeError() => state = state.copyWith(revoke: const ActionIdle());

  Future<void> refreshAfterSignIn() async {
    state = state.copyWith(loading: true);
    await _load();
  }
}

final shareControllerProvider = NotifierProvider.family<ShareController, ShareState, ShareArgs>(ShareController.new);
