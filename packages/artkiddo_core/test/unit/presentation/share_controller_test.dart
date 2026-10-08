import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

final _sessionProvider = NotifierProvider<_Session, String?>(_Session.new);

class _Session extends Notifier<String?> {
  @override
  String? build() => 'parent@example.com';
  void setEmail(String? email) => state = email;
}

class _FakeSharingService implements SharingService {
  List<ShareLink> links = [];
  int listCalls = 0;
  Completer<ActionResult<List<ShareLink>>>? listRequest;
  Completer<ActionResult<ShareLink>>? createRequest;
  ActionResult<List<ShareLink>>? listResult;
  bool lastCreatedIncludeAudio = false;
  String? lastUpdatedLinkId;
  bool? lastUpdatedIncludeAudio;

  @override
  Future<ActionResult<List<ShareLink>>> listLinks(String childId) async {
    listCalls++;
    return listRequest?.future ??
        Future.value(listResult ?? ActionSuccess(links));
  }

  @override
  Future<ActionResult<ShareLink>> createLink(
    String childId, {
    bool includeAudio = false,
  }) async {
    lastCreatedIncludeAudio = includeAudio;
    if (createRequest != null) return createRequest!.future;
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
  late AppCapabilities capabilities;

  late String testChildId;
  late ShareArgs args;

  ShareController observeController(ShareArgs args) {
    container.listen(shareControllerProvider(args), (_, _) {});
    return container.read(shareControllerProvider(args).notifier);
  }

  Future<void> settleLoad(ShareArgs args) async {
    await container.pump();
    if (!container.read(shareControllerProvider(args)).loading) return;
    final done = Completer<void>();
    final subscription = container.listen(shareControllerProvider(args), (
      _,
      next,
    ) {
      if (!next.loading && !done.isCompleted) done.complete();
    });
    await done.future.timeout(const Duration(seconds: 5));
    subscription.close();
  }

  Future<void> initContainer() async {
    container = ProviderContainer(
      overrides: [
        appCapabilitiesProvider.overrideWith((ref) => capabilities),
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
        sharingServiceProvider.overrideWith((ref) => sharingService),
        shareBackupProvider.overrideWith((ref) => backupAction),
        sessionEmailProvider.overrideWith((ref) => ref.watch(_sessionProvider)),
      ],
    );

    final childrenRepo = container.read(childrenRepositoryProvider);
    final childRes = await childrenRepo.create(
      name: 'Alice',
      birthDate: DateTime(2020, 1, 1),
    );
    testChildId = (childRes as ActionSuccess<String>).value;
    args = ShareArgs(childId: testChildId, childName: 'Alice');

    final masterRepo = container.read(artworksRepositoryProvider);
    final dummyFile = File(p.join(tempRoot.path, 'dummy.jpg'));
    await dummyFile.writeAsBytes([1, 2, 3]);
    final artworkRes = await masterRepo.create(
      childId: testChildId,
      sourceImageFile: dummyFile,
      addedAt: DateTime.now(),
    );
    final artworkId = (artworkRes as ActionSuccess<String>).value;
    // Mark synced
    await masterRepo.markSynced(artworkId);
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
    capabilities = AppCapabilities.cloud;
    sharingService = _FakeSharingService();
    backupAction = (childId) async => const ActionSuccess(null);

    // Insert child and a synced artwork
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
      final controller = observeController(args);
      await settleLoad(args);

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
    final controller = observeController(args);
    await settleLoad(args);

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
      final controller = observeController(args);
      await settleLoad(args);

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
        sessionEmailProvider.overrideWith((ref) => ref.watch(_sessionProvider)),
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
    observeController(args);
    await settleLoad(args);
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
          .read(artworksRepositoryProvider)
          .create(
            childId: childId,
            sourceImageFile: image,
            addedAt: DateTime.now(),
          );
      final artworkId = (artwork as ActionSuccess<String>).value;
      final secondArgs = ShareArgs(childId: childId, childName: '');
      final controller = observeController(secondArgs);
      await settleLoad(secondArgs);
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
        await container.read(artworksRepositoryProvider).markSynced(artworkId);
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
    final controller = observeController(secondArgs);
    await settleLoad(secondArgs);
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
      final controller = observeController(secondArgs);
      await settleLoad(secondArgs);
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

  test(
    'closing and reopening reloads links with identical sheet arguments',
    () async {
      final first = container.listen(shareControllerProvider(args), (_, _) {});
      await settleLoad(args);
      final controller = container.read(shareControllerProvider(args).notifier);
      await controller.createLink();
      expect(container.read(shareControllerProvider(args)).links, hasLength(1));
      first.close();
      await container.pump();

      // Another device revoked the link while this sheet was closed.
      sharingService.links = [];
      container.listen(shareControllerProvider(args), (_, _) {});
      await settleLoad(args);
      expect(
        container.read(shareControllerProvider(args).notifier),
        isNot(same(controller)),
      );
      expect(sharingService.listCalls, 2);
      expect(
        container.read(shareControllerProvider(args)).step,
        ShareStep.choice,
      );
      expect(container.read(shareControllerProvider(args)).links, isEmpty);
    },
  );

  test(
    'reopening after sign-in does not retain the signed-out state',
    () async {
      container.read(_sessionProvider.notifier).setEmail(null);
      final first = container.listen(shareControllerProvider(args), (_, _) {});
      await settleLoad(args);
      expect(
        container.read(shareControllerProvider(args)).step,
        ShareStep.signedOut,
      );
      first.close();
      await container.pump();
      container.read(_sessionProvider.notifier).setEmail('parent@example.com');
      observeController(args);
      await settleLoad(args);
      expect(
        container.read(shareControllerProvider(args)).step,
        ShareStep.choice,
      );
      expect(sharingService.listCalls, 1);
    },
  );

  test('session changes reload an already open share sheet', () async {
    container.read(_sessionProvider.notifier).setEmail(null);
    observeController(args);
    await settleLoad(args);
    container.read(_sessionProvider.notifier).setEmail('parent@example.com');
    await settleLoad(args);
    expect(
      container.read(shareControllerProvider(args)).step,
      ShareStep.choice,
    );
    container.read(_sessionProvider.notifier).setEmail(null);
    await settleLoad(args);
    expect(
      container.read(shareControllerProvider(args)).step,
      ShareStep.signedOut,
    );
    expect(container.read(shareControllerProvider(args)).links, isEmpty);
  });

  test('a late list response cannot overwrite a signed-out session', () async {
    final pending = Completer<ActionResult<List<ShareLink>>>();
    sharingService.listRequest = pending;
    observeController(args);
    // Wait until the request, rather than an arbitrary delay, has started.
    while (sharingService.listCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    container.read(_sessionProvider.notifier).setEmail(null);
    await settleLoad(args);
    pending.complete(const ActionSuccess([]));
    await container.pump();
    expect(
      container.read(shareControllerProvider(args)).step,
      ShareStep.signedOut,
    );
  });

  test(
    'closing while a list request is pending ignores its late result',
    () async {
      final pending = Completer<ActionResult<List<ShareLink>>>();
      sharingService.listRequest = pending;
      final first = container.listen(shareControllerProvider(args), (_, _) {});
      while (sharingService.listCalls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      first.close();
      await container.pump();
      pending.complete(const ActionSuccess([]));
      await container.pump();
      sharingService.listRequest = null;
      observeController(args);
      await settleLoad(args);
      expect(sharingService.listCalls, 2);
      expect(
        container.read(shareControllerProvider(args)).step,
        ShareStep.choice,
      );
    },
  );

  test('a late create result cannot restore links after sign-out', () async {
    final controller = observeController(args);
    await settleLoad(args);
    final pending = Completer<ActionResult<ShareLink>>();
    sharingService.createRequest = pending;
    final creation = controller.createLink();
    container.read(_sessionProvider.notifier).setEmail(null);
    await settleLoad(args);
    pending.complete(
      ActionSuccess(
        ShareLink(
          id: 'late-link',
          url: 'https://example.com/gallery?token=test',
          createdAt: DateTime.utc(2026, 9, 30),
          expiresAt: DateTime.utc(2027),
          revoked: false,
        ),
      ),
    );
    expect(await creation, isA<ActionCancelled<ShareLink>>());
    expect(
      container.read(shareControllerProvider(args)).step,
      ShareStep.signedOut,
    );
    expect(container.read(shareControllerProvider(args)).links, isEmpty);
  });

  test(
    'retry after a network error clears the failure and allows creation',
    () async {
      sharingService.listResult = const ActionFailed(NetworkFailure());
      final controller = observeController(args);
      await settleLoad(args);
      expect(
        container.read(shareControllerProvider(args)).loadError,
        isA<NetworkFailure>(),
      );
      sharingService.listResult = null;
      await controller.refresh();
      final state = container.read(shareControllerProvider(args));
      expect(state.offline, isFalse);
      expect(state.loadError, isNull);
      expect(state.childHasSyncedArtworks, isTrue);
      expect(sharingService.listCalls, 2);
      expect(await controller.createLink(), isA<ActionSuccess<ShareLink>>());
    },
  );

  test('a past list failure does not prevent a new create attempt', () async {
    sharingService.listResult = const ActionFailed(NetworkFailure());
    final controller = observeController(args);
    await settleLoad(args);
    expect(await controller.createLink(), isA<ActionSuccess<ShareLink>>());
    final state = container.read(shareControllerProvider(args));
    expect(state.step, ShareStep.linkReady);
    expect(state.offline, isFalse);
    expect(state.loadError, isNull);
  });

  test('retries do not overlap and a failed retry remains retryable', () async {
    final controller = observeController(args);
    await settleLoad(args);
    final pending = Completer<ActionResult<List<ShareLink>>>();
    sharingService.listRequest = pending;
    final first = controller.refresh();
    await controller.refresh();
    while (sharingService.listCalls < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(sharingService.listCalls, 2);
    pending.complete(const ActionFailed(NetworkFailure()));
    await first;
    expect(container.read(shareControllerProvider(args)).loading, isFalse);
    sharingService.listRequest = null;
    await controller.refresh();
    expect(sharingService.listCalls, 3);
    expect(container.read(shareControllerProvider(args)).loadError, isNull);
  });

  Future<void> pumpSheetLoad(WidgetTester tester) async {
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      if (!container.read(shareControllerProvider(args)).loading) break;
    }
    expect(container.read(shareControllerProvider(args)).loading, isFalse);
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Open share'));
    await tester.pump();
    await pumpSheetLoad(tester);
  }

  Future<void> pumpShareHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showShareSheet(
                    context,
                    childId: testChildId,
                    childName: 'Alice',
                    sendImage: () {},
                  ),
                  child: const Text('Open share'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the sheet can retry a list failure and then create a link', (
    tester,
  ) async {
    sharingService.listResult = const ActionFailed(NetworkFailure());
    await pumpShareHost(tester);
    await openSheet(tester);
    final context = tester.element(find.text('Open share'));
    final l10n = AppLocalizations.of(context);
    expect(find.text(l10n.commonRetry), findsOneWidget);
    final create = tester.widget<AppButton>(
      find.widgetWithText(AppButton, l10n.shareGalleryCreate),
    );
    expect(create.onPressed, isNotNull);
    sharingService.listResult = null;
    await tester.tap(find.text(l10n.commonRetry));
    await tester.pump();
    await pumpSheetLoad(tester);
    expect(find.text(l10n.commonRetry), findsNothing);
    await tester.ensureVisible(find.text(l10n.shareGalleryCreate));
    await tester.tap(find.text(l10n.shareGalleryCreate));
    await tester.pumpAndSettle();
    expect(find.text(l10n.commonCopy), findsOneWidget);
    expect(sharingService.links, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('reopening the sheet after sign-in shows the creation controls', (
    tester,
  ) async {
    container.read(_sessionProvider.notifier).setEmail(null);
    await pumpShareHost(tester);
    await openSheet(tester);
    final l10n = AppLocalizations.of(tester.element(find.text('Open share')));
    expect(find.text(l10n.shareSignedOutAction), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    container.read(_sessionProvider.notifier).setEmail('parent@example.com');
    await openSheet(tester);
    expect(find.text(l10n.shareGalleryCreate), findsOneWidget);
    expect(find.text(l10n.shareSignedOutAction), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('local image sharing does not initialize the optional service', (
    tester,
  ) async {
    capabilities = AppCapabilities.local;
    container.invalidate(appCapabilitiesProvider);
    await pumpShareHost(tester);
    await tester.tap(find.text('Open share'));
    await tester.pumpAndSettle();
    final l10n = AppLocalizations.of(tester.element(find.text('Open share')));
    expect(
      find.widgetWithText(AppButton, l10n.shareImageHeading),
      findsOneWidget,
    );
    expect(find.text(l10n.shareGalleryCreate), findsNothing);
    expect(sharingService.listCalls, 0);
    expect(container.exists(shareControllerProvider(args)), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
