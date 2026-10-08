import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../async_action.dart';
import '../config/app_capabilities.dart';
import '../../domain/app_failure.dart';
import '../../local/logging/log.dart';
import '../providers/core_providers.dart';
import '../../domain/action_result.dart';
import '../../local/repositories/trash_repository.dart';
import '../family/family_controller.dart';

class TrashState {
  final bool loading;
  final List<TrashedArtwork> items;
  final bool isParent;
  final String? familyId;
  final AppFailure? loadError;
  final AsyncAction restore;
  final AsyncAction purge;
  final AsyncAction purgeAll;

  /// The item currently targeted by [restore]/[purge] — a list can
  /// show several rows at once, so the busy state needs to say
  /// *which* row, not just whether one is busy.
  final String? busyItemId;

  /// Counts the restores that left an artwork existing on this phone only
  /// (purged remotely). The screen reacts to each increase by saying so.
  final int onlyHereRestores;

  const TrashState({
    this.loading = true,
    this.items = const [],
    this.isParent = false,
    this.familyId,
    this.loadError,
    this.restore = const ActionIdle(),
    this.purge = const ActionIdle(),
    this.purgeAll = const ActionIdle(),
    this.busyItemId,
    this.onlyHereRestores = 0,
  });

  TrashState copyWith({
    bool? loading,
    List<TrashedArtwork>? items,
    bool? isParent,
    String? familyId,
    AppFailure? loadError,
    bool clearLoadError = false,
    AsyncAction? restore,
    AsyncAction? purge,
    AsyncAction? purgeAll,
    String? busyItemId,
    bool clearBusyItemId = false,
    int? onlyHereRestores,
  }) {
    return TrashState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      isParent: isParent ?? this.isParent,
      familyId: familyId ?? this.familyId,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      restore: restore ?? this.restore,
      purge: purge ?? this.purge,
      purgeAll: purgeAll ?? this.purgeAll,
      busyItemId: clearBusyItemId ? null : (busyItemId ?? this.busyItemId),
      onlyHereRestores: onlyHereRestores ?? this.onlyHereRestores,
    );
  }
}

/// Loads and acts on the trash. Supports both [TrashCapability.local]
/// and [TrashCapability.sharedRemote].
class TrashController extends Notifier<TrashState> {
  Future<void>? _refreshing;
  @override
  TrashState build() {
    Future.microtask(refresh);
    return const TrashState();
  }

  Future<void> _load({bool quiet = false}) async {
    final capabilities = ref.read(appCapabilitiesProvider);
    final repository = ref.read(trashRepositoryProvider);

    if (capabilities.trash == TrashCapability.local) {
      state = state.copyWith(loading: true, isParent: true, familyId: null);
      // Opening the screen is the second deterministic purge trigger
      // after startup. The repository keeps the database write
      // authoritative and journals any file cleanup that needs another
      // retry.
      await repository.purgeExpired();
      final result = await repository.listTrash();
      _applyListResult(result);
      return;
    }

    final FamilyMembership? membership;
    try {
      if (ref.read(appCapabilitiesProvider).remoteBackup) {
        // Flush pending deletions before reading the shared trash.
        await ref.read(familyConvergenceProvider)();
      }
      membership = await ref.read(familyApiProvider).currentMembership();
    } catch (error) {
      // Offline: the trash of this device stays usable. Its deletions are
      // queued and reach the remote side once it is reachable again. The
      // last known role is kept; without one (never read) the parent
      // actions stay unavailable.
      Log.w(
        'Corbeille partagée injoignable, corbeille locale : $error',
        'Trash',
      );
      state = state.copyWith(
        loading: quiet ? state.loading : true,
        isParent: state.familyId == null ? false : state.isParent,
      );
      _applyListResult(await repository.listTrash(scopeId: state.familyId));
      return;
    }
    if (membership == null) {
      state = const TrashState(loading: false);
      return;
    }

    state = state.copyWith(
      loading: quiet ? state.loading : true,
      familyId: membership.familyId,
      isParent: membership.role == FamilyMemberRole.parent,
    );

    final result = await repository.listTrash(scopeId: membership.familyId);
    _applyListResult(result);
  }

  void _applyListResult(ActionResult<List<TrashedArtwork>> result) {
    switch (result) {
      case ActionSuccess(value: final items):
        Log.d('${items.length} œuvre(s) en Corbeille', 'Trash');
        state = state.copyWith(
          loading: false,
          items: items,
          clearLoadError: true,
        );
      case ActionFailed(failure: final f):
        state = state.copyWith(loading: false, loadError: f);
      case ActionCancelled():
        state = state.copyWith(loading: false);
    }
  }

  Future<void> refresh({bool quiet = false}) {
    if (state.restore.isBusy || state.purge.isBusy || state.purgeAll.isBusy) {
      return Future.value();
    }
    final active = _refreshing;
    if (active != null) return active;
    final work = _refreshSafely(quiet: quiet);
    _refreshing = work;
    return work.whenComplete(() {
      if (identical(_refreshing, work)) _refreshing = null;
    });
  }

  Future<void> _refreshSafely({required bool quiet}) async {
    try {
      await _load(quiet: quiet);
    } catch (error, stack) {
      Log.e('Trash refresh failed', error, stack, 'Trash');
      state = state.copyWith(
        loading: false,
        loadError: NetworkFailure(cause: error, stack: stack),
      );
    }
  }

  Future<void> restore(String artworkId) async {
    if (state.restore.isBusy) return;
    state = state.copyWith(restore: const ActionBusy(), busyItemId: artworkId);
    await _refreshing;
    final onlyHere = state.items.any(
      (i) => i.id == artworkId && i.existsOnlyHere,
    );
    final result = await ref.read(trashRepositoryProvider).restore(artworkId);
    switch (result) {
      case ActionSuccess():
        final remaining = state.items.where((i) => i.id != artworkId).toList();
        state = state.copyWith(
          restore: const ActionDone(),
          items: remaining,
          clearBusyItemId: true,
          onlyHereRestores: onlyHere
              ? state.onlyHereRestores + 1
              : state.onlyHereRestores,
        );
        // Remote restore needs a prompt sync so the shared gallery
        // reappears immediately. Local restore already changed the durable
        // Drift row; it must not construct or read a cloud provider.
        if (ref.read(appCapabilitiesProvider).remoteBackup) {
          unawaited(ref.read(familyConvergenceProvider)());
        }
      case ActionFailed(failure: final f):
        state = state.copyWith(restore: ActionError(f), clearBusyItemId: true);
      case ActionCancelled():
        state = state.copyWith(
          restore: const ActionIdle(),
          clearBusyItemId: true,
        );
    }
  }

  Future<void> purge(String artworkId) async {
    if (state.purge.isBusy) return;
    state = state.copyWith(purge: const ActionBusy(), busyItemId: artworkId);
    await _refreshing;
    final result = await ref.read(trashRepositoryProvider).purge(artworkId);
    switch (result) {
      case ActionSuccess():
        final remaining = state.items.where((i) => i.id != artworkId).toList();
        state = state.copyWith(
          purge: const ActionDone(),
          items: remaining,
          clearBusyItemId: true,
        );
        _sendDeletions();
      case ActionFailed(failure: final f):
        state = state.copyWith(purge: ActionError(f), clearBusyItemId: true);
      case ActionCancelled():
        state = state.copyWith(
          purge: const ActionIdle(),
          clearBusyItemId: true,
        );
    }
  }

  Future<void> purgeAll() async {
    final familyId = state.familyId;
    final local =
        ref.read(appCapabilitiesProvider).trash == TrashCapability.local;
    if (state.purgeAll.isBusy) return;
    state = state.copyWith(purgeAll: const ActionBusy());
    await _refreshing;
    final result = await ref
        .read(trashRepositoryProvider)
        .purgeAll(scopeId: local ? null : familyId);
    switch (result) {
      case ActionSuccess():
        state = state.copyWith(purgeAll: const ActionDone(), items: const []);
        _sendDeletions();
      case ActionFailed(failure: final f):
        state = state.copyWith(purgeAll: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(purgeAll: const ActionIdle());
    }
  }

  /// A deletion queued by the remote trash goes out at once when it can; it
  /// stays queued otherwise.
  void _sendDeletions() {
    if (ref.read(appCapabilitiesProvider).trash == TrashCapability.local) {
      return;
    }
    if (!ref.read(appCapabilitiesProvider).remoteBackup) return;
    unawaited(
      Future.sync(ref.read(familyConvergenceProvider)).catchError(
        (Object error, StackTrace stack) =>
            Log.e('Envoi des suppressions différé', error, stack, 'Trash'),
      ),
    );
  }
}

final trashControllerProvider = NotifierProvider<TrashController, TrashState>(
  TrashController.new,
);
