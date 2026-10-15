// Covers the invite-link plumbing of FamilyInviteScreen: deep-link prefill
// (initialCode), the injected link used for the QR and the share text, and
// the onJoined callback.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

class _FakeFamilyApi implements FamilyApi {
  RedeemState redeemState = RedeemState.ok;
  final redeemed = <String>[];

  @override
  Future<FamilyInfo> getFamilyInfo() async => const FamilyInfo(
    familyId: 'family-1',
    name: 'Famille Test',
    code: 'ABCD2345',
    role: FamilyMemberRole.parent,
  );

  @override
  Future<FamilyMembership?> currentMembership() async => const FamilyMembership(
    familyId: 'family-1',
    role: FamilyMemberRole.parent,
  );

  @override
  Future<int> activeMemberCount(String familyId) async => 1;

  @override
  Future<RedeemOutcome> redeemInvite({
    required String code,
    bool discardPrevious = false,
  }) async {
    redeemed.add(code);
    return RedeemOutcome(state: redeemState);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedChildrenRepository implements ChildrenRepository {
  @override
  Future<int> count() async => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FixedArtworksRepository implements ArtworksRepository {
  @override
  Future<int> count({String? childId}) async => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeFamilyApi api;

  Widget appWith(
    Widget home, {
    String Function(String, Locale)? inviteLinkFor,
    Locale locale = const Locale('fr'),
  }) {
    return ProviderScope(
      overrides: [
        appCapabilitiesProvider.overrideWithValue(AppCapabilities.cloud),
        familyApiProvider.overrideWithValue(api),
        childrenRepositoryProvider.overrideWithValue(
          _FixedChildrenRepository(),
        ),
        artworksRepositoryProvider.overrideWithValue(
          _FixedArtworksRepository(),
        ),
        if (inviteLinkFor != null)
          compositionActionsProvider.overrideWithValue(
            CompositionActions(inviteLinkFor: inviteLinkFor),
          ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  setUp(() => api = _FakeFamilyApi());

  testWidgets(
    'initialCode prefills the field and opens the confirmation once',
    (tester) async {
      await tester.pumpWidget(
        appWith(
          const FamilyInviteScreen(joinMode: true, initialCode: 'ABCD2345'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rejoindre une autre famille ?'), findsOneWidget);
      expect(find.text('ABCD2345'), findsOneWidget); // field text
      expect(api.redeemed, isEmpty);

      // Cancelling must not reopen the dialog.
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('Rejoindre une autre famille ?'), findsNothing);
      expect(api.redeemed, isEmpty);
    },
  );

  testWidgets('confirming a prefilled join redeems and calls onJoined', (
    tester,
  ) async {
    var joined = 0;
    await tester.pumpWidget(
      appWith(
        FamilyInviteScreen(
          joinMode: true,
          initialCode: 'ABCD2345',
          onJoined: () => joined++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Rejoindre et tout supprimer'));
    await tester.pumpAndSettle();

    expect(api.redeemed, ['ABCD2345']);
    expect(joined, 1);
  });

  testWidgets('onJoined is not called when the code is invalid', (
    tester,
  ) async {
    api.redeemState = RedeemState.invalidCode;
    var joined = 0;
    var failed = 0;
    await tester.pumpWidget(
      appWith(
        FamilyInviteScreen(
          joinMode: true,
          initialCode: 'ABCD2345',
          onJoined: () => joined++,
          onRedeemFailed: () => failed++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suivant'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Rejoindre et tout supprimer'));
    await tester.pumpAndSettle();

    expect(api.redeemed, ['ABCD2345']);
    expect(joined, 0);
    expect(failed, 1);
  });

  testWidgets('initialCode is ignored outside joinMode', (tester) async {
    await tester.pumpWidget(
      appWith(const FamilyInviteScreen(initialCode: 'ABCD2345')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rejoindre une autre famille ?'), findsNothing);
  });

  testWidgets('QR encodes the injected link, with the active locale', (
    tester,
  ) async {
    await tester.pumpWidget(
      appWith(
        const FamilyInviteScreen(),
        locale: const Locale('en'),
        inviteLinkFor: (code, locale) =>
            'https://example.test/${locale.languageCode}/join/?code=$code',
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<QrImageView>(find.byType(QrImageView)).key,
      const ValueKey('https://example.test/en/join/?code=ABCD2345'),
    );
  });

  testWidgets('QR falls back to the raw code without an injected link', (
    tester,
  ) async {
    await tester.pumpWidget(appWith(const FamilyInviteScreen()));
    await tester.pumpAndSettle();

    expect(
      tester.widget<QrImageView>(find.byType(QrImageView)).key,
      const ValueKey('ABCD2345'),
    );
  });

  group('share message', () {
    final shared = <String?>[];

    setUp(() {
      shared.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (call) async {
              shared.add((call.arguments as Map)['text'] as String?);
              return 'dev.fluttercommunity.plus/share/unavailable';
            },
          );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            null,
          );
    });

    testWidgets('uses the localized message with link and code', (
      tester,
    ) async {
      await tester.pumpWidget(
        appWith(
          const FamilyInviteScreen(),
          inviteLinkFor: (code, locale) =>
              'https://example.test/join/?code=$code',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inviter'));
      await tester.pumpAndSettle();

      expect(shared, [
        'Rejoins ma famille sur ArtKiddo : '
            'https://example.test/join/?code=ABCD2345 (code ABCD2345)',
      ]);
    });

    testWidgets('uses the code as link when none is injected', (tester) async {
      await tester.pumpWidget(appWith(const FamilyInviteScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inviter'));
      await tester.pumpAndSettle();

      expect(shared, [
        'Rejoins ma famille sur ArtKiddo : ABCD2345 (code ABCD2345)',
      ]);
    });
  });
}
