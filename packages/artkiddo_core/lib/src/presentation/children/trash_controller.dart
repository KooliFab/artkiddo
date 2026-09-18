import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../async_action.dart';
import '../config/app_capabilities.dart';
import '../../domain/app_failure.dart';
import '../../local/logging/log.dart';
import '../providers/core_providers.dart';
import '../../domain/action_result.dart';
import '../../local/repositories/trash_repository.dart';

class TrashState {
  final bool loading;
  final List<TrashedArtwork> items;
  final bool isParent;
  final String? foyerId;
  final AppFailure? loadError;
  final AsyncAction restore;
  final AsyncAction purge;
  final AsyncAction purgeAll;

  /// The item currently targeted by [restore]/[purge] — a list can
  /// show several rows at once, so the busy state needs to say
  /// *which* row, not just whether one is busy.
  final String? busyItemId;

  const TrashState({
    this.loading = true,
    this.items = const [],
    this.isParent = false,
    this.foyerId,
    this.loadError,
    this.restore = const ActionIdle(),
    this.purge = const ActionIdle(),
    this.purgeAll = const ActionIdle(),
    this.busyItemId,
  });

  TrashState copyWith({
    bool? loading,
    List<TrashedArtwork>? items,
    bool? isParent,
    String? foyerId,
    AppFailure? loadError,
    bool clearLoadError = false,
    AsyncAction? restore,
    AsyncAction? purge,
    AsyncAction? purgeAll,
    String? busyItemId,
    bool clearBusyItemId = false,
  }) {
    return TrashState(
      loading: loading ?? this.loading,
      items: items ?? this.items,
      isParent: isParent ?? this.isParent,
      foyerId: foyerId ?? this.foyerId,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      restore: restore ?? this.restore,
      purge: purge ?? this.purge,
      purgeAll: purgeAll ?? this.purgeAll,
      busyItemId: clearBusyItemId ? null : (busyItemId ?? this.busyItemId),
    );
  }
}

/// Loads and acts on the local trash. `isParent`/`foyerId` stay part
/// of [TrashState]'s shape for a shared-household trash composition;
/// this controller itself only ever operates on
/// [TrashCapability.local] and rejects any other capability.
class TrashController extends Notifier<TrashState> {
  @override
  TrashState build() {
    Future.microtask(_load);
    return const TrashState();
  }

  Future<void> _load() async {
    final capabilities = ref.read(appCapabilitiesProvider);
    final repository = ref.read(trashRepositoryProvider);
    if (capabilities.trash != TrashCapability.local) {
      throw StateError('The public core only supports local trash');
    }
    state = state.copyWith(loading: true, isParent: true, foyerId: null);
    // Opening the screen is the second deterministic purge trigger
    // after startup. The repository keeps the database write
    // authoritative and journals any file cleanup that needs another
    // retry.
    await repository.purgeExpired();
    final result = await repository.listTrash();
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

  Future<void> refresh() => _load();

  Future<void> restore(String masterpieceId) async {
    if (state.restore.isBusy) return;
    state = state.copyWith(
      restore: const ActionBusy(),
      busyItemId: masterpieceId,
    );
    final result = await ref
        .read(trashRepositoryProvider)
        .restore(masterpieceId);
    switch (result) {
      case ActionSuccess():
        final remaining = state.items
            .where((i) => i.id != masterpieceId)
            .toList();
        state = state.copyWith(
          restore: const ActionDone(),
          items: remaining,
          clearBusyItemId: true,
        );
      case ActionFailed(failure: final f):
        state = state.copyWith(restore: ActionError(f), clearBusyItemId: true);
      case ActionCancelled():
        state = state.copyWith(
          restore: const ActionIdle(),
          clearBusyItemId: true,
        );
    }
  }

  Future<void> purge(String masterpieceId) async {
    if (state.purge.isBusy) return;
    state = state.copyWith(
      purge: const ActionBusy(),
      busyItemId: masterpieceId,
    );
    final result = await ref.read(trashRepositoryProvider).purge(masterpieceId);
    switch (result) {
      case ActionSuccess():
        final remaining = state.items
            .where((i) => i.id != masterpieceId)
            .toList();
        state = state.copyWith(
          purge: const ActionDone(),
          items: remaining,
          clearBusyItemId: true,
        );
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
    if (state.purgeAll.isBusy) return;
    state = state.copyWith(purgeAll: const ActionBusy());
    final result = await ref.read(trashRepositoryProvider).purgeAll();
    switch (result) {
      case ActionSuccess():
        state = state.copyWith(purgeAll: const ActionDone(), items: const []);
      case ActionFailed(failure: final f):
        state = state.copyWith(purgeAll: ActionError(f));
      case ActionCancelled():
        state = state.copyWith(purgeAll: const ActionIdle());
    }
  }
}

final trashControllerProvider = NotifierProvider<TrashController, TrashState>(
  TrashController.new,
);
