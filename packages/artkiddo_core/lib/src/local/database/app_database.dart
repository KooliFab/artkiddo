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
  Set<Column> get primaryKey => {id};
}

@DataClassName('MasterpieceEntity')
class MasterpiecesTable extends Table {
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
  Set<Column> get primaryKey => {id};
}

@DataClassName('SyncOutboxEntryEntity')
class SyncOutboxTable extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()(); // 'child' | 'masterpiece'
  TextColumn get entityId => text()();
  TextColumn get op => text()(); // 'upsert' | 'delete'
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextAttemptAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

@DataClassName('VaultMetaEntity')
class VaultMetaTable extends Table {
  TextColumn get id => text()();
  TextColumn get foyerId => text().nullable()();

  DateTimeColumn get lastPullCursor => dateTime().nullable()();
  DateTimeColumn get childrenPullCursor =>
      dateTime().nullable().named('children_pull_cursor')();
  DateTimeColumn get masterpiecesPullCursor =>
      dateTime().nullable().named('masterpieces_pull_cursor')();
  DateTimeColumn get purgedPullCursor =>
      dateTime().nullable().named('purged_pull_cursor')();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('PendingFileCleanupEntity')
class PendingFileCleanupsTable extends Table {
  TextColumn get relativePath => text()();
  DateTimeColumn get failedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {relativePath};
}

@DataClassName('ShareLinkUrlCacheEntity')
class ShareLinkUrlCacheTable extends Table {
  TextColumn get id => text()(); // share_tokens.id
  TextColumn get url => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    ChildrenTable,
    MasterpiecesTable,
    PendingFileCleanupsTable,
    SyncOutboxTable,
    VaultMetaTable,
    ShareLinkUrlCacheTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 11;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Keep the from >= 5 guards on every later migration step. The from < 5
      // branch rebuilds masterpieces_table and must not receive columns that
      // only exist in a schema version introduced after the rebuild.
      if (from < 2) {
        await m.createTable(pendingFileCleanupsTable);
      }
      if (from < 3) {
        await m.addColumn(masterpiecesTable, masterpiecesTable.drawnAt);
      }
      if (from < 4) {
        await m.addColumn(
          masterpiecesTable,
          masterpiecesTable.displayImagePath,
        );
        await m.addColumn(
          masterpiecesTable,
          masterpiecesTable.thumbnailImagePath,
        );
      }
      if (from < 5) {
        await m.createTable(syncOutboxTable);
        await m.createTable(vaultMetaTable);

        await m.addColumn(
          masterpiecesTable,
          masterpiecesTable.displayObjectKey,
        );
        await m.addColumn(
          masterpiecesTable,
          masterpiecesTable.thumbnailObjectKey,
        );

        await customStatement(
          'ALTER TABLE masterpieces_table RENAME TO masterpieces_table_v4',
        );
        await m.createTable(masterpiecesTable);
        await customStatement('''
              INSERT INTO masterpieces_table
                (id, child_id, relative_image_path, created_at, drawn_at, story, sync_state,
                 display_image_path, thumbnail_image_path, display_object_key, thumbnail_object_key)
              SELECT id, child_id, relative_image_path, created_at, drawn_at, story, sync_state,
                     display_image_path, thumbnail_image_path, NULL, NULL
              FROM masterpieces_table_v4
            ''');
        await customStatement('DROP TABLE masterpieces_table_v4');
      }
      if (from < 6 && to >= 6) {
        await m.createTable(shareLinkUrlCacheTable);
      }
      if (from < 7 && from >= 5 && to >= 7) {
        await m.addColumn(masterpiecesTable, masterpiecesTable.byteSize);
      }
      if (from < 8 && from >= 5 && to >= 8) {
        await customStatement(
          'ALTER TABLE masterpieces_table ADD COLUMN image_width INTEGER NULL',
        );
        await customStatement(
          'ALTER TABLE masterpieces_table ADD COLUMN image_height INTEGER NULL',
        );
      }
      if (from < 9 && from >= 5 && to >= 9) {
        await m.addColumn(
          masterpiecesTable,
          masterpiecesTable.relativeAudioPath,
        );
        await m.addColumn(masterpiecesTable, masterpiecesTable.audioDurationMs);
        // This column was historically called r2_key_audio. Keep that name
        // until the v11 rename below, even though the current Dart table uses
        // audio_object_key.
        await customStatement(
          'ALTER TABLE masterpieces_table '
          'ADD COLUMN r2_key_audio TEXT NULL',
        );
        await m.addColumn(masterpiecesTable, masterpiecesTable.audioByteSize);
      }
      if (from < 10 && to >= 10) {
        if (from >= 5) {
          await m.addColumn(masterpiecesTable, masterpiecesTable.deletedAt);
          await m.addColumn(vaultMetaTable, vaultMetaTable.childrenPullCursor);
          await m.addColumn(
            vaultMetaTable,
            vaultMetaTable.masterpiecesPullCursor,
          );
          await m.addColumn(vaultMetaTable, vaultMetaTable.purgedPullCursor);
        }
      }
      if (from < 11 && from >= 5 && to >= 11) {
        await customStatement(
          'ALTER TABLE masterpieces_table RENAME COLUMN r2_key_display TO display_object_key',
        );
        await customStatement(
          'ALTER TABLE masterpieces_table RENAME COLUMN r2_key_thumbnail TO thumbnail_object_key',
        );
        await customStatement(
          'ALTER TABLE masterpieces_table RENAME COLUMN r2_key_audio TO audio_object_key',
        );
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
      await delete(masterpiecesTable).go();
      await delete(childrenTable).go();
      await delete(syncOutboxTable).go();
      await delete(pendingFileCleanupsTable).go();
      await delete(shareLinkUrlCacheTable).go();
      await delete(vaultMetaTable).go();
    });
  }
}
