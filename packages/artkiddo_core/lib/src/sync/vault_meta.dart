import 'package:drift/drift.dart';

import '../local/database/app_database.dart';
import '../contracts/sync_backend.dart';

class FoyerMismatchException implements Exception {
  final String vaultFoyerId;
  final String authenticatedFoyerId;
  const FoyerMismatchException({
    required this.vaultFoyerId,
    required this.authenticatedFoyerId,
  });

  @override
  String toString() =>
      'FoyerMismatchException: this vault is already attached to foyer $vaultFoyerId, '
      'but the authenticated account belongs to foyer $authenticatedFoyerId';
}

class VaultMetaRepository {
  static const _singletonId = 'singleton';

  final AppDatabase _db;
  VaultMetaRepository(this._db);

  Future<VaultMetaEntity> _readOrCreate() async {
    final existing = await (_db.select(
      _db.vaultMetaTable,
    )..where((t) => t.id.equals(_singletonId))).getSingleOrNull();
    if (existing != null) return existing;
    final row = VaultMetaTableCompanion.insert(id: _singletonId);
    await _db
        .into(_db.vaultMetaTable)
        .insert(row, mode: InsertMode.insertOrIgnore);
    return (await (_db.select(
          _db.vaultMetaTable,
        )..where((t) => t.id.equals(_singletonId))).getSingleOrNull()) ??
        const VaultMetaEntity(
          id: _singletonId,
          foyerId: null,
          lastPullCursor: null,
        );
  }

  Future<String?> getFoyerId() async => (await _readOrCreate()).foyerId;

  Future<PullCursorSet> getPullCursors() async {
    final row = await _readOrCreate();
    return PullCursorSet(
      children: row.childrenPullCursor,
      masterpieces: row.masterpiecesPullCursor,
      purged: row.purgedPullCursor,
    );
  }

  Future<DateTime?> getChildrenPullCursor() async =>
      (await getPullCursors()).children;

  Future<DateTime?> getMasterpiecesPullCursor() async =>
      (await getPullCursors()).masterpieces;

  Future<DateTime?> getPurgedPullCursor() async =>
      (await getPullCursors()).purged;

  Future<DateTime?> getLastPullCursor() async {
    final cursors = await getPullCursors();
    final values = [
      if (cursors.children != null) cursors.children!,
      if (cursors.masterpieces != null) cursors.masterpieces!,
      if (cursors.purged != null) cursors.purged!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  Future<void> attachFoyer(String foyerId) async {
    final current = await getFoyerId();
    if (current == foyerId) return;
    if (current != null && current != foyerId) {
      throw FoyerMismatchException(
        vaultFoyerId: current,
        authenticatedFoyerId: foyerId,
      );
    }
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            foyerId: Value(foyerId),
          ),
        );
  }

  Future<void> assertCompatible(String foyerId) async {
    final current = await getFoyerId();
    if (current != null && current != foyerId) {
      throw FoyerMismatchException(
        vaultFoyerId: current,
        authenticatedFoyerId: foyerId,
      );
    }
  }

  Future<void> setPullCursor({required PullCursorSet cursors}) async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            childrenPullCursor: Value(cursors.children),
            masterpiecesPullCursor: Value(cursors.masterpieces),
            purgedPullCursor: Value(cursors.purged),
          ),
        );
  }

  Future<void> setChildrenPullCursor(DateTime cursor) async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            childrenPullCursor: Value(cursor),
          ),
        );
  }

  Future<void> setMasterpiecesPullCursor(DateTime cursor) async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            masterpiecesPullCursor: Value(cursor),
          ),
        );
  }

  Future<void> setPurgedPullCursor(DateTime cursor) async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            purgedPullCursor: Value(cursor),
          ),
        );
  }

  Future<void> setLastPullCursor(DateTime cursor) async {
    await setPullCursor(
      cursors: PullCursorSet(
        children: cursor,
        masterpieces: cursor,
        purged: cursor,
      ),
    );
  }

  Future<void> detachFoyer() async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            foyerId: const Value(null),
          ),
        );
  }
}
