import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('later migration steps are guarded for v5+ databases', () {
    final source = File(
      'lib/src/local/database/app_database.dart',
    ).readAsStringSync();

    expect(source, contains('Keep the from >= 5 guards'));
    for (final version in [7, 8, 9, 10, 11]) {
      expect(
        source,
        contains('from < $version'),
        reason: 'migration step v$version is missing',
      );
    }
    expect(source, contains('from < 7 && from >= 5'));
    expect(source, contains('from < 8 && from >= 5'));
    expect(source, contains('from < 9 && from >= 5'));
    expect(source, contains('if (from >= 5)'));
    expect(source, contains('from < 11 && from >= 5'));
  });
}
