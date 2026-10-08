import 'dart:io';

import 'package:crypto/crypto.dart';

/// SHA-256 and size of a file, read in one streaming pass.
class FileDigest {
  /// Lower-case hexadecimal SHA-256.
  final String sha256;
  final int byteSize;

  const FileDigest({required this.sha256, required this.byteSize});
}

/// Hashes [file] without loading it in memory. Throws a
/// [FileSystemException] when it cannot be read.
Future<FileDigest> digestFile(File file) async {
  var size = 0;
  final digest = await sha256
      .bind(
        file.openRead().map((chunk) {
          size += chunk.length;
          return chunk;
        }),
      )
      .first;
  return FileDigest(sha256: digest.toString(), byteSize: size);
}
