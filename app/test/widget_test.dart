import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_local/main.dart';

void main() {
  testWidgets('local shell exposes the account-free path', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: ArtKiddoLocalApp(home: Text('Coffre local'))),
    );
    await tester.pump();

    expect(find.text('Coffre local'), findsOneWidget);
  });
}
