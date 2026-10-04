import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../logging/log.dart';

part 'app_database.g.dart';

@DataClassName('ChildEntity')
class ChildrenTable extends Table {
  TextColumn get id => text()(); // UUIDv4 primary key
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get birthDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('localOnly'))();

  /// Last remote revision known for each synchronized field
  /// (`ChildSyncFields`); `0` until the remote side has acknowledged it. A
  /// new operation names these as its base revisions.
  IntColumn get nameRev => integer().withDefault(const Constant(0))();
  IntColumn get birthDateRev => integer().withDefault(const Constant(0))();
  IntColumn get lifecycleRev => integer().withDefault(const Constant(0))();

  /// Set when the child was purged remotely while artworks of it are still
  /// in the local trash: the row stays as their parent, hidden from every
  /// list, until the last of them is gone.
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  String get tableName => 'children';

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ArtworkEntity')
class ArtworksTable extends Table {
  TextColumn get id => text()(); // UUIDv4 primary key
  TextColumn get childId =>
      text().references(ChildrenTable, #id, onDelete: KeyAction.cascade)();

  TextColumn get relativeImagePath => text().nullable()();

  DateTimeColumn get addedAt => dateTime().named('created_at')();

  DateTimeColumn get drawnAt => dateTime().nullable()();

  TextColumn get story => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('localOnly'))();

  TextColumn get displayImagePath => text().nullable()();
  TextColumn get thumbnailImagePath => text().nullable()();

  IntColumn get imageWidth => integer().nullable()();
  IntColumn get imageHeight => integer().nullable()();

  /// Opaque object-storage keys. The public core never encodes a provider
  /// specific key format; an optional capability owns their meaning.
  TextColumn get displayObjectKey =>
      text().nullable().named('display_object_key')();
  TextColumn get thumbnailObjectKey =>
      text().nullable().named('thumbnail_object_key')();

  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  TextColumn get relativeAudioPath => text().nullable()();
  IntColumn get audioDurationMs => integer().nullable()();
  TextColumn get audioObjectKey =>
      text().nullable().named('audio_object_key')();
  IntColumn get audioByteSize => integer().withDefault(const Constant(0))();

  /// Baseline acknowledged by the remote store, independent of local edits.
  IntColumn get audioRevision => integer().withDefault(const Constant(0))();
  TextColumn get audioSyncIntent =>
      text().withDefault(const Constant('keep'))();
  BoolColumn get audioConflict =>
      boolean().withDefault(const Constant(false))();

  TextColumn get addedBy => text().nullable().named('added_by')();

  /// Last remote revision known for each synchronized field
  /// (`ArtworkSyncFields`). The audio revision is [audioRevision].
  IntColumn get storyRev => integer().withDefault(const Constant(0))();
  IntColumn get drawnAtRev => integer().withDefault(const Constant(0))();
  IntColumn get lifecycleRev => integer().withDefault(const Constant(0))();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  /// Set when the artwork was purged remotely while this device kept it in
  /// its trash (its files or operations). Restored here, it exists on this
  /// device only: the remote side refuses to bring it back.
  DateTimeColumn get remotePurgedAt => dateTime().nullable()();

  @override
  String get tableName => 'artworks';

  @override
  Set<Column> get primaryKey => {id};
}

/// The durable operation queue.
///
/// One row is one operation with a stable [opId]. While `pending` it may be
/// merged with a later edit of the same entity; once `in_flight` (persisted
/// before the send) it never changes, so a replay after a crash carries the
/// same identifier and the same content.
@DataClassName('SyncOutboxEntryEntity')
class SyncOutboxTable extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get opId => text()
      .withDefault(
        const CustomExpression<String>(
          "(lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' || "
          "substr(hex(randomblob(2)), 2) || '-' || "
          "substr('89ab', 1 + (abs(random()) % 4), 1) || "
          "substr(hex(randomblob(2)), 2) || '-' || hex(randomblob(6))))",
        ),
      )
      .named('op_id')();

  /// Kept as `entity` (the entity type) so existing readers of the table keep
  /// working.
  TextColumn get entity => text()(); // 'child' | 'artwork'
  TextColumn get entityId => text()();
  TextColumn get op => text()(); // 'upsert' | 'delete'

  /// `EntityPatch.toJson`. Null for an operation that has no field snapshot
  /// yet: the content is then read from the row when the operation is sent.
  TextColumn get patchJson => text().nullable()();

  /// 'pending' | 'in_flight'.
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'sync_outbox';

  @override
  List<Set<Column>> get uniqueKeys => [
    {opId},
  ];
}

/// Values that lost a conflict, kept for 30 days. Local only: never sent.
@DataClassName('ReplacedValueEntity')
class ReplacedValuesTable extends Table {
  TextColumn get id => text()(); // UUIDv4
  TextColumn get entityType => text()(); // 'child' | 'artwork'
  TextColumn get entityId => text()();
  TextColumn get field => text()();
  TextColumn get valueJson => text()();

  /// `MediaRef.toJson` when the value is a media version.
  TextColumn get mediaRef => text().nullable()();

  /// Whose value was replaced: 'remote' | 'local'.
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'replaced_values';

  @override
  Set<Column> get primaryKey => {id};
}

/// Every media file version the vault holds. A version is immutable: a new
/// recording is a new row and a new file, never a rewrite. An artwork's
/// original and its audio share its id as `media_id` and are told apart by
/// `role`, each with its own version numbers.
@DataClassName('MediaVersionEntity')
class MediaVersionsTable extends Table {
  TextColumn get mediaId => text()();
  IntColumn get version => integer()();

  /// 'original' | 'optimized' | 'audio'.
  TextColumn get role => text()();

  /// Path relative to the vault, so it survives container moves.
  TextColumn get localPath => text()();
  IntColumn get byteSize => integer().withDefault(const Constant(0))();

  /// 'present' | 'missing' | 'pendingDownload'.
  TextColumn get state => text().withDefault(const Constant('present'))();

  @override
  String get tableName => 'media_versions';

  @override
  Set<Column> get primaryKey => {mediaId, version, role};
}

/// Remote artwork changes received before the child they belong to. Only the
/// latest change of an artwork is kept (it carries the whole state); it is
/// applied as soon as the child arrives.
@DataClassName('DeferredRemoteChangeEntity')
class DeferredRemoteChangesTable extends Table {
  TextColumn get artworkId => text()();
  TextColumn get childId => text()();

  /// `SyncChange.toJson`.
  TextColumn get changeJson => text()();

  @override
  String get tableName => 'deferred_remote_changes';

  @override
  Set<Column> get primaryKey => {artworkId};
}

/// Remote field values older than the revision this device holds, met while
/// reading the journal with no local operation on the field. That only
/// lasts when the remote history went back (a restore); otherwise a newer
/// change of the field follows and removes the entry. What is left when the
/// read ends is applied, the local value kept in `replaced_values`.
@DataClassName('OlderRemoteValueEntity')
class OlderRemoteValuesTable extends Table {
  TextColumn get entityId => text()();
  TextColumn get field => text()();

  /// `SyncChange.toJson` of the latest such change of the field.
  TextColumn get changeJson => text()();

  @override
  String get tableName => 'older_remote_values';

  @override
  Set<Column> get primaryKey => {entityId, field};
}

@DataClassName('VaultMetaEntity')
class VaultMetaTable extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text().nullable().named('family_id')();
  BoolColumn get joinResetPending => boolean()
      .withDefault(const Constant(false))
      .named('join_reset_pending')();

  DateTimeColumn get lastPullCursor => dateTime().nullable()();
  DateTimeColumn get childrenPullCursor =>
      dateTime().nullable().named('children_pull_cursor')();
  DateTimeColumn get artworksPullCursor =>
      dateTime().nullable().named('artworks_pull_cursor')();
  DateTimeColumn get purgedPullCursor =>
      dateTime().nullable().named('purged_pull_cursor')();

  /// Position in the remote change journal (`ChangeCursor.value`) and its
  /// generation, written in the transaction that applies the page they end.
  TextColumn get changeCursor => text().nullable().named('change_cursor')();
  IntColumn get changeGeneration =>
      integer().nullable().named('change_generation')();

  @override
  String get tableName => 'vault_meta';

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingFileCleanupEntity')
class PendingFileCleanupsTable extends Table {
  TextColumn get relativePath => text()();
  DateTimeColumn get failedAt => dateTime()();

  @override
  String get tableName => 'pending_file_cleanups';

  @override
  Set<Column> get primaryKey => {relativePath};
}

@DataClassName('ShareLinkUrlCacheEntity')
class ShareLinkUrlCacheTable extends Table {
  TextColumn get id => text()(); // opaque share token identifier
  TextColumn get url => text()();

  @override
  String get tableName => 'share_link_url_cache';

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ChildrenTable,
    ArtworksTable,
    PendingFileCleanupsTable,
    SyncOutboxTable,
    ReplacedValuesTable,
    MediaVersionsTable,
    DeferredRemoteChangesTable,
    OlderRemoteValuesTable,
    VaultMetaTable,
    ShareLinkUrlCacheTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({this.onPreBaselineWipe}) : super(_openConnection());

  /// [onPreBaselineWipe] empties the local vault files; it runs after a
  /// pre-baseline database was erased (see [migration]).
  AppDatabase.forTesting(super.executor, {this.onPreBaselineWipe});

  final Future<void> Function()? onPreBaselineWipe;

  /// Table that only the launch baseline has: the pre-baseline schema 1 (the
  /// state before the schema baseline reset) did not know it.
  static const String baselineMarkerTable = 'media_versions';

  /// Schema v1 is the launch baseline: every table is created by `onCreate`.
  /// Once a vault exists in the field, any schema change bumps this number,
  /// adds a step here, a snapshot in `drift_schemas/` and a case in
  /// `test/unit/local_data/migration_test.dart`.
  @override
  int get schemaVersion => 1;

  /// Pre-baseline databases are erased, never migrated (the only tester's
  /// data was disposable). They are recognised by two rules only:
  /// - a stored `user_version` above [schemaVersion] (old schemas 2 to 7),
  ///   which Drift reports as `from > to`;
  /// - `user_version == 1` without [baselineMarkerTable] (old schema 1).
  ///
  /// The wipe never applies to a database that carries the marker. A real
  /// future v2 must add an `onUpgrade` step that migrates, and must replace
  /// the downgrade rule with one that cannot mistake a pre-baseline v2..v7
  /// database for it (for example a new marker), before bumping the version.
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    // Drift reports a downgrade through `onUpgrade` too (`from > to`).
    onUpgrade: (Migrator m, int from, int to) async {
      if (from > to) await _wipeSchema(m);
    },
    beforeOpen: (details) async {
      if (!details.wasCreated &&
          details.versionBefore == 1 &&
          details.versionNow == 1 &&
          !await _hasTable(baselineMarkerTable)) {
        await _wipeSchema(createMigrator());
      }
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<bool> _hasTable(String name) async {
    final rows = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(name)],
    ).get();
    return rows.isNotEmpty;
  }

  /// Drops every table, view, trigger and index, recreates the baseline
  /// schema, then empties the vault files. Safe to repeat.
  Future<void> _wipeSchema(Migrator m) async {
    await customStatement('PRAGMA defer_foreign_keys = ON');
    final rows = await customSelect(
      'SELECT type, name FROM sqlite_master '
      "WHERE name NOT LIKE 'sqlite_%' "
      "AND type IN ('trigger', 'view', 'index', 'table')",
    ).get();
    for (final type in const ['trigger', 'view', 'index', 'table']) {
      for (final row in rows.where((r) => r.read<String>('type') == type)) {
        final name = row.read<String>('name').replaceAll('"', '""');
        await customStatement('DROP ${type.toUpperCase()} IF EXISTS "$name"');
      }
    }
    await m.createAll();
    try {
      await onPreBaselineWipe?.call();
    } catch (e, st) {
      Log.e('Effacement des fichiers du coffre impossible', e, st, 'Vault');
    }
  }

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'artkiddo_vault');
  }

  Future<void> eraseAllData() async {
    await transaction(() async {
      await delete(artworksTable).go();
      await delete(childrenTable).go();
      await delete(syncOutboxTable).go();
      await delete(replacedValuesTable).go();
      await delete(mediaVersionsTable).go();
      await delete(deferredRemoteChangesTable).go();
      await delete(olderRemoteValuesTable).go();
      await delete(pendingFileCleanupsTable).go();
      await delete(shareLinkUrlCacheTable).go();
      await delete(vaultMetaTable).go();
    });
  }
}
