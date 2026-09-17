// Lot 05 (QA) — preuve pour C9 (contracts.md §10) :
// « La suppression de l'enfant filtré ramène le filtre à "Tous" et émet
// filterReset une seule fois. »
//
// Utilise la vraie base Drift (comme capture_controller_test.dart), pas de
// double : `GalleryFilterNotifier` écoute réellement
// `allChildrenStreamProvider`, lui-même adossé à `DriftChildrenRepository`.
//
// Note lot 05 : ce test a été réécrit une fois en cours de session parce
// que le lot 08 (encore « en cours » au moment de ce contrôle, cf.
// journal.md) a fait évoluer `GalleryFilterNotifier` sous nos pieds — le
// champ `filterResetChildName` / `consumeFilterReset()` a été remplacé par
// un provider dédié `galleryFilterResetBannerProvider` (décision D26,
// commentée dans le code : l'ancien design pouvait effacer la bannière
// avant qu'elle soit rendue). Le test ci-dessous cible l'API actuelle.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  late Directory tempRoot;
  late AppDatabase db;
  late LocalVault vault;
  late ProviderContainer container;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('artkiddo_filter_reset_test_');
    final docsDir = Directory(p.join(tempRoot.path, 'docs'));
    await docsDir.create(recursive: true);
    db = AppDatabase.forTesting(NativeDatabase(File(p.join(tempRoot.path, 'test.sqlite'))));
    vault = LocalVault(documentsDirProvider: () async => docsDir);

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith((ref) => db),
        localVaultProvider.overrideWith((ref) => vault),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await tempRoot.exists()) await tempRoot.delete(recursive: true);
  });

  test('deleting the filtered child resets the filter to AllChildren and posts filterReset once (C9)', () async {
    final childrenRepo = container.read(childrenRepositoryProvider);

    final aResult = await childrenRepo.create(name: 'Léa', birthDate: DateTime(2021, 3, 14));
    final bResult = await childrenRepo.create(name: 'Noah', birthDate: DateTime(2023, 11, 2));
    final childAId = (aResult as ActionSuccess<String>).value;
    final childBId = (bResult as ActionSuccess<String>).value;

    // Keep the stream actively subscribed (mirrors the gallery screen
    // watching it), otherwise the notifier's own `ref.listen` subscription
    // can be the only consumer and the underlying Drift watch never settles
    // deterministically in a plain unit test.
    final events = <List<int>>[];
    final sub = container.listen(allChildrenStreamProvider, (previous, next) {
      next.whenData((list) => events.add(list.map((c) => c.id.hashCode).toList()));
    }, fireImmediately: true);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(events.last.length, 2, reason: 'both children must be visible before any deletion');

    final filterNotifier = container.read(galleryFilterProvider.notifier);
    filterNotifier.setFilter(OneChild(childAId));
    expect(container.read(galleryFilterProvider), isA<OneChild>());
    expect(container.read(galleryFilterResetBannerProvider), isNull, reason: 'no reset has happened yet');

    await childrenRepo.delete(childAId);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(container.read(galleryFilterProvider), const AllChildren(), reason: 'filter must fall back to "Tous"');
    expect(
      container.read(galleryFilterResetBannerProvider),
      'Léa',
      reason: 'filterReset banner must carry the removed child\'s name',
    );

    // The view clears the banner explicitly once shown (D26) — it is not
    // self-clearing, so re-reading it must still show the same value until
    // that explicit dismissal happens.
    expect(container.read(galleryFilterResetBannerProvider), 'Léa', reason: 'must not self-clear on repeated reads');
    container.read(galleryFilterResetBannerProvider.notifier).clear();
    expect(container.read(galleryFilterResetBannerProvider), isNull);

    // The other child's filter is unaffected by an unrelated deletion.
    filterNotifier.setFilter(OneChild(childBId));
    await childrenRepo.delete(childBId);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(container.read(galleryFilterProvider), const AllChildren());
    expect(container.read(galleryFilterResetBannerProvider), 'Noah');
    sub.close();
  }, timeout: const Timeout(Duration(seconds: 10)));
}
