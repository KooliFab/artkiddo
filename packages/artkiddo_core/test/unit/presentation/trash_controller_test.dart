import 'dart:async';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Family implements FamilyApi {
  @override
  Future<FamilyMembership?> currentMembership() async =>
      const FamilyMembership(familyId: 'family', role: FamilyMemberRole.parent);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineAfterFirstRead implements FamilyApi {
  bool offline;
  _OfflineAfterFirstRead({required this.offline});
  @override
  Future<FamilyMembership?> currentMembership() async => offline
      ? throw StateError('offline')
      : const FamilyMembership(
          familyId: 'family',
          role: FamilyMemberRole.parent,
        );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Trash implements TrashRepository {
  List<TrashedArtwork> items = [];
  int reads = 0;
  String? scope;
  @override
  Future<ActionResult<List<TrashedArtwork>>> listTrash({
    String? scopeId,
  }) async {
    reads++;
    scope = scopeId;
    return ActionSuccess(List.of(items));
  }

  @override
  Future<ActionResult<int>> purgeExpired({DateTime? now}) async =>
      const ActionSuccess(0);
  @override
  Future<ActionResult<void>> restore(String id) async {
    items.removeWhere((item) => item.id == id);
    return const ActionSuccess(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TrashedArtwork photo(String id) => TrashedArtwork(
    id: id,
    childId: 'child',
    childName: 'Lou',
    deletedAt: DateTime(2026),
    purgeAt: DateTime(2026, 2),
  );

  test(
    'refresh flushes own deletions first and discovers another parent deletion',
    () async {
      final trash = _Trash();
      var syncs = 0;
      final container = ProviderContainer(
        overrides: [
          appCapabilitiesProvider.overrideWithValue(AppCapabilities.cloud),
          trashRepositoryProvider.overrideWithValue(trash),
          familyApiProvider.overrideWithValue(_Family()),
          familyConvergenceProvider.overrideWithValue(() async {
            syncs++;
            trash.items = [photo('deleted-by-other-parent')];
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(trashControllerProvider.notifier);
      await controller.refresh();
      expect(syncs, 1);
      expect(trash.scope, 'family');
      expect(
        container.read(trashControllerProvider).items.single.id,
        'deleted-by-other-parent',
      );
      trash.items = [];
      await controller.refresh(quiet: true);
      expect(trash.reads, 2);
      expect(syncs, 2);
      expect(container.read(trashControllerProvider).isParent, true);
    },
  );

  test('local trash never reads family or convergence providers', () async {
    final trash = _Trash()..items = [photo('local')];
    final container = ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(AppCapabilities.local),
        trashRepositoryProvider.overrideWithValue(trash),
        familyApiProvider.overrideWith(
          (ref) => throw StateError('remote provider'),
        ),
        familyConvergenceProvider.overrideWith(
          (ref) => throw StateError('remote provider'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(trashControllerProvider.notifier).refresh();
    expect(container.read(trashControllerProvider).items.single.id, 'local');
    expect(trash.scope, isNull);
  });

  test(
    'overlapping refresh requests share one convergence and list read',
    () async {
      final gate = Completer<void>();
      final trash = _Trash();
      var syncs = 0;
      final container = ProviderContainer(
        overrides: [
          appCapabilitiesProvider.overrideWithValue(AppCapabilities.cloud),
          trashRepositoryProvider.overrideWithValue(trash),
          familyApiProvider.overrideWithValue(_Family()),
          familyConvergenceProvider.overrideWithValue(() async {
            syncs++;
            await gate.future;
          }),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(trashControllerProvider.notifier);
      final first = controller.refresh();
      final second = controller.refresh(quiet: true);
      gate.complete();
      await Future.wait([first, second]);
      expect(syncs, 1);
      expect(trash.reads, 1);
    },
  );

  test('parent actions are unavailable while the role was never read, and '
      'available once it is known as parent', () async {
    final family = _OfflineAfterFirstRead(offline: true);
    final trash = _Trash()..items = [photo('a')];
    final container = ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(AppCapabilities.cloud),
        trashRepositoryProvider.overrideWithValue(trash),
        familyApiProvider.overrideWithValue(family),
        familyConvergenceProvider.overrideWithValue(() async {}),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(trashControllerProvider.notifier);
    await controller.refresh();
    expect(container.read(trashControllerProvider).items, hasLength(1));
    expect(container.read(trashControllerProvider).isParent, false);

    family.offline = false;
    await controller.refresh(quiet: true);
    expect(container.read(trashControllerProvider).isParent, true);

    family.offline = true; // the last known role is kept
    await controller.refresh(quiet: true);
    expect(container.read(trashControllerProvider).isParent, true);
  });
}
