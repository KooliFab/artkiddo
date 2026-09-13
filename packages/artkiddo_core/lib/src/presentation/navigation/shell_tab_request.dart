import 'package:flutter_riverpod/flutter_riverpod.dart';

class ShellTabRequestNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int tabIndex) => state = tabIndex;

  void clear() => state = null;
}

final shellTabRequestProvider = NotifierProvider<ShellTabRequestNotifier, int?>(
  ShellTabRequestNotifier.new,
);
