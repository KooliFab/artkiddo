import 'package:drift/drift.dart';

import '../../contracts/trash.dart';
import '../database/app_database.dart';
import '../../domain/app_failure.dart';
import '../logging/log.dart';
import '../../domain/action_result.dart';
import '../storage/local_vault.dart';

class LocalTrashRepository implements TrashRepository {
  static const retention = Duration(days: 30);

  final AppDatabase _db;
  final LocalVault _vault;
  final DateTime Function() _now;

  LocalTrashRepository(this._db, this._vault, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  AppFailure _mapException(Object error, StackTrace stack) =>
      LocalWriteFailure(cause: error, stack: stack);

  @override
  Future<ActionResult<List<TrashedArtwork>>> listTrash({
    String? scopeId,
  }) async {
    try {
      final rows =
          await (_db.select(_db.masterpiecesTable)
                ..where((t) => t.deletedAt.isNotNull())
                ..orderBy([
                  (t) => OrderingTerm(
                    expression: t.deletedAt,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();
      if (rows.isEmpty) return const ActionSuccess(<TrashedArtwork>[]);

      final childIds = rows.map((row) => row.childId).toSet();
      final children = await (_db.select(
        _db.childrenTable,
      )..where((t) => t.id.isIn(childIds))).get();
      final names = {for (final child in children) child.id: child.name};

      return ActionSuccess([
        for (final row in rows)
          TrashedArtwork(
            id: row.id,
            childId: row.childId,
            childName: names[row.childId] ?? '',
            deletedAt: row.deletedAt!,
            purgeAt: row.deletedAt!.add(retention),
            story: row.story,
          ),
      ]);
    } catch (e, st) {
      Log.e('Chargement de la Corbeille locale impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<void>> restore(String masterpieceId) async {
    try {
      final row = await (_db.select(
        _db.masterpiecesTable,
      )..where((t) => t.id.equals(masterpieceId))).getSingleOrNull();
      if (row == null || row.deletedAt == null) {
        return const ActionSuccess(null);
      }
      final count =
          await (_db.update(_db.masterpiecesTable)..where(
                (t) => t.id.equals(masterpieceId) & t.deletedAt.isNotNull(),
              ))
              .write(
                const MasterpiecesTableCompanion(
                  deletedAt: Value(null),
                  syncState: Value('localOnly'),
                ),
              );
      if (count == 0) return const ActionSuccess(null);
      final restored = await (_db.select(
        _db.masterpiecesTable,
      )..where((t) => t.id.equals(masterpieceId))).getSingleOrNull();
      if (restored?.deletedAt != null) {
        return const ActionFailed(LocalWriteFailure());
      }
      return const ActionSuccess(null);
    } catch (e, st) {
      Log.e('Restauration locale impossible ($masterpieceId)', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<void>> purge(String masterpieceId) async {
    try {
      final row = await (_db.select(
        _db.masterpiecesTable,
      )..where((t) => t.id.equals(masterpieceId))).getSingleOrNull();
      if (row == null || row.deletedAt == null) {
        return const ActionSuccess(null);
      }
      return await _purgeRows([row]);
    } catch (e, st) {
      Log.e('Purge locale impossible ($masterpieceId)', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<void>> purgeAll({String? scopeId}) async {
    try {
      final rows = await (_db.select(
        _db.masterpiecesTable,
      )..where((t) => t.deletedAt.isNotNull())).get();
      return await _purgeRows(rows);
    } catch (e, st) {
      Log.e('Vidage de la Corbeille locale impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  @override
  Future<ActionResult<int>> purgeExpired({DateTime? now}) async {
    final cutoff = (now ?? _now()).subtract(retention);
    try {
      final rows =
          await (_db.select(_db.masterpiecesTable)..where(
                (t) =>
                    t.deletedAt.isNotNull() &
                    t.deletedAt.isSmallerOrEqualValue(cutoff),
              ))
              .get();
      final result = await _purgeRows(rows);
      return switch (result) {
        ActionSuccess() => ActionSuccess(rows.length),
        ActionFailed(failure: final failure) => ActionFailed(failure),
        ActionCancelled() => const ActionCancelled(),
      };
    } catch (e, st) {
      Log.e('Purge automatique locale impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }
  }

  Future<ActionResult<void>> _purgeRows(List<MasterpieceEntity> rows) async {
    if (rows.isEmpty) return const ActionSuccess(null);
    try {
      await _db.transaction(() async {
        await (_db.delete(
          _db.masterpiecesTable,
        )..where((t) => t.id.isIn(rows.map((row) => row.id)))).go();
      });
    } catch (e, st) {
      Log.e('Suppression des lignes de Corbeille impossible', e, st, 'Trash');
      return ActionFailed(_mapException(e, st));
    }

    for (final row in rows) {
      if (row.relativeImagePath != null) {
        await _vault.deleteFileOrEnqueueCleanup(
          relativePath: row.relativeImagePath!,
          db: _db,
        );
      }
      if (row.relativeAudioPath != null) {
        await _vault.deleteAudioFileOrEnqueueCleanup(
          relativeAudioPath: row.relativeAudioPath!,
          db: _db,
        );
      }
      await _vault.deleteDerivativeFilesOrEnqueueCleanup(
        displayRelativePath: row.displayImagePath,
        thumbnailRelativePath: row.thumbnailImagePath,
        db: _db,
      );
    }
    return const ActionSuccess(null);
  }
}
