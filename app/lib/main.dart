import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_CA', null);
  await initializeDateFormatting('en_CA', null);
  final container = await ArtKiddoBootstrap.start(
    const ArtKiddoBootstrapConfig(
      capabilities: AppCapabilities.local,
      cloudServices: null,
      environment: AppEnvironment.local,
    ),
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const ArtKiddoLocalApp(),
    ),
  );
}

class ArtKiddoLocalApp extends ConsumerWidget {
  final Widget home;

  const ArtKiddoLocalApp({super.key, this.home = const AppShell()});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(effectiveLocaleProvider);
    return MaterialApp(
      title: 'ArtKiddo Local',
      theme: AppTheme.lightTheme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );
  }
}
