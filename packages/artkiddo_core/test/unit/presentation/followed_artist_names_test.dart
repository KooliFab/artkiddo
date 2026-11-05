import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FollowedArtistNames', () {
    test('full name is the first name and the household name', () {
      expect(FollowedArtistNames.full('Tom', 'Martin'), 'Tom Martin');
      expect(FollowedArtistNames.full('Tom', '  '), 'Tom');
      expect(FollowedArtistNames.full('Tom', null), 'Tom');
    });

    test('short name keeps the household initial only', () {
      expect(FollowedArtistNames.short('Tom', 'Martin'), 'Tom M.');
      expect(FollowedArtistNames.short('Inès', ' élise '), 'Inès É.');
      expect(FollowedArtistNames.short('Tom', null), 'Tom');
    });
  });

  group('nicknames', () {
    ProviderContainer container() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      return c;
    }

    test('a nickname replaces the short name, on this device', () async {
      SharedPreferences.setMockInitialValues({});
      final c = container();
      c.listen(followedArtistLabelsProvider, (_, _) {});
      String label() => c
          .read(followedArtistLabelsProvider)
          .of(childId: 'tom', name: 'Tom', familyName: 'Martin');

      expect(label(), 'Tom M.');
      await c
          .read(followedNicknamesProvider.notifier)
          .setNickname('tom', '  Titou ');
      expect(label(), 'Titou');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(FollowedNicknamesNotifier.prefsKey),
        '{"tom":"Titou"}',
      );
    });

    test('a blank nickname removes it', () async {
      SharedPreferences.setMockInitialValues({
        FollowedNicknamesNotifier.prefsKey: '{"tom":"Titou","ines":"Nini"}',
      });
      final c = container();
      c.listen(followedNicknamesProvider, (_, _) {});
      await c.read(followedNicknamesProvider.notifier).setNickname('tom', ' ');
      expect(c.read(followedNicknamesProvider), {'ines': 'Nini'});
    });

    test('a nickname set before loading keeps the stored ones', () async {
      SharedPreferences.setMockInitialValues({
        FollowedNicknamesNotifier.prefsKey: '{"ines":"Nini"}',
      });
      final c = container();
      await c
          .read(followedNicknamesProvider.notifier)
          .setNickname('tom', 'Titou');
      expect(c.read(followedNicknamesProvider), {
        'ines': 'Nini',
        'tom': 'Titou',
      });
    });

    test('a corrupt stored value is ignored', () async {
      SharedPreferences.setMockInitialValues({
        FollowedNicknamesNotifier.prefsKey: 'not json',
      });
      final c = container();
      c.listen(followedNicknamesProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(followedNicknamesProvider), isEmpty);
    });
  });
}
