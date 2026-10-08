import 'dart:io';

import 'package:uuid/uuid.dart';

import '../logging/log.dart';

/// Suffix of every unfinished write. A file ending with it is never read.
const String kTempFileSuffix = '.tmp';

/// File primitives used by [writeFileAtomically], injectable so tests can
/// simulate a crash or a full disk between two steps.
abstract interface class VaultFileOps {
  /// Writes [bytes] to [file] and flushes them to the disk.
  Future<void> writeBytes(File file, List<int> bytes);

  /// Copies [source] to [dest].
  Future<void> copy(File source, File dest);

  Future<int> length(File file);

  /// Moves [from] to [to] (atomic on the same volume).
  Future<void> rename(File from, String to);

  /// Deletes [file]; a missing file is not an error.
  Future<void> deleteIfExists(File file);
}

class DiskVaultFileOps implements VaultFileOps {
  const DiskVaultFileOps();

  @override
  Future<void> writeBytes(File file, List<int> bytes) =>
      file.writeAsBytes(bytes, flush: true);

  @override
  Future<void> copy(File source, File dest) => source.copy(dest.path);

  @override
  Future<int> length(File file) => file.length();

  @override
  Future<void> rename(File from, String to) => from.rename(to);

  @override
  Future<void> deleteIfExists(File file) async {
    if (await file.exists()) await file.delete();
  }
}

const Uuid _uuid = Uuid();

/// The only way the vault writes a file at a final path.
///
/// Writes `<dest>.<uuid>.tmp` in the **same directory** (a rename is atomic
/// only on one volume), flushes and closes it, checks its size, then renames
/// it onto [dest]. A crash or an error at any step leaves [dest] exactly as
/// it was: the previous content, or no file. The temporary file is removed
/// on error; one that survives a crash is removed at the next start.
///
/// Give exactly one of [bytes] and [source]. Any failure (disk full
/// included) is rethrown unchanged after the cleanup; callers map it with
/// their usual failure mapping.
Future<void> writeFileAtomically(
  File dest, {
  List<int>? bytes,
  File? source,
  VaultFileOps ops = const DiskVaultFileOps(),
}) async {
  if ((bytes == null) == (source == null)) {
    throw ArgumentError('give exactly one of bytes and source');
  }
  await dest.parent.create(recursive: true);
  final tmp = File('${dest.path}.${_uuid.v4()}$kTempFileSuffix');
  try {
    final int expected;
    if (bytes != null) {
      expected = bytes.length;
      await ops.writeBytes(tmp, bytes);
    } else {
      expected = await ops.length(source!);
      await ops.copy(source, tmp);
    }
    final written = await ops.length(tmp);
    if (written != expected) {
      throw FileSystemException(
        'Incomplete write: $written of $expected bytes',
        tmp.path,
      );
    }
    await ops.rename(tmp, dest.path);
  } catch (_) {
    try {
      await ops.deleteIfExists(tmp);
    } on FileSystemException catch (cleanupError) {
      // The original error matters more; the next start removes the leftover.
      Log.w('Fichier temporaire conservé : $cleanupError', 'Vault');
    }
    rethrow;
  }
}
