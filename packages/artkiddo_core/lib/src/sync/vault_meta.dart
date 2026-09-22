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
class FamilyMismatchException implements Exception {
  final String vaultFamilyId;
  final String authenticatedFamilyId;
  const FamilyMismatchException({
    required this.vaultFamilyId,
    required this.authenticatedFamilyId,
  });

  @override
  String toString() =>
      'FamilyMismatchException: this vault is already attached to family $vaultFamilyId, '
      'but the authenticated account belongs to family $authenticatedFamilyId';
}

/// The one row of `VaultMetaTable` this device keeps: which household
/// (if any) this local vault is attached to, and how far each
/// independent `pull` stream got.
///
/// `familyId` is written exactly once, at the vault's first remote
/// attachment; every later sync must find the same value or refuse
/// ([FamilyMismatchException]). The independent cursors are always the
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
          familyId: null,
          joinResetPending: false,
          lastPullCursor: null,
        );
  }

  Future<String?> getFamilyId() async => (await _readOrCreate()).familyId;

  Future<bool> isJoinResetPending() async =>
      (await _readOrCreate()).joinResetPending;

  Future<void> markJoinResetPending() async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          const VaultMetaTableCompanion(
            id: Value(_singletonId),
            joinResetPending: Value(true),
          ),
        );
  }

  Future<void> clearJoinResetPending() async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          const VaultMetaTableCompanion(
            id: Value(_singletonId),
            joinResetPending: Value(false),
          ),
        );
  }

  Future<PullCursorSet> getPullCursors() async {
    final row = await _readOrCreate();
    return PullCursorSet(
      children: row.childrenPullCursor,
      artworks: row.artworksPullCursor,
      purged: row.purgedPullCursor,
    );
  }

  Future<DateTime?> getChildrenPullCursor() async =>
      (await getPullCursors()).children;

  Future<DateTime?> getArtworksPullCursor() async =>
      (await getPullCursors()).artworks;

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
      if (cursors.artworks != null) cursors.artworks!,
      if (cursors.purged != null) cursors.purged!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Writes `familyId` for the first time. A no-op (not an error) if
  /// this vault is already attached to the *same* household (restoring
  /// a reinstalled app). Throws [FamilyMismatchException] if the vault
  /// already belongs to a *different* household — see the isolation
  /// rule this class exists to enforce.
  Future<void> attachFamily(String familyId) async {
    final current = await getFamilyId();
    if (current == familyId) return;
    if (current != null && current != familyId) {
      throw FamilyMismatchException(
        vaultFamilyId: current,
        authenticatedFamilyId: familyId,
      );
    }
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            familyId: Value(familyId),
          ),
        );
  }

  /// Verifies (without writing) that `familyId` is compatible with this
  /// vault: either unattached yet, or already attached to exactly this
  /// household. Throws [FamilyMismatchException] otherwise. Callers
  /// that only want to check before deciding whether to proceed use
  /// this instead of [attachFamily].
  Future<void> assertCompatible(String familyId) async {
    final current = await getFamilyId();
    if (current != null && current != familyId) {
      throw FamilyMismatchException(
        vaultFamilyId: current,
        authenticatedFamilyId: familyId,
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
            artworksPullCursor: Value(cursors.artworks),
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

  Future<void> setArtworksPullCursor(DateTime cursor) async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            artworksPullCursor: Value(cursor),
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
        artworks: cursor,
        purged: cursor,
      ),
    );
  }

  /// Called after a successful account deletion when the member chose
  /// to keep their local vault. The member no longer belongs to any
  /// household server-side (the deletion flow already removed that
  /// membership on their behalf), so this vault becomes a strictly
  /// local one — consistent with the rule this class otherwise
  /// enforces: [attachFamily] would refuse a future sign-in to a
  /// *different* household if `familyId` stayed set to one the account
  /// no longer belongs to. `lastPullCursor` is left untouched: it
  /// describes this vault's own history, not its household
  /// attachment.
  Future<void> detachFamily() async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            familyId: const Value(null),
          ),
        );
  }
}
