// Regression coverage for the join-confirmation dialog: redeeming another
// family's code used to fire straight from the submit button (and, worse,
// straight from a QR scan) with no confirmation at all, silently discarding
// whatever the parent had already captured locally. This asserts the
// dialog gates both entry points and its destructive action stays disabled
// until explicitly acknowledged.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

class _FakeFamilyApi implements FamilyApi {
  int redeemCallCount = 0;
  bool failMemberCount = false;

  @override
  Future<FamilyInfo> getFamilyInfo() async => const FamilyInfo(
    familyId: 'family-1',
    name: 'Famille Test',
    code: 'ABCD2345',
    role: FamilyMemberRole.parent,
  );

  @override
  Future<void> renameFamily(String name) async {}

  @override
  Future<FamilyMembership?> currentMembership() async => const FamilyMembership(
    familyId: 'family-1',
    role: FamilyMemberRole.parent,
  );

  @override
  Future<int> activeMemberCount(String familyId) async {
    if (failMemberCount) throw StateError('membership check unavailable');
    return 1;
  }

  @override
  Future<RedeemOutcome> redeemInvite({
    required String code,
    bool discardPrevious = false,
  }) async {
    redeemCallCount++;
    return const RedeemOutcome(state: RedeemState.invalidCode);
  }

  @override
  Future<UserProfile> getMyProfile() async =>
      const UserProfile(userId: 'family-1', email: 'test@example.com');

  @override
  Future<UserProfile> updateMyProfile({
    String? firstName,
    String? lastName,
  }) async => UserProfile(
    userId: 'family-1',
    email: 'test@example.com',
    firstName: firstName,
    lastName: lastName,
  );

  @override
  Future<List<FamilyMember>> listFamilyMembers() async => const [];

  @override
  Future<void> removeFamilyMember(String userId) async {}

  @override
  Future<void> leaveFamily() async {}

  @override
  Future<FamilyMember> updateFamilyMemberRole(
    String userId,
    FamilyMemberRole role,
  ) async => FamilyMember(
    userId: userId,
    role: role,
    email: 'test@example.com',
    joinedAt: DateTime(2026),
  );

  @override
  Future<FamilyMember> updateFamilyMemberRelationLabel(
    String userId,
    String? relationLabel,
  ) async => FamilyMember(
    userId: userId,
    role: FamilyMemberRole.contributor,
    email: 'test@example.com',
    relationLabel: relationLabel,
    joinedAt: DateTime(2026),
  );
}

/// `noSuchMethod` delegation, same trick `_FlakyArtworks` uses elsewhere in
/// this suite: only `count()` needs a real body — the dialog reads nothing
/// else off either repository, and any accidental extra call surfaces
/// loudly as a `NoSuchMethodError` rather than a wrong-but-silent default.
class _FixedChildrenRepository implements ChildrenRepository {
  _FixedChildrenRepository(this._count);
  final int _count;

  @override
  Future<int> count() async => _count;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedArtworksRepository implements ArtworksRepository {
  _FixedArtworksRepository(this._count);
  final int _count;

  @override
  Future<int> count({String? childId}) async => _count;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeFamilyApi api;

  Widget appWith(_FakeFamilyApi api) {
    return ProviderScope(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(AppCapabilities.cloud),
        familyApiProvider.overrideWithValue(api),
        childrenRepositoryProvider.overrideWithValue(
          _FixedChildrenRepository(2),
        ),
        artworksRepositoryProvider.overrideWithValue(
          _FixedArtworksRepository(5),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const FamilyInviteScreen(),
      ),
    );
  }

  setUp(() {
    api = _FakeFamilyApi();
  });

  Future<void> enterCodeAndOpenDialog(WidgetTester tester) async {
    await tester.pumpWidget(appWith(api));
    await tester.pumpAndSettle();
    // FamilyInviteScreen renders a single TextField: the join-code input.
    await tester.enterText(find.byType(TextField).first, 'ABCD2345');
    await tester.pump();
    final joinButton = find.text('Rejoindre');
    await tester.ensureVisible(joinButton);
    await tester.pumpAndSettle();
    await tester.tap(joinButton);
    await tester.pump();
  }

  testWidgets(
    'tapping Rejoindre opens the confirmation dialog without redeeming',
    (tester) async {
      await enterCodeAndOpenDialog(tester);

      expect(find.text('Rejoindre une autre famille ?'), findsOneWidget);
      expect(api.redeemCallCount, 0);
    },
  );

  testWidgets(
    'a failed membership check cannot advance to the destructive confirmation',
    (tester) async {
      api.failMemberCount = true;
      await enterCodeAndOpenDialog(tester);
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Impossible de vérifier l'état de votre famille actuelle. Réessayez avant de continuer.",
        ),
        findsOneWidget,
      );
      final next = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Suivant'),
      );
      expect(next.onPressed, isNull);
      expect(find.text('Rejoindre et tout supprimer'), findsNothing);
      expect(api.redeemCallCount, 0);
    },
  );

  testWidgets('cancelling at the summary step never redeems', (tester) async {
    await enterCodeAndOpenDialog(tester);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(find.text('Rejoindre une autre famille ?'), findsNothing);
    expect(api.redeemCallCount, 0);
  });

  testWidgets(
    'the destructive action stays disabled until the checkbox is ticked, '
    'and cancelling at that step never redeems',
    (tester) async {
      await enterCodeAndOpenDialog(tester);
      // The impact load (local counts + membership check) is async; wait
      // for it before advancing — the "Suivant" button is itself gated on
      // it finishing.
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suivant'));
      await tester.pumpAndSettle();

      final destructiveButtonFinder = find.widgetWithText(
        TextButton,
        'Rejoindre et tout supprimer',
      );
      expect(destructiveButtonFinder, findsOneWidget);
      final disabledButton = tester.widget<TextButton>(destructiveButtonFinder);
      expect(
        disabledButton.onPressed,
        isNull,
        reason: 'must stay disabled until the checkbox is ticked',
      );

      await tester.tap(find.byType(Checkbox));
      await tester.pump();

      final enabledButton = tester.widget<TextButton>(destructiveButtonFinder);
      expect(enabledButton.onPressed, isNotNull);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();

      expect(api.redeemCallCount, 0);
    },
  );
}
