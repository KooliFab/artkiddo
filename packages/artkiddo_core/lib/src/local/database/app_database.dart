import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DataClassName('ChildEntity')
class ChildrenTable extends Table {
  TextColumn get id => text()(); // UUIDv4 primary key
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get birthDate => dateTime()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get syncState => text().withDefault(const Constant('localOnly'))();

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

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  String get tableName => 'artworks';

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOutboxEntryEntity')
class SyncOutboxTable extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()(); // 'child' | 'artwork'
  TextColumn get entityId => text()();
  TextColumn get op => text()(); // 'upsert' | 'delete'
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  String get tableName => 'sync_outbox';
}

@DataClassName('VaultMetaEntity')
class VaultMetaTable extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text().nullable().named('family_id')();
  BoolColumn get joinResetPending =>
      boolean().withDefault(const Constant(false)).named('join_reset_pending')();

  DateTimeColumn get lastPullCursor => dateTime().nullable()();
  DateTimeColumn get childrenPullCursor =>
      dateTime().nullable().named('children_pull_cursor')();
  DateTimeColumn get artworksPullCursor =>
      dateTime().nullable().named('artworks_pull_cursor')();
  DateTimeColumn get purgedPullCursor =>
      dateTime().nullable().named('purged_pull_cursor')();

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
    VaultMetaTable,
    ShareLinkUrlCacheTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  /// Schema v1 is a deliberate clean baseline. Schema v2 adds the durable
  /// join-reset marker used to recover if the process dies after the server
  /// commits a family switch but before the local vault is erased.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(vaultMetaTable, vaultMetaTable.joinResetPending);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'artkiddo_vault');
  }

  Future<void> eraseAllData() async {
    await transaction(() async {
      await delete(artworksTable).go();
      await delete(childrenTable).go();
      await delete(syncOutboxTable).go();
      await delete(pendingFileCleanupsTable).go();
      await delete(shareLinkUrlCacheTable).go();
      await delete(vaultMetaTable).go();
    });
  }
}
