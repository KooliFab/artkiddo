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
              contains('household requires a FamilyApi binding'),
              contains('webGalleryLinks requires a SharingService binding'),
              contains('webGalleryLinks requires a ShareBackup binding'),
            ),
          ),
        ),
      );
    });

    test(
      'a cloud composition missing only the FamilyApi binding is rejected',
      () {
        expect(
          () => ArtKiddoBootstrap.createContainer(
            cloudConfig(
              overrides: [
                remoteMediaFetcherProvider.overrideWithValue(
                  _StubRemoteMediaFetcher(),
                ),
                sharingServiceProvider.overrideWithValue(_StubSharingService()),
                shareBackupProvider.overrideWithValue(
                  (childId) async => const ActionSuccess(null),
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
          ),
          throwsA(
            isA<BootstrapConfigurationException>().having(
              (error) => error.failures,
              'failures',
              equals(['household requires a FamilyApi binding']),
            ),
          ),
        );
      },
    );

    test('a cloud composition missing only the share binding is rejected', () {
      expect(
        () => ArtKiddoBootstrap.createContainer(
          cloudConfig(
            overrides: [
              remoteMediaFetcherProvider.overrideWithValue(
                _StubRemoteMediaFetcher(),
              ),
              familyApiProvider.overrideWithValue(_StubFamilyApi()),
              sharingServiceProvider.overrideWithValue(_StubSharingService()),
              shareBackupProvider.overrideWithValue(
                (childId) async => const ActionSuccess(null),
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
            familyApiProvider.overrideWithValue(_StubFamilyApi()),
            sharingServiceProvider.overrideWithValue(_StubSharingService()),
            shareBackupProvider.overrideWithValue(
              (childId) async => const ActionSuccess(null),
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
      expect(container.read(familyApiProvider), isNot(isA<NoFamilyApi>()));
      expect(
        container.read(sharingServiceProvider),
        isNot(isA<NoSharingService>()),
      );
    });
  });
}

final class _StubRemoteMediaFetcher implements RemoteMediaFetcher {
  @override
  Future<bool> ensureAudioDownloaded(String artworkId) async => true;
}

final class _StubFamilyApi implements FamilyApi {
  @override
  Future<FamilyInfo> getFamilyInfo() async => const FamilyInfo(
    familyId: 'stub',
    code: '000000',
    role: FamilyMemberRole.parent,
  );

  @override
  Future<void> renameFamily(String name) async {}

  @override
  Future<FamilyMembership?> currentMembership() async => null;

  @override
  Future<RedeemOutcome> redeemInvite({
    required String code,
    bool discardPrevious = false,
  }) async => const RedeemOutcome(state: RedeemState.invalidCode);

  @override
  Future<int> activeMemberCount(String familyId) async => 1;

  @override
  Future<UserProfile> getMyProfile() async => const UserProfile(
        userId: 'stub',
        email: 'stub@example.com',
      );

  @override
  Future<UserProfile> updateMyProfile({String? firstName, String? lastName}) async =>
      UserProfile(
        userId: 'stub',
        email: 'stub@example.com',
        firstName: firstName,
        lastName: lastName,
      );

  @override
  Future<List<FamilyMember>> listFamilyMembers() async => const [];
}

final class _StubSharingService implements SharingService {
  @override
  Future<ActionResult<List<ShareLink>>> listLinks(String childId) async =>
      const ActionSuccess([]);

  @override
  Future<ActionResult<ShareLink>> createLink(
    String childId, {
    bool includeAudio = false,
  }) async => const ActionCancelled();

  @override
  Future<ActionResult<void>> updateIncludeAudio(
    String linkId,
    bool includeAudio,
  ) async => const ActionCancelled();

  @override
  Future<ActionResult<void>> revokeLink(String linkId) async =>
      const ActionCancelled();
}
