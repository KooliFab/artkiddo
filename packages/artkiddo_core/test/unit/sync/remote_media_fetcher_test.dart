import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

void main() {
  group('RemoteMediaFetcher contract', () {
    test('default provider returns NoRemoteMediaFetcher', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fetcher = container.read(remoteMediaFetcherProvider);
      expect(fetcher, isA<NoRemoteMediaFetcher>());
    });

    test('NoRemoteMediaFetcher does not fetch anything and returns false', () async {
      const fetcher = NoRemoteMediaFetcher();
      final result = await fetcher.ensureAudioDownloaded('some-id');
      expect(result, isFalse);
    });
  });
}
