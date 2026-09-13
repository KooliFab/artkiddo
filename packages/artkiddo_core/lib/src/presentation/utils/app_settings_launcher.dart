import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../local/logging/log.dart';

abstract final class AppSettingsLauncher {
  static const _androidApplicationId = 'ca.bencool.artkiddo';

  static Future<bool> open() async {
    final uri = Platform.isIOS
        ? Uri.parse('app-settings:')
        : Uri(scheme: 'package', path: _androidApplicationId);
    try {
      final opened = await launchUrl(uri);
      if (!opened) {
        Log.w('Ouverture des réglages refusée par le système', 'Settings');
      }
      return opened;
    } catch (e, st) {
      Log.e('Ouverture des réglages impossible', e, st, 'Settings');
      return false;
    }
  }
}
