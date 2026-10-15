import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeInviteCode', () {
    test('accepts a raw code, uppercased and trimmed', () {
      expect(normalizeInviteCode('ABCD2345'), 'ABCD2345');
      expect(normalizeInviteCode('abcd2345'), 'ABCD2345');
      expect(normalizeInviteCode('  abcd2345 \n'), 'ABCD2345');
    });

    test('accepts French and English join URLs', () {
      expect(
        normalizeInviteCode('https://example.test/join/?code=ABCD2345'),
        'ABCD2345',
      );
      expect(
        normalizeInviteCode('https://example.test/en/join/?code=abcd2345'),
        'ABCD2345',
      );
    });

    test('accepts a missing trailing slash and http', () {
      expect(
        normalizeInviteCode('http://example.test/join?code=ABCD2345'),
        'ABCD2345',
      );
      expect(
        normalizeInviteCode(' https://example.test/en/join?code=ABCD2345&x=1 '),
        'ABCD2345',
      );
    });

    test('accepts the custom app scheme', () {
      expect(normalizeInviteCode('artkiddo://join?code=ABCD2345'), 'ABCD2345');
      expect(normalizeInviteCode('artkiddo://join/?code=abcd2345'), 'ABCD2345');
    });

    test('rejects URLs that are not a join link', () {
      expect(
        normalizeInviteCode('https://example.test/gallery/?code=ABCD2345'),
        isNull,
      );
      expect(
        normalizeInviteCode('https://example.test/join/more?code=ABCD2345'),
        isNull,
      );
      expect(normalizeInviteCode('https://example.test/join/'), isNull);
      expect(
        normalizeInviteCode('ftp://example.test/join?code=ABCD2345'),
        isNull,
      );
      expect(normalizeInviteCode('artkiddo://other?code=ABCD2345'), isNull);
    });

    test('rejects wrong length', () {
      expect(normalizeInviteCode('ABCD234'), isNull);
      expect(normalizeInviteCode('ABCD23456'), isNull);
      expect(
        normalizeInviteCode('https://example.test/join/?code=ABCD234'),
        isNull,
      );
    });

    test('rejects characters outside the alphabet', () {
      expect(normalizeInviteCode('ABCD2340'), isNull); // 0
      expect(normalizeInviteCode('ABCD2341'), isNull); // 1
      expect(normalizeInviteCode('ABCDOIL2'), isNull);
      expect(normalizeInviteCode('ABCD-345'), isNull);
    });

    test('is robust to garbage', () {
      expect(normalizeInviteCode(''), isNull);
      expect(normalizeInviteCode('   '), isNull);
      expect(normalizeInviteCode('hello world'), isNull);
      expect(normalizeInviteCode('://'), isNull);
      expect(normalizeInviteCode('https://'), isNull);
      expect(normalizeInviteCode('http://[bad/join?code=ABCD2345'), isNull);
      expect(normalizeInviteCode('%%%\u0000'), isNull);
    });

    test('finds the code in the shared messages (en and fr)', () {
      expect(
        normalizeInviteCode(
          'Join my family on ArtKiddo: '
          'https://artkiddo.bencool.ca/en/join/?code=ABCD2345 (code ABCD2345)',
        ),
        'ABCD2345',
      );
      expect(
        normalizeInviteCode(
          'Rejoins ma famille sur ArtKiddo : '
          'https://artkiddo.bencool.ca/join/?code=WXYZ2345) (code WXYZ2345)',
        ),
        'WXYZ2345',
      );
    });

    test('finds a standalone code in free text without a link', () {
      expect(normalizeInviteCode('Mon code (abcd2345), merci'), 'ABCD2345');
      expect(normalizeInviteCode('rien ici'), isNull);
    });

    test('uses the first value of a repeated code parameter', () {
      expect(
        normalizeInviteCode(
          'https://example.test/join/?code=ABCD2345&code=WXYZ2345',
        ),
        'ABCD2345',
      );
    });
  });
}
