import 'package:drift/drift.dart';

import '../local/database/app_database.dart';
import '../contracts/sync_backend.dart';

/// Thrown when the authenticated user's household does not match the
/// household this local vault is already attached to. The only two
/// ways out — stay local and sign out, or start a brand-new vault (new
/// Drift database, new vault directory) and restore that account's
/// household into it — are both a *device-level* decision, not
/// something [SyncEngine] can make on its own. [SyncEngine]'s job
/// stops at detecting the mismatch and refusing to sync in either
/// direction; the caller decides what happens next.
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

/// The one row of `VaultMetaTable` this device keeps: which household
/// (if any) this local vault is attached to, and how far each
/// independent `pull` stream got.
///
/// `foyerId` is written exactly once, at the vault's first remote
/// attachment; every later sync must find the same value or refuse
/// ([FoyerMismatchException]). The independent cursors are always the
/// maximal **server** timestamp their own stream has applied, never a
/// client clock. A null cursor means "never pulled" for that stream,
/// which is exactly the join/restore starting point.
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

  /// Compatibility read for pre-independent-cursor callers. New code
  /// must use [getPullCursors]; returning the maximum independent
  /// cursor preserves the old "last activity" status without coupling
  /// the streams again.
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

  /// Writes `foyerId` for the first time. A no-op (not an error) if
  /// this vault is already attached to the *same* household (restoring
  /// a reinstalled app). Throws [FoyerMismatchException] if the vault
  /// already belongs to a *different* household — see the isolation
  /// rule this class exists to enforce.
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

  /// Verifies (without writing) that `foyerId` is compatible with this
  /// vault: either unattached yet, or already attached to exactly this
  /// household. Throws [FoyerMismatchException] otherwise. Callers
  /// that only want to check before deciding whether to proceed use
  /// this instead of [attachFoyer].
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

  /// Compatibility bridge for old integrations. It deliberately writes
  /// all streams only when explicitly requested by a legacy caller;
  /// migrations never call it, so the single legacy cursor is not
  /// copied into the independent ones.
  Future<void> setLastPullCursor(DateTime cursor) async {
    await setPullCursor(
      cursors: PullCursorSet(
        children: cursor,
        masterpieces: cursor,
        purged: cursor,
      ),
    );
  }

  /// Called after a successful account deletion when the member chose
  /// to keep their local vault. The member no longer belongs to any
  /// household server-side (the deletion flow already removed that
  /// membership on their behalf), so this vault becomes a strictly
  /// local one — consistent with the rule this class otherwise
  /// enforces: [attachFoyer] would refuse a future sign-in to a
  /// *different* household if `foyerId` stayed set to one the account
  /// no longer belongs to. `lastPullCursor` is left untouched: it
  /// describes this vault's own history, not its household
  /// attachment.
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
