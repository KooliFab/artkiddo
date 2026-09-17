// Unit tests for [PendingIntentNotifier] — the single-slot replay
// mechanism used to resume "share this gallery" after a sign-in.
//
// Reference: `.scratch/aaa-ui-ux/design/navigation.md` §5.1, §10 (C12).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  test('posing an intent then consuming it returns it exactly once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(pendingIntentProvider.notifier).pose(const ShareChildGalleryIntent('child-A'));
    expect(container.read(pendingIntentProvider), isA<ShareChildGalleryIntent>());

    final consumed = container.read(pendingIntentProvider.notifier).consume();
    expect(consumed, isA<ShareChildGalleryIntent>().having((i) => i.childId, 'childId', 'child-A'));

    // Consuming again must not replay the same intent a second time
    // (navigation.md §5.1 step 4 — the slot is cleared before the
    // destination is opened).
    final secondConsume = container.read(pendingIntentProvider.notifier).consume();
    expect(secondConsume, isA<NoPendingIntent>());
    expect(container.read(pendingIntentProvider), isA<NoPendingIntent>());
  });

  test('posing a new intent replaces the previous one (single slot)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(pendingIntentProvider.notifier).pose(const ShareChildGalleryIntent('child-A'));
    container.read(pendingIntentProvider.notifier).pose(const SyncNowIntent());

    final consumed = container.read(pendingIntentProvider.notifier).consume();
    expect(consumed, isA<SyncNowIntent>(), reason: 'only one intent slot exists; the later pose wins');
  });
}
