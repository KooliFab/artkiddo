import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// How many artworks (the trash included) have something that never reached
/// the server: a row not acknowledged yet, an operation still queued for it,
/// or a voice story the server has not confirmed, or a purge by the server
/// that left it on this device only. A row known through the server
/// (`remoteThumbnail`) is not unsaved. This is what a destructive action on a
/// child or an account must show before it asks for confirmation, and it
/// agrees with `backupStatusFor`: outside the trash, an artwork counts here
/// exactly when its status is not "saved", except when the only reason is a
/// file missing from this device (the server still holds the artwork).
/// [childId] restricts the count to one child.
Future<int> countUnsavedArtworks(AppDatabase db, {String? childId}) async {
  final row = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM artworks a '
        "WHERE (a.sync_state NOT IN ('synced', 'remoteThumbnail') "
        "OR a.remote_purged_at IS NOT NULL OR a.audio_sync_intent <> 'keep' "
        'OR a.audio_conflict = 1 OR EXISTS ('
        "SELECT 1 FROM sync_outbox o WHERE o.entity = 'artwork' "
        'AND o.entity_id = a.id)) '
        'AND (?1 IS NULL OR a.child_id = ?1)',
        variables: [Variable<String>(childId)],
        readsFrom: {db.artworksTable, db.syncOutboxTable},
      )
      .getSingle();
  return row.read<int>('n');
}
