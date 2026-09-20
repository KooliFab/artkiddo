class QuotaExceededException implements Exception {
  final DateTime? resetsAt;
  final String? quotaMode;

  const QuotaExceededException({this.resetsAt, this.quotaMode});

  @override
  String toString() =>
      'QuotaExceededException(resetsAt: $resetsAt, quotaMode: $quotaMode)';
}

class GlobalUploadsSuspendedException implements Exception {
  final String message;

  const GlobalUploadsSuspendedException([
    this.message = 'New remote backups are temporarily unavailable.',
  ]);

  @override
  String toString() => 'GlobalUploadsSuspendedException: $message';
}

enum ObjectVariant { display, thumbnail, audio }

abstract class ObjectUploader {
  Future<String> uploadDerivative({
    required List<int> bytes,
    required String artworkId,
    required ObjectVariant variant,
    String? childId,
    String? fileName,
  });
}

abstract class ObjectDownloader {
  Future<List<int>> downloadByKey(String key);
}
