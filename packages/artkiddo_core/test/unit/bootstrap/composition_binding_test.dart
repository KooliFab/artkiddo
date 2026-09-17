import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// A composition may declare a capability and still forget to bind it.
/// `validate()` cannot see that: it only inspects the declared configuration.
/// These tests cover what the overrides actually produced.
void main() {
  group('composition bindings', () {
    ArtKiddoBootstrapConfig cloudConfig({List<Override> overrides = const []}) {
      return ArtKiddoBootstrapConfig(
        capabilities: AppCapabilities.cloud,
        cloudServices: CloudServices.production,
        environment: AppEnvironment.test,
        overrides: overrides,
      );
    }

    test('the local composition needs no binding at all', () {
      final container = ArtKiddoBootstrap.createContainer(
        const ArtKiddoBootstrapConfig(
          capabilities: AppCapabilities.local,
          cloudServices: null,
          environment: AppEnvironment.test,
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(appCapabilitiesProvider), AppCapabilities.local);
      expect(
        container.read(remoteMediaFetcherProvider),
        isA<NoRemoteMediaFetcher>(),
      );
    });

    test('a cloud composition without any binding is rejected', () {
      expect(
        () => ArtKiddoBootstrap.createContainer(cloudConfig()),
        throwsA(
          isA<BootstrapConfigurationException>().having(
            (error) => error.failures,
            'failures',
            allOf(
              contains(
                'remoteAccount requires a CompositionActions.openAccount',
              ),
              contains('household requires a CompositionActions.openFamilyHub'),
              contains(
                'webGalleryLinks requires a CompositionActions.openGalleryShare',
              ),
              contains('remoteBackup requires a RemoteMediaFetcher binding'),
            ),
          ),
        ),
      );
    });

    test('a cloud composition missing only the share binding is rejected', () {
      expect(
        () => ArtKiddoBootstrap.createContainer(
          cloudConfig(
            overrides: [
              remoteMediaFetcherProvider.overrideWithValue(
                _StubRemoteMediaFetcher(),
              ),
              compositionActionsProvider.overrideWithValue(
                CompositionActions(
                  openAccount: (context) {},
                  openFamilyHub: (context) {},
                ),
              ),
            ],
          ),
        ),
        throwsA(
          isA<BootstrapConfigurationException>().having(
            (error) => error.failures,
            'failures',
            equals([
              'webGalleryLinks requires a CompositionActions.openGalleryShare',
            ]),
          ),
        ),
      );
    });

    test('a fully bound cloud composition is accepted', () {
      final container = ArtKiddoBootstrap.createContainer(
        cloudConfig(
          overrides: [
            remoteMediaFetcherProvider.overrideWithValue(
              _StubRemoteMediaFetcher(),
            ),
            compositionActionsProvider.overrideWithValue(
              CompositionActions(
                openAccount: (context) {},
                openFamilyHub: (context) {},
                openGalleryShare: (context, childId, childName) {},
              ),
            ),
          ],
        ),
      );
      addTearDown(container.dispose);

      expect(container.read(appCapabilitiesProvider), AppCapabilities.cloud);
      expect(
        container.read(remoteMediaFetcherProvider),
        isNot(isA<NoRemoteMediaFetcher>()),
      );
    });
  });
}

final class _StubRemoteMediaFetcher implements RemoteMediaFetcher {
  @override
  Future<bool> ensureAudioDownloaded(String masterpieceId) async => true;
}
