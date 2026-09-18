import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A typed intent the user asked for but that required a prerequisite
/// (an account, mostly). Stored in a single global slot: posing a new
/// intent replaces the previous one.
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

  /// Consumes (clears) the current intent and returns it. Callers must
  /// clear the slot *before* opening the replayed destination, to prevent
  /// a double replay.
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
