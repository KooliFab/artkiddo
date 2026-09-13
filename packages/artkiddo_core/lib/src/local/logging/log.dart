import 'package:flutter/foundation.dart';

class Log {
  Log._();

  static const _reset = '\x1B[0m';
  static const _red = '\x1B[31m';
  static const _yellow = '\x1B[33m';
  static const _green = '\x1B[32m';
  static const _cyan = '\x1B[36m';
  static const _gray = '\x1B[90m';

  static void d(String message, [String? tag]) =>
      _log(_cyan, 'D', tag, message);

  static void i(String message, [String? tag]) =>
      _log(_green, 'I', tag, message);

  static void w(String message, [String? tag]) =>
      _log(_yellow, 'W', tag, message);

  static void e(
    String message, [
    Object? error,
    StackTrace? stack,
    String? tag,
  ]) {
    _log(_red, 'E', tag, message);
    if (kDebugMode) {
      if (error != null) debugPrint('$_red$error$_reset');
      if (stack != null) debugPrint('$_gray$stack$_reset');
    }
  }

  static void _log(String color, String level, String? tag, String message) {
    if (kDebugMode) {
      final tagPart = tag != null ? '[$tag] ' : '';
      debugPrint('$color[$level] $tagPart$message$_reset');
    }
  }
}
