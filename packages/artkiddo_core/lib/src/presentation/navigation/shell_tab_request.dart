import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cross-branch tab switch request (e.g. "View artworks" from
/// child actions switching to the gallery tab after posing the filter).
/// Consumed once by [AppShell].
class ShellTabRequestNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int tabIndex) => state = tabIndex;

  void clear() => state = null;
}

final shellTabRequestProvider = NotifierProvider<ShellTabRequestNotifier, int?>(
  ShellTabRequestNotifier.new,
);
