import 'package:drift/drift.dart';

import '../local/database/app_database.dart';
import '../contracts/sync_protocol.dart';

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
/// (if any) this local vault is attached to, and how far the device read
/// the remote change journal.
///
/// `familyId` is written exactly once, at the vault's first remote
/// attachment; every later sync must find the same value or refuse
/// ([FamilyMismatchException]). The journal cursor ([getChangeCursor]) is
/// opaque and written only with the page it ends; a null cursor means
/// "never pulled", which is exactly the join/restore starting point.
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

  /// Where the next journal read starts, or null to read from the
  /// beginning.
  Future<ChangeCursor?> getChangeCursor() async {
    final row = await _readOrCreate();
    final value = row.changeCursor;
    final generation = row.changeGeneration;
    if (value == null || generation == null) return null;
    return ChangeCursor(value: value, generation: generation);
  }

  /// Records the end of a page of the journal. Call it inside the
  /// transaction that applies that page.
  Future<void> setChangeCursor(ChangeCursor cursor) async {
    await _db
        .into(_db.vaultMetaTable)
        .insertOnConflictUpdate(
          VaultMetaTableCompanion.insert(
            id: _singletonId,
            changeCursor: Value(cursor.value),
            changeGeneration: Value(cursor.generation),
          ),
        );
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
