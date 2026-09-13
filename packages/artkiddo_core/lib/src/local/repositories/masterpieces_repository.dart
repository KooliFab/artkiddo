import 'dart:io';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:image/image.dart' as image;
import '../database/app_database.dart';
import '../storage/local_vault.dart';
import '../../domain/app_failure.dart';
import '../logging/log.dart';
import '../../domain/action_result.dart';
import '../../sync/sync_outbox.dart';
import '../../domain/masterpiece.dart';
import '../../domain/child.dart';

enum ArtworkDeletionStrategy { localRecoverable, remoteTombstone }

abstract class MasterpiecesRepository {
  Stream<List<Masterpiece>> watch({String? childId}); // addedAt descending
  Future<Masterpiece?> getById(String id);
  Future<int> count({String? childId});

  Future<ActionResult<String>> create({
    required String childId,
    required File sourceImageFile,
    required DateTime addedAt,
    DateTime? drawnAt,
    String? story,
    File? sourceAudioFile,
    int? audioDurationMs,
  });

  Future<ActionResult<void>> updateStory({
    required String id,
    required String? story, // null = explicit clear
  });

  Future<ActionResult<void>> updateDrawnAt({
    required String id,
    required DateTime? drawnAt, // null = explicit clear
  });

  Future<ActionResult<void>> updateAudio({
    required String id,
    required File sourceAudioFile,
    required int durationMs,
  });

  Future<ActionResult<void>> clearAudio(String id);

  Future<ActionResult<void>> markAudioDownloaded({
    required String id,
    required String audioRelativePath,
  });

  Future<ActionResult<void>> delete(String id);

  Future<ActionResult<void>> markSynced(String id);

  Future<ActionResult<void>> ensureDerivatives(String id);

  Future<DerivativeBackfillSummary> backfillMissingDerivatives();

  Future<ActionResult<void>> upsertFromRemote({
    required String id,
    required String childId,
    required DateTime addedAt,
    DateTime? drawnAt,
    String? story,
    String? displayObjectKey,
    String? thumbnailObjectKey,
    String? audioObjectKey,
    int? audioDurationMs,
    int audioByteSize = 0,
    required int byteSize,
    int? imageWidth,
    int? imageHeight,
  });

  Future<ActionResult<void>> applyRemoteTombstone(String id);

  Future<ActionResult<void>> markThumbnailDownloaded({
    required String id,
    required String thumbnailRelativePath,
  });

  Future<ActionResult<void>> markDownloadFailed(String id);

  Future<ActionResult<void>> markDisplayDownloaded({
    required String id,
    required String displayRelativePath,
  });
}

class DerivativeBackfillSummary {
  final int attempted;
  final int succeeded;
  final int failed;
  const DerivativeBackfillSummary({
    required this.attempted,
    required this.succeeded,
    required this.failed,
  });
}

class DriftMasterpiecesRepository implements MasterpiecesRepository {
  final AppDatabase _db;
  final LocalVault _vault;
  final Uuid _uuid;
  final SyncOutboxRepository _outbox;
  final ArtworkDeletionStrategy deletionStrategy;
  final DateTime Function() _now;

  DriftMasterpiecesRepository(
    this._db,
    this._vault, {
    Uuid? uuid,
    SyncOutboxRepository? outbox,
    this.deletionStrategy = ArtworkDeletionStrategy.remoteTombstone,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _outbox = outbox ?? SyncOutboxRepository(_db),
       _now = now ?? DateTime.now;

  Masterpiece _toDomain(MasterpieceEntity entity) {
    return Masterpiece(
      id: entity.id,
      childId: entity.childId,
      relativeImagePath: entity.relativeImagePath,
      addedAt: entity.addedAt,
      drawnAt: entity.drawnAt,
      story: entity.story,
      displayImagePath: entity.displayImagePath,
      thumbnailImagePath: entity.thumbnailImagePath,
      imageWidth: entity.imageWidth,
      imageHeight: entity.imageHeight,
      relativeAudioPath: entity.relativeAudioPath,
      audioDurationMs: entity.audioDurationMs,
      audioByteSize: entity.audioByteSize,
      syncState: SyncState.values.firstWhere(
        (s) => s.name == entity.syncState,
        orElse: () => SyncState.localOnly,
      ),
    );
  }

  static String? _normalizeStory(String? story) {
    if (story == null || story.isEmpty) return null;
    return story;
  }

  Future<(int?, int?)> _readImageDimensions(File file) async {
    try {
      final decoded = image.decodeImage(await file.readAsBytes());
      if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
        return (null, null);
      }
      return (decoded.width, decoded.height);
    } catch (_) {
      return (null, null);
    }
  }

  AppFailure _mapWriteException(Object error, StackTrace stack) {
    final message = error.toString().toLowerCase();
    if (message.contains('no space left') ||
        message.contains('enospc') ||
        message.contains('disk full')) {
      return StorageFullFailure(cause: error, stack: stack);
    }
    return LocalWriteFailure(cause: error, stack: stack);
  }

  @override
  Stream<List<Masterpiece>> watch({String? childId}) {
    final query = _db.select(_db.masterpiecesTable);
    if (childId != null) {
      query.where((t) => t.childId.equals(childId) & t.deletedAt.isNull());
    } else {
      query.where((t) => t.deletedAt.isNull());
    }
    query.orderBy([
      (t) => OrderingTerm(expression: t.addedAt, mode: OrderingMode.desc),
    ]);
    return query.watch().map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<Masterpiece?> getById(String id) async {
    final row = await (_db.select(
      _db.masterpiecesTable,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row != null ? _toDomain(row) : null;
  }

  @override
  Future<int> count({String? childId}) async {
    final query = _db.selectOnly(_db.masterpiecesTable)
      ..addColumns([_db.masterpiecesTable.id.count()]);
    if (childId != null) {
      query.where(
        _db.masterpiecesTable.childId.equals(childId) &
            _db.masterpiecesTable.deletedAt.isNull(),
      );
    } else {
      query.where(_db.masterpiecesTable.deletedAt.isNull());
    }
    final row = await query.getSingle();
    return row.read(_db.masterpiecesTable.id.count()) ?? 0;
  }

  @override
  Future<ActionResult<String>> create({
    required String childId,
    required File sourceImageFile,
    required DateTime addedAt,
    DateTime? drawnAt,
    String? story,
    File? sourceAudioFile,
    int? audioDurationMs,
  }) async {
    if (sourceImageFile.path.isEmpty) {
      return const ActionFailed(ImageUnreadableFailure());
    }
    if (!await sourceImageFile.exists()) {
      return const ActionFailed(ImageUnreadableFailure());
    }

    final id = _uuid.v4();
    final normalizedStory = _normalizeStory(story);
    final dimensions = await _readImageDimensions(sourceImageFile);

    String relativePath;
    try {
      relativePath = await _vault.storeMasterpieceImage(
        sourceFile: sourceImageFile,
        masterpieceId: id,
      );
    } catch (e, st) {
      Log.e(
        'Copie de l’original dans le coffre impossible',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }

    String? relativeAudioPath;
    int audioByteSize = 0;
    if (sourceAudioFile != null && sourceAudioFile.path.isNotEmpty) {
      if (await sourceAudioFile.exists()) {
        try {
          relativeAudioPath = await _vault.storeMasterpieceAudio(
            sourceFile: sourceAudioFile,
            masterpieceId: id,
            version: 1,
          );
          audioByteSize = await sourceAudioFile.length();
        } catch (e, st) {
          Log.e(
            'Copie de l’enregistrement vocal dans le coffre impossible ($id)',
            e,
            st,
            'MasterpiecesRepo',
          );
          await _vault.deleteFileOrEnqueueCleanup(
            relativePath: relativePath,
            db: _db,
          );
          return ActionFailed(_mapWriteException(e, st));
        }
      }
    }

    try {
      await _db.transaction(() async {
        await _db
            .into(_db.masterpiecesTable)
            .insert(
              MasterpiecesTableCompanion.insert(
                id: id,
                childId: childId,
                relativeImagePath: Value(relativePath),
                addedAt: addedAt,
                drawnAt: Value(drawnAt),
                story: Value(normalizedStory),
                imageWidth: Value(dimensions.$1),
                imageHeight: Value(dimensions.$2),
                relativeAudioPath: Value(relativeAudioPath),
                audioDurationMs: Value(audioDurationMs),
                audioByteSize: Value(audioByteSize),
                syncState: const Value('localOnly'),
              ),
            );
        await _outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: id,
          op: SyncOutboxOp.upsert,
        );
      });
    } catch (e, st) {
      Log.e(
        'Création locale de l’œuvre impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      await _vault.deleteFileOrEnqueueCleanup(
        relativePath: relativePath,
        db: _db,
      );
      if (relativeAudioPath != null) {
        await _vault.deleteAudioFileOrEnqueueCleanup(
          relativeAudioPath: relativeAudioPath,
          db: _db,
        );
      }
      return ActionFailed(_mapWriteException(e, st));
    }

    await ensureDerivatives(id);

    Log.i('Œuvre créée localement ($id)', 'MasterpiecesRepo');

    return ActionSuccess(id);
  }

  @override
  Future<ActionResult<void>> updateStory({
    required String id,
    required String? story,
  }) async {
    final normalized = _normalizeStory(story);
    int rows;
    try {
      rows = await _db.transaction(() async {
        final written =
            await (_db.update(_db.masterpiecesTable)
                  ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
                .write(MasterpiecesTableCompanion(story: Value(normalized)));
        if (written > 0) {
          await _outbox.enqueue(
            entity: SyncEntityKind.masterpiece,
            entityId: id,
            op: SyncOutboxOp.upsert,
          );
        }
        return written;
      });
    } catch (e, st) {
      Log.e('Mise à jour du récit impossible ($id)', e, st, 'MasterpiecesRepo');
      return ActionFailed(_mapWriteException(e, st));
    }
    if (rows == 0) {
      return const ActionFailed(NotFoundFailure());
    }

    final reread = await getById(id);
    if (reread == null || reread.story != normalized) {
      return const ActionFailed(LocalWriteFailure());
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> updateDrawnAt({
    required String id,
    required DateTime? drawnAt,
  }) async {
    int rows;
    try {
      rows = await _db.transaction(() async {
        final written =
            await (_db.update(_db.masterpiecesTable)
                  ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
                .write(MasterpiecesTableCompanion(drawnAt: Value(drawnAt)));
        if (written > 0) {
          await _outbox.enqueue(
            entity: SyncEntityKind.masterpiece,
            entityId: id,
            op: SyncOutboxOp.upsert,
          );
        }
        return written;
      });
    } catch (e, st) {
      Log.e(
        'Mise à jour de la date impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    if (rows == 0) {
      return const ActionFailed(NotFoundFailure());
    }

    final reread = await getById(id);
    if (reread == null || reread.drawnAt != drawnAt) {
      return const ActionFailed(LocalWriteFailure());
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> markSynced(String id) async {
    int rows;
    try {
      rows =
          await (_db.update(
            _db.masterpiecesTable,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            const MasterpiecesTableCompanion(syncState: Value('synced')),
          );
    } catch (e, st) {
      Log.e(
        'Mise à jour de synchronisation impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    if (rows == 0) {
      return const ActionFailed(NotFoundFailure());
    }

    final reread = await getById(id);
    if (reread == null || reread.syncState != SyncState.synced) {
      return const ActionFailed(LocalWriteFailure());
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> updateAudio({
    required String id,
    required File sourceAudioFile,
    required int durationMs,
  }) async {
    final current = await getById(id);
    if (current == null) {
      return const ActionFailed(NotFoundFailure());
    }

    if (!await sourceAudioFile.exists()) {
      return const ActionFailed(LocalWriteFailure());
    }

    String audioPath;
    final version = DateTime.now().millisecondsSinceEpoch;
    try {
      audioPath = await _vault.storeMasterpieceAudio(
        sourceFile: sourceAudioFile,
        masterpieceId: id,
        version: version,
      );
    } catch (e, st) {
      Log.e(
        'Copie du nouvel enregistrement audio impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }

    final fileSize = await sourceAudioFile.length();

    try {
      await _db.transaction(() async {
        final rows =
            await (_db.update(
              _db.masterpiecesTable,
            )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
              MasterpiecesTableCompanion(
                relativeAudioPath: Value(audioPath),
                audioDurationMs: Value(durationMs),
                audioByteSize: Value(fileSize),
                audioObjectKey: const Value(null),
                syncState: const Value('localOnly'),
              ),
            );
        if (rows == 0) throw StateError('Masterpiece row disappeared');
        await _outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: id,
          op: SyncOutboxOp.upsert,
        );
      });
    } catch (e, st) {
      Log.e(
        'Échec de la transaction mise à jour audio ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      await _vault.deleteAudioFileOrEnqueueCleanup(
        relativeAudioPath: audioPath,
        db: _db,
      );
      return ActionFailed(_mapWriteException(e, st));
    }

    if (current.relativeAudioPath != null &&
        current.relativeAudioPath != audioPath) {
      await _vault.deleteAudioFileOrEnqueueCleanup(
        relativeAudioPath: current.relativeAudioPath,
        db: _db,
      );
    }

    final reread = await getById(id);
    if (reread == null ||
        reread.relativeAudioPath != audioPath ||
        reread.audioDurationMs != durationMs) {
      return const ActionFailed(LocalWriteFailure());
    }

    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> clearAudio(String id) async {
    final current = await getById(id);
    if (current == null) {
      return const ActionFailed(NotFoundFailure());
    }

    try {
      await _db.transaction(() async {
        final rows =
            await (_db.update(
              _db.masterpiecesTable,
            )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
              const MasterpiecesTableCompanion(
                relativeAudioPath: Value(null),
                audioDurationMs: Value(null),
                audioByteSize: Value(0),
                audioObjectKey: Value(null),
                syncState: Value('localOnly'),
              ),
            );
        if (rows == 0) throw StateError('Masterpiece row disappeared');
        await _outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: id,
          op: SyncOutboxOp.upsert,
        );
      });
    } catch (e, st) {
      Log.e(
        'Échec de l’effacement de l’audio ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }

    if (current.relativeAudioPath != null) {
      await _vault.deleteAudioFileOrEnqueueCleanup(
        relativeAudioPath: current.relativeAudioPath,
        db: _db,
      );
    }

    final reread = await getById(id);
    if (reread == null ||
        reread.relativeAudioPath != null ||
        reread.audioDurationMs != null) {
      return const ActionFailed(LocalWriteFailure());
    }

    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> markAudioDownloaded({
    required String id,
    required String audioRelativePath,
  }) async {
    try {
      final rows =
          await (_db.update(
            _db.masterpiecesTable,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            MasterpiecesTableCompanion(
              relativeAudioPath: Value(audioRelativePath),
            ),
          );
      if (rows == 0) return const ActionFailed(NotFoundFailure());
    } catch (e, st) {
      Log.e(
        'Enregistrement de l’audio téléchargé impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> delete(String id) async {
    final current = await getById(id);
    if (current == null) {
      return const ActionFailed(NotFoundFailure());
    }

    if (deletionStrategy == ArtworkDeletionStrategy.localRecoverable) {
      final deletedAt = _now();
      try {
        final rows =
            await (_db.update(_db.masterpiecesTable)
                  ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
                .write(MasterpiecesTableCompanion(deletedAt: Value(deletedAt)));
        if (rows == 0) return const ActionFailed(NotFoundFailure());
        final persisted = await (_db.select(
          _db.masterpiecesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (persisted?.deletedAt == null ||
            !persisted!.deletedAt!.isAtSameMomentAs(deletedAt)) {
          return const ActionFailed(LocalWriteFailure());
        }
        return const ActionSuccess(null);
      } catch (e, st) {
        Log.e(
          'Mise à la Corbeille locale impossible ($id)',
          e,
          st,
          'MasterpiecesRepo',
        );
        return ActionFailed(_mapWriteException(e, st));
      }
    }

    try {
      await _db.transaction(() async {
        final rows = await (_db.delete(
          _db.masterpiecesTable,
        )..where((t) => t.id.equals(id))).go();
        if (rows == 0) {
          throw StateError(
            'masterpiece row disappeared during delete transaction',
          );
        }
        await _outbox.enqueue(
          entity: SyncEntityKind.masterpiece,
          entityId: id,
          op: SyncOutboxOp.delete,
        );
      });
    } catch (e, st) {
      Log.e(
        'Suppression locale de l’œuvre impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }

    if (current.relativeImagePath != null) {
      await _vault.deleteFileOrEnqueueCleanup(
        relativePath: current.relativeImagePath!,
        db: _db,
      );
    }
    if (current.relativeAudioPath != null) {
      await _vault.deleteAudioFileOrEnqueueCleanup(
        relativeAudioPath: current.relativeAudioPath,
        db: _db,
      );
    }
    await _vault.deleteDerivativeFilesOrEnqueueCleanup(
      displayRelativePath: current.displayImagePath,
      thumbnailRelativePath: current.thumbnailImagePath,
      db: _db,
    );
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> ensureDerivatives(String id) async {
    final current = await getById(id);
    if (current == null) {
      return const ActionFailed(NotFoundFailure());
    }

    if (current.displayImagePath != null &&
        current.thumbnailImagePath != null) {
      final displayFile = await _vault.resolveFile(current.displayImagePath!);
      final thumbnailFile = await _vault.resolveFile(
        current.thumbnailImagePath!,
      );
      if (await displayFile.exists() && await thumbnailFile.exists()) {
        return const ActionSuccess(null);
      }
    }

    final originalPath = current.relativeImagePath;
    if (originalPath == null) {
      return const ActionSuccess(null);
    }

    final outcome = await _vault.generateDerivatives(
      masterpieceId: id,
      originalRelativePath: originalPath,
    );

    final producedSomethingNew =
        outcome.displayRelativePath != null ||
        outcome.thumbnailRelativePath != null;
    if (!producedSomethingNew &&
        current.displayImagePath == null &&
        current.thumbnailImagePath == null) {
      return const ActionFailed(ImageUnreadableFailure());
    }

    try {
      await (_db.update(
        _db.masterpiecesTable,
      )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
        MasterpiecesTableCompanion(
          displayImagePath: outcome.displayRelativePath != null
              ? Value(outcome.displayRelativePath)
              : const Value.absent(),
          thumbnailImagePath: outcome.thumbnailRelativePath != null
              ? Value(outcome.thumbnailRelativePath)
              : const Value.absent(),
        ),
      );
    } catch (e, st) {
      Log.e(
        'Enregistrement des dérivés impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<DerivativeBackfillSummary> backfillMissingDerivatives() async {
    final rows =
        await (_db.select(_db.masterpiecesTable)..where(
              (t) =>
                  (t.displayImagePath.isNull() |
                      t.thumbnailImagePath.isNull()) &
                  t.relativeImagePath.isNotNull() &
                  t.deletedAt.isNull(),
            ))
            .get();

    var succeeded = 0;
    var failed = 0;
    for (final row in rows) {
      final result = await ensureDerivatives(row.id);
      if (result is ActionSuccess) {
        succeeded++;
      } else {
        failed++;
      }
    }
    return DerivativeBackfillSummary(
      attempted: rows.length,
      succeeded: succeeded,
      failed: failed,
    );
  }

  @override
  Future<ActionResult<void>> upsertFromRemote({
    required String id,
    required String childId,
    required DateTime addedAt,
    DateTime? drawnAt,
    String? story,
    String? displayObjectKey,
    String? thumbnailObjectKey,
    String? audioObjectKey,
    int? audioDurationMs,
    int audioByteSize = 0,
    required int byteSize,
    int? imageWidth,
    int? imageHeight,
  }) async {
    try {
      final existing = await getById(id);
      final hasLocalImage =
          existing?.relativeImagePath != null ||
          existing?.displayImagePath != null ||
          existing?.thumbnailImagePath != null;
      final syncState = hasLocalImage ? 'synced' : 'remoteThumbnail';

      String? preservedAudioPath;
      if (existing != null && existing.relativeAudioPath != null) {
        final row = await (_db.select(
          _db.masterpiecesTable,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (row?.audioObjectKey == audioObjectKey && audioObjectKey != null) {
          preservedAudioPath = existing.relativeAudioPath;
        } else {
          await _vault.deleteAudioFileOrEnqueueCleanup(
            relativeAudioPath: existing.relativeAudioPath,
            db: _db,
          );
        }
      }

      await _db
          .into(_db.masterpiecesTable)
          .insertOnConflictUpdate(
            MasterpiecesTableCompanion.insert(
              id: id,
              childId: childId,
              addedAt: addedAt,
              drawnAt: Value(drawnAt),
              story: Value(story),
              syncState: Value(syncState),
              displayObjectKey: Value(displayObjectKey),
              thumbnailObjectKey: Value(thumbnailObjectKey),
              audioObjectKey: Value(audioObjectKey),
              relativeAudioPath: Value(preservedAudioPath),
              audioDurationMs: Value(audioDurationMs),
              audioByteSize: Value(audioByteSize),
              byteSize: Value(byteSize),
              imageWidth: Value(imageWidth),
              imageHeight: Value(imageHeight),
              deletedAt: const Value(null),
            ),
          );
    } catch (e, st) {
      Log.e(
        'Application d’œuvre distante impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> applyRemoteTombstone(String id) async {
    final current = await getById(id);
    if (current == null) {
      return const ActionSuccess(null);
    }
    try {
      await (_db.delete(
        _db.masterpiecesTable,
      )..where((t) => t.id.equals(id))).go();
    } catch (e, st) {
      Log.e(
        'Application du tombstone œuvre impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    if (current.relativeImagePath != null) {
      await _vault.deleteFileOrEnqueueCleanup(
        relativePath: current.relativeImagePath!,
        db: _db,
      );
    }
    if (current.relativeAudioPath != null) {
      await _vault.deleteAudioFileOrEnqueueCleanup(
        relativeAudioPath: current.relativeAudioPath,
        db: _db,
      );
    }
    await _vault.deleteDerivativeFilesOrEnqueueCleanup(
      displayRelativePath: current.displayImagePath,
      thumbnailRelativePath: current.thumbnailImagePath,
      db: _db,
    );
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> markThumbnailDownloaded({
    required String id,
    required String thumbnailRelativePath,
  }) async {
    final current = await getById(id);
    if (current == null) {
      return const ActionFailed(NotFoundFailure());
    }
    final hasOriginalOrDisplay =
        current.relativeImagePath != null || current.displayImagePath != null;
    try {
      await (_db.update(
        _db.masterpiecesTable,
      )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
        MasterpiecesTableCompanion(
          thumbnailImagePath: Value(thumbnailRelativePath),
          syncState: Value(hasOriginalOrDisplay ? 'synced' : 'remoteThumbnail'),
        ),
      );
    } catch (e, st) {
      Log.e(
        'Enregistrement de miniature téléchargée impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> markDownloadFailed(String id) async {
    try {
      final rows =
          await (_db.update(
            _db.masterpiecesTable,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            const MasterpiecesTableCompanion(
              syncState: Value('downloadFailed'),
            ),
          );
      if (rows == 0) {
        return const ActionFailed(NotFoundFailure());
      }
    } catch (e, st) {
      Log.e(
        'Marquage d’échec de téléchargement impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    return const ActionSuccess(null);
  }

  @override
  Future<ActionResult<void>> markDisplayDownloaded({
    required String id,
    required String displayRelativePath,
  }) async {
    try {
      final rows =
          await (_db.update(
            _db.masterpiecesTable,
          )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
            MasterpiecesTableCompanion(
              displayImagePath: Value(displayRelativePath),
              syncState: const Value('synced'),
            ),
          );
      if (rows == 0) {
        return const ActionFailed(NotFoundFailure());
      }
    } catch (e, st) {
      Log.e(
        'Enregistrement de visuel téléchargé impossible ($id)',
        e,
        st,
        'MasterpiecesRepo',
      );
      return ActionFailed(_mapWriteException(e, st));
    }
    return const ActionSuccess(null);
  }
}
