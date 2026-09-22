import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_CA', null);
  await initializeDateFormatting('en_CA', null);
  final container = await ArtKiddoBootstrap.start(
    ArtKiddoBootstrapConfig(
      capabilities: AppCapabilities.local,
      cloudServices: null,
      environment: AppEnvironment.local,
      // The account-free composition overrides nothing. Every destination it
      // needs — children, settings, language, about, trash — is a local
      // default inside the core, reachable without a capability or a bound
      // action (ADR 0016). An override here would mean this build depends on
      // something the core cannot guarantee on its own.
      overrides: const [],
    ),
  );
  await seedDebugDemoData(
    db: container.read(appDatabaseProvider),
    createArtwork: (childId, sourceImageFile, addedAt, story) =>
        DriftArtworksRepository(
          container.read(appDatabaseProvider),
          container.read(localVaultProvider),
        ).create(
          childId: childId,
          sourceImageFile: sourceImageFile,
          addedAt: addedAt,
          story: story,
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
