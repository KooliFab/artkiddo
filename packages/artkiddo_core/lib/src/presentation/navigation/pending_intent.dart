import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class PendingIntent {
  const PendingIntent();
}

class NoPendingIntent extends PendingIntent {
  const NoPendingIntent();
}

class ShareChildGalleryIntent extends PendingIntent {
  final String childId;
  const ShareChildGalleryIntent(this.childId);
}

class SyncNowIntent extends PendingIntent {
  const SyncNowIntent();
}

class PendingIntentNotifier extends Notifier<PendingIntent> {
  @override
  PendingIntent build() => const NoPendingIntent();

  void pose(PendingIntent intent) => state = intent;

  PendingIntent consume() {
    final current = state;
    state = const NoPendingIntent();
    return current;
  }
}

final pendingIntentProvider =
    NotifierProvider<PendingIntentNotifier, PendingIntent>(
      PendingIntentNotifier.new,
    );
