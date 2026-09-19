import 'dart:io';
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

class _FakeSharingService implements SharingService {
  List<ShareLink> links = [];
  ActionResult<List<ShareLink>>? listResult;
  bool lastCreatedIncludeAudio = false;
  String? lastUpdatedLinkId;
  bool? lastUpdatedIncludeAudio;

  @override
  Future<ActionResult<List<ShareLink>>> listLinks(String childId) async {
    return listResult ?? ActionSuccess(links);
  }

  @override
  Future<ActionResult<ShareLink>> createLink(
    String childId, {
    bool includeAudio = false,
  }) async {
    lastCreatedIncludeAudio = includeAudio;
    final link = ShareLink(
      id: 'link-${links.length + 1}',
      url: 'https://artkiddo.app/gallery/token-${links.length + 1}',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      revoked: false,
      includeAudio: includeAudio,
    );
    links = [link, ...links];
    return ActionSuccess(link);
  }

  @override
  Future<ActionResult<void>> updateIncludeAudio(
    String linkId,
    bool includeAudio,
  ) async {
    lastUpdatedLinkId = linkId;
    lastUpdatedIncludeAudio = includeAudio;
    links = links.map((l) {
      if (l.id == linkId) {
        return l.copyWith(includeAudio: includeAudio);
      }
      return l;
    }).toList();
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> revokeLink(String linkId) async {
    links = links.where((l) => l.id != linkId).toList();
    return const ActionSuccess(null);
  }
}

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;
  late _FakeSharingService sharingService;
  late ShareBackup backupAction;
  late ProviderContainer container;

  late String testChildId;
  late ShareArgs args;

  Future<void> initContainer() async {
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
        sharingServiceProvider.overrideWith((ref) => sharingService),
        shareBackupProvider.overrideWith((ref) => backupAction),
        sessionEmailProvider.overrideWith((ref) => 'parent@example.com'),
      ],
    );

    final childrenRepo = container.read(childrenRepositoryProvider);
    final childRes = await childrenRepo.create(
      name: 'Alice',
      birthDate: DateTime(2020, 1, 1),
    );
    testChildId = (childRes as ActionSuccess<String>).value;
    args = ShareArgs(childId: testChildId, childName: 'Alice');

    final masterRepo = container.read(masterpiecesRepositoryProvider);
    final dummyFile = File(p.join(tempRoot.path, 'dummy.jpg'));
    await dummyFile.writeAsBytes([1, 2, 3]);
    final masterpieceRes = await masterRepo.create(
      childId: testChildId,
      sourceImageFile: dummyFile,
      addedAt: DateTime.now(),
    );
    final masterpieceId = (masterpieceRes as ActionSuccess<String>).value;
    // Mark synced
    await masterRepo.markSynced(masterpieceId);
  }

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp(
      'artkiddo_share_controller_test_',
    );
    final docsDir = Directory(p.join(tempRoot.path, 'docs'));
    await docsDir.create(recursive: true);
    db = AppDatabase.forTesting(
      NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))),
    );
    vault = LocalVault(documentsDirProvider: () async => docsDir);
    sharingService = _FakeSharingService();
    backupAction = (childId) async => const ActionSuccess(null);

    // Insert child and a synced masterpiece
    await initContainer();
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  test(
    'setNewLinkIncludeAudio updates newLinkIncludeAudio flag in state',
    () async {
      final controller = container.read(shareControllerProvider(args).notifier);
      // Wait for initial load
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(shareControllerProvider(args)).newLinkIncludeAudio,
        isFalse,
      );

      controller.setNewLinkIncludeAudio(true);
      expect(
        container.read(shareControllerProvider(args)).newLinkIncludeAudio,
        isTrue,
      );

      controller.setNewLinkIncludeAudio(false);
      expect(
        container.read(shareControllerProvider(args)).newLinkIncludeAudio,
        isFalse,
      );
    },
  );

  test('createLink passes includeAudio to SharingService', () async {
    final controller = container.read(shareControllerProvider(args).notifier);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    controller.setNewLinkIncludeAudio(true);
    final result = await controller.createLink();

    expect(result, isA<ActionSuccess<ShareLink>>());
    expect(sharingService.lastCreatedIncludeAudio, isTrue);

    final state = container.read(shareControllerProvider(args));
    expect(state.links.length, 1);
    expect(state.links.first.includeAudio, isTrue);
  });

  test(
    'updateLinkIncludeAudio updates existing link in state and calls SharingService',
    () async {
      final controller = container.read(shareControllerProvider(args).notifier);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Create a link with audio = false
      controller.setNewLinkIncludeAudio(false);
      await controller.createLink();

      final linkId = container
          .read(shareControllerProvider(args))
          .links
          .first
          .id;
      expect(
        container.read(shareControllerProvider(args)).links.first.includeAudio,
        isFalse,
      );

      // Toggle to true
      final result = await controller.updateLinkIncludeAudio(linkId, true);
      expect(result, isA<ActionSuccess<void>>());
      expect(sharingService.lastUpdatedLinkId, linkId);
      expect(sharingService.lastUpdatedIncludeAudio, isTrue);

      final updatedLink = container
          .read(shareControllerProvider(args))
          .links
          .first;
      expect(updatedLink.includeAudio, isTrue);
    },
  );

  test('expired links are excluded at the exact expiry boundary', () async {
    final now = DateTime.utc(2026, 9, 19);
    container.dispose();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
        sharingServiceProvider.overrideWith((ref) => sharingService),
        sessionEmailProvider.overrideWith((ref) => 'parent@example.com'),
        shareClockProvider.overrideWithValue(() => now),
      ],
    );
    sharingService.links = [
      ShareLink(
        id: 'expired',
        url: 'https://example.com/expired',
        createdAt: now.subtract(const Duration(days: 1)),
        expiresAt: now,
        revoked: false,
      ),
      ShareLink(
        id: 'active',
        url: 'https://example.com/active',
        createdAt: now,
        expiresAt: now.add(const Duration(seconds: 1)),
        revoked: false,
      ),
    ];
    await Future<void>.delayed(const Duration(milliseconds: 50));
    container.read(shareControllerProvider(args));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(
      container.read(shareControllerProvider(args)).links.map((l) => l.id),
      ['active'],
    );
  });

  test(
    'backup prevents double submit and unlocks only the selected child',
    () async {
      final child = await container
          .read(childrenRepositoryProvider)
          .create(name: 'Bob', birthDate: DateTime(2021, 1, 1));
      final childId = (child as ActionSuccess<String>).value;
      final image = File(p.join(tempRoot.path, 'second.jpg'));
      await image.writeAsBytes([1, 2, 3]);
      final artwork = await container
          .read(masterpiecesRepositoryProvider)
          .create(
            childId: childId,
            sourceImageFile: image,
            addedAt: DateTime.now(),
          );
      final artworkId = (artwork as ActionSuccess<String>).value;
      final secondArgs = ShareArgs(childId: childId, childName: '');
      final controller = container.read(
        shareControllerProvider(secondArgs).notifier,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container
            .read(shareControllerProvider(secondArgs))
            .childHasSyncedArtworks,
        isFalse,
      );
      expect(
        container.read(shareControllerProvider(secondArgs)).resolvedChildName,
        'Bob',
      );

      final gate = Completer<void>();
      var calls = 0;
      backupAction = (requestedChildId) async {
        expect(requestedChildId, childId);
        calls++;
        await gate.future;
        await container
            .read(masterpiecesRepositoryProvider)
            .markSynced(artworkId);
        return const ActionFailed(ServiceFailure());
      };
      final first = controller.backupNow();
      expect(
        container.read(shareControllerProvider(secondArgs)).backup.isBusy,
        isTrue,
      );
      expect(await controller.backupNow(), isA<ActionCancelled<void>>());
      gate.complete();
      expect(await first, isA<ActionSuccess<void>>());
      expect(calls, 1);
      expect(
        container
            .read(shareControllerProvider(secondArgs))
            .childHasSyncedArtworks,
        isTrue,
      );
    },
  );

  test('backup without synced artwork shows a retryable error', () async {
    final child = await container
        .read(childrenRepositoryProvider)
        .create(name: 'Bob', birthDate: DateTime(2021, 1, 1));
    final childId = (child as ActionSuccess<String>).value;
    final secondArgs = ShareArgs(childId: childId, childName: 'Bob');
    final controller = container.read(
      shareControllerProvider(secondArgs).notifier,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    backupAction = (id) async => const ActionSuccess(null);
    expect(await controller.backupNow(), isA<ActionFailed<void>>());
    expect(
      container.read(shareControllerProvider(secondArgs)).backup,
      isA<ActionError>(),
    );
    expect(await controller.backupNow(), isA<ActionFailed<void>>());
    expect(
      container
          .read(shareControllerProvider(secondArgs))
          .childHasSyncedArtworks,
      isFalse,
    );
  });

  test(
    'backup retries after a link-list network error and clears offline',
    () async {
      final child = await container
          .read(childrenRepositoryProvider)
          .create(name: 'Bob', birthDate: DateTime(2021, 1, 1));
      final childId = (child as ActionSuccess<String>).value;
      final secondArgs = ShareArgs(childId: childId, childName: 'Bob');
      sharingService.listResult = const ActionFailed(NetworkFailure());
      final controller = container.read(
        shareControllerProvider(secondArgs).notifier,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        container.read(shareControllerProvider(secondArgs)).offline,
        isTrue,
      );

      backupAction = (id) async => const ActionSuccess(null);
      expect(await controller.backupNow(), isA<ActionFailed<void>>());
      final state = container.read(shareControllerProvider(secondArgs));
      expect(state.offline, isFalse);
      expect(state.backup, isA<ActionError>());
    },
  );
}
