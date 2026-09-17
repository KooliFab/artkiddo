import 'dart:convert';
import 'dart:typed_data';

import 'package:artkiddo_core/artkiddo_core.dart';
import 'package:local_data_transfer/local_data_transfer.dart';
import 'package:path/path.dart' as p;

/// Selects the ArtKiddo records and media included in one manual transfer.
class ArkiddoTransferProfile {
  final bool includeChildren;
  final bool includeMasterpieces;
  final bool includeImages;
  final bool includeAudio;
  final Set<String>? childIds;
  final Set<String>? masterpieceIds;

  const ArkiddoTransferProfile({
    this.includeChildren = true,
    this.includeMasterpieces = true,
    this.includeImages = true,
    this.includeAudio = true,
    this.childIds,
    this.masterpieceIds,
  });

  bool includesChild(String id) => childIds == null || childIds!.contains(id);

  bool includesMasterpiece(String id) =>
      masterpieceIds == null || masterpieceIds!.contains(id);
}

class ArkiddoTransferBundle {
  final Uint8List manifest;
  final List<FileSource> files;

  const ArkiddoTransferBundle({required this.manifest, this.files = const []});
}

class ArkiddoTransferDocument {
  final int schemaVersion;
  final List<Map<String, dynamic>> children;
  final List<Map<String, dynamic>> masterpieces;

  const ArkiddoTransferDocument({
    required this.schemaVersion,
    required this.children,
    required this.masterpieces,
  });

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'children': children,
    'masterpieces': masterpieces,
  };
}

/// Serializes domain data and exposes local media as bounded file streams.
class ArkiddoTransferExporter {
  final LocalVault vault;

  const ArkiddoTransferExporter({required this.vault});

  Future<ArkiddoTransferBundle> build({
    required Iterable<Child> children,
    required Iterable<Masterpiece> masterpieces,
    ArkiddoTransferProfile profile = const ArkiddoTransferProfile(),
  }) async {
    final selectedChildren = children
        .where((child) => profile.includesChild(child.id))
        .toList(growable: false);
    final selectedChildIds = selectedChildren.map((child) => child.id).toSet();
    final selectedMasterpieces = masterpieces
        .where(
          (masterpiece) =>
              selectedChildIds.contains(masterpiece.childId) &&
              profile.includesMasterpiece(masterpiece.id),
        )
        .toList(growable: false);

    final document = ArkiddoTransferDocument(
      schemaVersion: 1,
      children: profile.includeChildren
          ? selectedChildren.map(_childJson).toList(growable: false)
          : const [],
      masterpieces: profile.includeMasterpieces
          ? selectedMasterpieces.map(_masterpieceJson).toList(growable: false)
          : const [],
    );
    final files = <FileSource>[];
    if (profile.includeMasterpieces) {
      for (final masterpiece in selectedMasterpieces) {
        if (profile.includeImages) {
          final image = await _sourceFor(
            masterpiece.relativeImagePath ?? masterpiece.bestDisplayImagePath,
            entityId: masterpiece.id,
            field: 'image',
          );
          if (image != null) files.add(image);
        }
        if (profile.includeAudio) {
          final audio = await _sourceFor(
            masterpiece.relativeAudioPath,
            entityId: masterpiece.id,
            field: 'audio',
          );
          if (audio != null) files.add(audio);
        }
      }
    }
    return ArkiddoTransferBundle(
      manifest: Uint8List.fromList(utf8.encode(jsonEncode(document.toJson()))),
      files: files,
    );
  }

  static Map<String, dynamic> _childJson(Child child) => {
    'id': child.id,
    'name': child.name,
    'birthDate': child.birthDate.toUtc().toIso8601String(),
    'createdAt': child.createdAt.toUtc().toIso8601String(),
    'updatedAt': child.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _masterpieceJson(Masterpiece masterpiece) => {
    'id': masterpiece.id,
    'childId': masterpiece.childId,
    'relativeImagePath': masterpiece.relativeImagePath,
    'addedAt': masterpiece.addedAt.toUtc().toIso8601String(),
    'drawnAt': masterpiece.drawnAt?.toUtc().toIso8601String(),
    'story': masterpiece.story,
    'relativeAudioPath': masterpiece.relativeAudioPath,
    'audioDurationMs': masterpiece.audioDurationMs,
    'audioByteSize': masterpiece.audioByteSize,
    'imageWidth': masterpiece.imageWidth,
    'imageHeight': masterpiece.imageHeight,
  };

  Future<FileSource?> _sourceFor(
    String? relativePath, {
    required String entityId,
    required String field,
  }) async {
    if (relativePath == null) return null;
    final file = await vault.resolveFile(relativePath);
    if (!await file.exists()) return null;
    final stat = await file.stat();
    return FileSource(
      name: p.basename(file.path),
      mimeType: _mimeType(file.path, field),
      size: stat.size,
      openRead: file.openRead,
      metadata: {
        'entityType': 'masterpiece',
        'entityId': entityId,
        'field': field,
        'relativePath': relativePath,
      },
    );
  }

  static String _mimeType(String path, String field) {
    final extension = p.extension(path).toLowerCase();
    if (field == 'audio' || extension == '.m4a') return 'audio/mp4';
    if (extension == '.png') return 'image/png';
    if (extension == '.webp') return 'image/webp';
    return 'image/jpeg';
  }
}

/// Deserializes a manifest. Domain conflict resolution remains in the app.
class ArkiddoTransferImporter {
  const ArkiddoTransferImporter();

  ArkiddoTransferDocument decode(List<int> payload) {
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map) {
      throw const FormatException('Invalid ArtKiddo manifest.');
    }
    final version = decoded['schemaVersion'];
    if (version != 1) {
      throw FormatException('Unsupported ArtKiddo schema: $version.');
    }
    return ArkiddoTransferDocument(
      schemaVersion: version as int,
      children: _records(decoded['children']),
      masterpieces: _records(decoded['masterpieces']),
    );
  }

  static List<Map<String, dynamic>> _records(Object? value) {
    if (value is! List) {
      throw const FormatException('Manifest records are invalid.');
    }
    return value
        .map((record) {
          if (record is! Map) {
            throw const FormatException('Manifest record is invalid.');
          }
          return Map<String, dynamic>.from(record);
        })
        .toList(growable: false);
  }
}

/// Commits verified staged media into the existing LocalVault.
///
/// The database row is deliberately not written here: the caller validates the
/// decoded manifest first, then updates Drift through its normal repositories.
class ArkiddoReceivedFileHandler {
  final LocalVault vault;

  const ArkiddoReceivedFileHandler({required this.vault});

  Future<String> commitImage({
    required ReceivedFile received,
    required String masterpieceId,
  }) async {
    _validateMedia(received, expectedPrefix: 'image/', expectedField: 'image');
    final directory = await vault.masterPiecesDirectory;
    final extension = p.extension(received.metadata.name).isEmpty
        ? '.jpg'
        : p.extension(received.metadata.name);
    final relativePath = p.join(
      LocalVault.masterpiecesFolder,
      '$masterpieceId$extension',
    );
    await received.commitTo(p.join(directory.path, '$masterpieceId$extension'));
    return relativePath;
  }

  Future<String> commitAudio({
    required ReceivedFile received,
    required String masterpieceId,
    int version = 1,
  }) async {
    _validateMedia(received, expectedPrefix: 'audio/', expectedField: 'audio');
    final directory = await vault.audioDirectory;
    final extension = p.extension(received.metadata.name).isEmpty
        ? '.m4a'
        : p.extension(received.metadata.name);
    final fileName = '${masterpieceId}_v$version$extension';
    await received.commitTo(p.join(directory.path, fileName));
    return p.join(LocalVault.audioFolder, fileName);
  }

  static void _validateMedia(
    ReceivedFile received, {
    required String expectedPrefix,
    required String expectedField,
  }) {
    if (!received.metadata.mimeType.startsWith(expectedPrefix) ||
        received.metadata.metadata['entityType'] != 'masterpiece' ||
        received.metadata.metadata['field'] != expectedField) {
      throw FormatException(
        'Received media does not match the expected ArtKiddo field.',
      );
    }
  }
}
