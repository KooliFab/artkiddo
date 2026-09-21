/// Fetches media that exists remotely but not yet in the local vault.
abstract class RemoteMediaFetcher {
  /// Ensures the artwork's audio file is present locally.
  /// Returns false when the media could not be made available.
  Future<bool> ensureAudioDownloaded(String artworkId);
}

/// Local-only composition: nothing is ever fetched.
final class NoRemoteMediaFetcher implements RemoteMediaFetcher {
  const NoRemoteMediaFetcher();

  @override
  Future<bool> ensureAudioDownloaded(String artworkId) async => false;
}
