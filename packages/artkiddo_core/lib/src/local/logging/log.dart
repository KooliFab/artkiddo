import 'package:flutter/foundation.dart';

/// Simple journal with colored output.
///
/// Tree-shaken in release via `kDebugMode`: no cost, no information leak
/// to a real user. In debug, every call writes to the console — which is
/// what's needed to diagnose an error silently swallowed by a `try/catch`
/// that only updates the screen's state.
class Log {
  Log._();

  static const _reset = '\x1B[0m';
  static const _red = '\x1B[31m';
  static const _yellow = '\x1B[33m';
  static const _green = '\x1B[32m';
  static const _cyan = '\x1B[36m';
  static const _gray = '\x1B[90m';

  /// Debug (cyan) — verbose development information.
  static void d(String message, [String? tag]) =>
      _log(_cyan, 'D', tag, message);

  /// Info (green) — a normal, notable event (sign-in, sync).
  static void i(String message, [String? tag]) =>
      _log(_green, 'I', tag, message);

  /// Warning (yellow) — a recoverable anomaly.
  static void w(String message, [String? tag]) =>
      _log(_yellow, 'W', tag, message);

  /// Error (red) — with the exception and stack trace when available.
  /// This is the call to place in every `catch` that feeds an
  /// `ActionError` shown on screen: without it, the real error (exception
  /// type, service message) stays invisible, and only the message
  /// translated for the parent appears on screen.
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
