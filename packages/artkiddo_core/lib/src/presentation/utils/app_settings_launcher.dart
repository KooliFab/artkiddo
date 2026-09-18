import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import '../../local/logging/log.dart';

/// Opens the OS settings screen for this app.
///
/// `url_launcher` is the only navigation/URL dependency in this widget's
/// budget: `app_settings` was not added. iOS exposes a documented
/// `app-settings:` URL scheme that `url_launcher` can open directly.
/// Android has no equivalent *documented* URL scheme reachable without a
/// dedicated plugin (`app_settings`); the `package:<applicationId>` URI
/// used below is the same one that plugin resolves to under the hood and
/// is honoured by Android's `ACTION_APPLICATION_DETAILS_SETTINGS` intent
/// filter, but it is not part of `url_launcher`'s own contract.
///
/// KNOWN ISSUE: `_androidApplicationId` below is hardcoded to one
/// composition's applicationId. Since this file is now shared by every
/// composition that consumes this package, a composition whose
/// `applicationId` differs opens the wrong app's settings screen on
/// Android. This needs to become an injected value (a constructor
/// parameter or a provider each composition overrides, matching the
/// `CompositionActions`/`RemoteMediaFetcher` pattern already used
/// elsewhere in this package) rather than a compile-time constant.
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
