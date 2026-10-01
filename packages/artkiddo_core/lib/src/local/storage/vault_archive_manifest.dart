import 'dart:convert';

import '../../contracts/sync_protocol.dart';

/// The only manifest layout this version reads and writes.
const int kVaultArchiveFormatVersion = 1;

/// Name of the manifest at the root of an archive.
const String kVaultArchiveManifestName = 'manifest.json';

/// Folder of the archive that holds every media file.
const String kVaultArchiveMediaFolder = 'media';

/// Why an archive was refused. Nothing is written to the vault for any of
/// them.
enum VaultArchiveFailure {
  /// Not a readable ZIP, or no manifest in it.
  notAnArchive,

  /// The manifest names a `formatVersion` this version does not know.
  unsupportedVersion,

  /// The manifest is malformed, or an entry path is absolute, contains `..`
  /// or leaves the archive.
  invalidManifest,

  /// A media file is missing from the archive, or its size or SHA-256 does
  /// not match the manifest.
  corruptedMedia,
}

class VaultArchiveImportException implements Exception {
  final VaultArchiveFailure failure;
  final String detail;

  const VaultArchiveImportException(this.failure, this.detail);

  @override
  String toString() => 'VaultArchiveImportException(${failure.name}: $detail)';
}

/// Every id of the vault is a lower-case UUID. It also builds file names, so
/// accepting nothing else keeps a separator or a dot out of them.
final RegExp _safeId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);
final RegExp _sha256Hex = RegExp(r'^[0-9a-f]{64}$');
final RegExp _extension = RegExp(r'^\.[a-z0-9]{1,5}$');
final RegExp _calendarDate = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// True when [path] stays inside the archive: relative, `/`-separated, with
/// no empty, `.` or `..` segment, no drive letter and no control character.
bool isSafeArchivePath(String path) {
  if (path.isEmpty || path.startsWith('/') || path.contains('\\')) {
    return false;
  }
  if (RegExp(r'^[A-Za-z]:').hasMatch(path)) return false;
  if (path.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) return false;
  final segments = path.endsWith('/')
      ? path.substring(0, path.length - 1).split('/')
      : path.split('/');
  return segments.every(
    (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
  );
}

VaultArchiveImportException _invalid(String detail) =>
    VaultArchiveImportException(VaultArchiveFailure.invalidManifest, detail);

class ArchiveChild {
  final String id;
  final String name;

  /// `YYYY-MM-DD`.
  final String birthDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Set when the child is only the hidden parent of trashed artworks.
  final DateTime? deletedAt;

  const ArchiveChild({
    required this.id,
    required this.name,
    required this.birthDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'birthDate': birthDate,
    'createdAt': syncInstantValue(createdAt),
    'updatedAt': syncInstantValue(updatedAt),
    if (deletedAt != null) 'deletedAt': syncInstantValue(deletedAt!),
  };

  factory ArchiveChild.fromJson(Object? json) {
    final map = _map(json, 'child');
    return ArchiveChild(
      id: _id(map, 'id'),
      name: _string(map, 'name'),
      birthDate: _date(map, 'birthDate'),
      createdAt: _instant(map, 'createdAt'),
      updatedAt: _instant(map, 'updatedAt'),
      deletedAt: _optionalInstant(map, 'deletedAt'),
    );
  }
}

class ArchiveArtwork {
  final String id;
  final String childId;
  final DateTime addedAt;

  /// `YYYY-MM-DD`, null when the date is unknown.
  final String? drawnAt;
  final String? story;
  final int? imageWidth;
  final int? imageHeight;
  final int? audioDurationMs;

  /// Null while the artwork is active; the instant it went to the trash
  /// otherwise.
  final DateTime? deletedAt;

  const ArchiveArtwork({
    required this.id,
    required this.childId,
    required this.addedAt,
    this.drawnAt,
    this.story,
    this.imageWidth,
    this.imageHeight,
    this.audioDurationMs,
    this.deletedAt,
  });

  bool get isTrashed => deletedAt != null;

  Map<String, Object?> toJson() => {
    'id': id,
    'childId': childId,
    'addedAt': syncInstantValue(addedAt),
    if (drawnAt != null) 'drawnAt': drawnAt,
    if (story != null) 'story': story,
    if (imageWidth != null) 'imageWidth': imageWidth,
    if (imageHeight != null) 'imageHeight': imageHeight,
    if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
    if (deletedAt != null) 'deletedAt': syncInstantValue(deletedAt!),
  };

  factory ArchiveArtwork.fromJson(Object? json) {
    final map = _map(json, 'artwork');
    return ArchiveArtwork(
      id: _id(map, 'id'),
      childId: _id(map, 'childId'),
      addedAt: _instant(map, 'addedAt'),
      drawnAt: map['drawnAt'] == null ? null : _date(map, 'drawnAt'),
      story: map['story'] == null ? null : _string(map, 'story'),
      imageWidth: _optionalInt(map, 'imageWidth'),
      imageHeight: _optionalInt(map, 'imageHeight'),
      audioDurationMs: _optionalInt(map, 'audioDurationMs'),
      deletedAt: _optionalInstant(map, 'deletedAt'),
    );
  }
}

/// Which copy of a photo an archive holds.
enum ArchiveQuality { original, optimized }

class ArchiveMedia {
  final String mediaId;
  final int version;
  final MediaRole role;
  final String sha256;
  final int byteSize;

  /// Path of the file inside the archive, under `media/`.
  final String path;
  final ArchiveQuality quality;

  const ArchiveMedia({
    required this.mediaId,
    required this.version,
    required this.role,
    required this.sha256,
    required this.byteSize,
    required this.path,
    required this.quality,
  });

  /// Lower-case extension of [path], with its dot (`.jpg`).
  String get extension => _extensionOf(path);

  Map<String, Object?> toJson() => {
    'mediaId': mediaId,
    'version': version,
    'role': role.name,
    'sha256': sha256,
    'byteSize': byteSize,
    'path': path,
    'quality': quality.name,
  };

  factory ArchiveMedia.fromJson(Object? json) {
    final map = _map(json, 'media');
    final role = _enumByName(MediaRole.values, map, 'role');
    final quality = _enumByName(ArchiveQuality.values, map, 'quality');
    final path = _string(map, 'path');
    if (!isSafeArchivePath(path) ||
        !path.startsWith('$kVaultArchiveMediaFolder/') ||
        path.endsWith('/')) {
      throw _invalid('unsafe media path: $path');
    }
    if (!_extension.hasMatch(_extensionOf(path))) {
      throw _invalid('unexpected media extension: $path');
    }
    final sha = _string(map, 'sha256');
    if (!_sha256Hex.hasMatch(sha)) throw _invalid('malformed sha256');
    final size = _optionalInt(map, 'byteSize');
    final version = _optionalInt(map, 'version');
    if (size == null || size < 0) throw _invalid('malformed byteSize');
    if (version == null || version < 1) throw _invalid('malformed version');
    if (role == MediaRole.audio && quality != ArchiveQuality.original) {
      throw _invalid('an audio file has no optimized quality');
    }
    if (role == MediaRole.original && quality != ArchiveQuality.original ||
        role == MediaRole.optimized && quality != ArchiveQuality.optimized) {
      throw _invalid('role and quality disagree for $path');
    }
    return ArchiveMedia(
      mediaId: _id(map, 'mediaId'),
      version: version,
      role: role,
      sha256: sha,
      byteSize: size,
      path: path,
      quality: quality,
    );
  }
}

/// A file the vault references but could not give to the archive.
class ArchiveMissing {
  final String mediaId;
  final MediaRole role;

  /// Vault path of the file that was not found or not readable.
  final String path;

  const ArchiveMissing({
    required this.mediaId,
    required this.role,
    required this.path,
  });

  Map<String, Object?> toJson() => {
    'mediaId': mediaId,
    'role': role.name,
    'path': path,
  };

  factory ArchiveMissing.fromJson(Object? json) {
    final map = _map(json, 'missing');
    return ArchiveMissing(
      mediaId: _id(map, 'mediaId'),
      role: _enumByName(MediaRole.values, map, 'role'),
      path: _string(map, 'path'),
    );
  }
}

/// `manifest.json`: everything an archive says about itself. It holds
/// titles, dates, ids and file hashes; never a token, a key or a session.
class VaultArchiveManifest {
  final int formatVersion;
  final DateTime exportedAt;
  final String appVersion;
  final bool partial;
  final List<ArchiveMissing> missing;
  final List<ArchiveChild> children;
  final List<ArchiveArtwork> artworks;
  final List<ArchiveMedia> media;

  const VaultArchiveManifest({
    this.formatVersion = kVaultArchiveFormatVersion,
    required this.exportedAt,
    required this.appVersion,
    required this.partial,
    required this.missing,
    required this.children,
    required this.artworks,
    required this.media,
  });

  Map<String, Object?> toJson() => {
    'formatVersion': formatVersion,
    'exportedAt': syncInstantValue(exportedAt),
    'appVersion': appVersion,
    'partial': partial,
    'missing': missing.map((m) => m.toJson()).toList(),
    'children': children.map((c) => c.toJson()).toList(),
    'artworks': artworks.map((a) => a.toJson()).toList(),
    'media': media.map((m) => m.toJson()).toList(),
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Parses and validates [source]. The version is checked first so a newer
  /// layout is reported as such rather than as a malformed file.
  factory VaultArchiveManifest.decode(String source) {
    final Object? json;
    try {
      json = jsonDecode(source);
    } on FormatException {
      throw _invalid('manifest is not JSON');
    }
    final map = _map(json, 'manifest');
    final version = map['formatVersion'];
    if (version is! int) throw _invalid('missing formatVersion');
    if (version != kVaultArchiveFormatVersion) {
      throw VaultArchiveImportException(
        VaultArchiveFailure.unsupportedVersion,
        'formatVersion $version',
      );
    }
    final manifest = VaultArchiveManifest(
      exportedAt: _instant(map, 'exportedAt'),
      appVersion: _string(map, 'appVersion'),
      partial: map['partial'] is bool
          ? map['partial'] as bool
          : throw _invalid('partial must be a boolean'),
      missing: _list(map, 'missing').map(ArchiveMissing.fromJson).toList(),
      children: _list(map, 'children').map(ArchiveChild.fromJson).toList(),
      artworks: _list(map, 'artworks').map(ArchiveArtwork.fromJson).toList(),
      media: _list(map, 'media').map(ArchiveMedia.fromJson).toList(),
    );
    manifest._checkConsistency();
    return manifest;
  }

  void _checkConsistency() {
    final childIds = <String>{};
    for (final child in children) {
      if (!childIds.add(child.id)) {
        throw _invalid('duplicate child ${child.id}');
      }
    }
    final artworkIds = <String>{};
    for (final artwork in artworks) {
      if (!artworkIds.add(artwork.id)) {
        throw _invalid('duplicate artwork ${artwork.id}');
      }
      if (!childIds.contains(artwork.childId)) {
        throw _invalid('artwork ${artwork.id} has an unknown child');
      }
    }
    final paths = <String>{};
    final slots = <String>{};
    for (final entry in media) {
      if (!artworkIds.contains(entry.mediaId)) {
        throw _invalid('media of an unknown artwork: ${entry.mediaId}');
      }
      if (!paths.add(entry.path)) {
        throw _invalid('duplicate path ${entry.path}');
      }
      // One photo (original or optimized) and one audio per artwork.
      final slot =
          '${entry.mediaId}/${entry.role == MediaRole.audio ? 'audio' : 'photo'}';
      if (!slots.add(slot)) throw _invalid('two files for $slot');
    }
    for (final entry in missing) {
      if (!artworkIds.contains(entry.mediaId)) {
        throw _invalid('missing file of an unknown artwork');
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Typed reads: every failure is an `invalidManifest`.
// ---------------------------------------------------------------------------

String _extensionOf(String path) {
  final name = path.split('/').last;
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot).toLowerCase();
}

Map<String, Object?> _map(Object? json, String what) {
  if (json is! Map) throw _invalid('$what must be an object');
  return json.cast<String, Object?>();
}

List<Object?> _list(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! List) throw _invalid('$key must be a list');
  return value;
}

String _string(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty && key != 'story') {
    throw _invalid('$key must be a non-empty string');
  }
  return value;
}

String _id(Map<String, Object?> map, String key) {
  final value = _string(map, key);
  if (!_safeId.hasMatch(value)) throw _invalid('$key is not a UUID: $value');
  return value;
}

String _date(Map<String, Object?> map, String key) {
  final value = _string(map, key);
  if (!_calendarDate.hasMatch(value) || DateTime.tryParse(value) == null) {
    throw _invalid('$key must be YYYY-MM-DD');
  }
  return value;
}

DateTime _instant(Map<String, Object?> map, String key) {
  final value = _string(map, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.endsWith('Z')) {
    throw _invalid('$key must be a UTC instant');
  }
  return parsed;
}

DateTime? _optionalInstant(Map<String, Object?> map, String key) =>
    map[key] == null ? null : _instant(map, key);

int? _optionalInt(Map<String, Object?> map, String key) {
  final value = map[key];
  if (value == null) return null;
  if (value is! int) throw _invalid('$key must be an integer');
  return value;
}

T _enumByName<T extends Enum>(
  List<T> values,
  Map<String, Object?> map,
  String key,
) {
  final value = map[key];
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  throw _invalid('unknown $key: $value');
}
