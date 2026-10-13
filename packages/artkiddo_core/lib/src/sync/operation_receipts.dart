import 'dart:convert';

import 'package:drift/drift.dart';

import '../contracts/sync_protocol.dart';
import '../local/database/app_database.dart';
import 'replaced_values.dart';
import 'sync_outbox.dart';

/// What applying one [MutationReceipt] changed locally.
class ReceiptOutcome {
  /// Fields whose remote revision was recorded or handed to a later operation.
  final int accepted;

  /// Fields the remote side did not accept.
  final int conflicts;

  /// True when the receipt left new work in the queue (a local value that won
  /// a conflict is sent again on top of the remote revision).
  final bool resendQueued;

  const ReceiptOutcome({
    required this.accepted,
    required this.conflicts,
    required this.resendQueued,
  });
}

/// Applies the remote answer to exactly one operation.
///
/// Everything happens in **one transaction**, so a crash leaves either the
/// operation (replayed with the same `opId`) or its whole outcome:
///
/// * accepted field → its remote revision is recorded on the row, **unless a
///   later local operation also changes that field**; that operation then
///   takes the accepted revision as its base, because the local value has
///   moved on since the acknowledged operation was created;
/// * `field`/`audio` conflict → the remote value goes to `replaced_values`
///   and the local value wins: it is sent again with the remote revision as
///   its base (or, when a newer local edit of that field is already queued,
///   that edit simply takes the remote revision as its base);
/// * `deleteVsEdit` → the edit stays on the local row, is also recorded in
///   `replaced_values` (the entity may be purged remotely), and is not sent
///   again, so nothing is resurrected. A story or date is also held
///   ([ReplacedValuesRepository.hold]): the pull keeps it on the row, and a
///   remote restore sends it again; an accepted field releases it;
/// * the operation itself is removed. Operations of the same entity queued
///   after it are never touched.
class OutboxReceiptHandler {
  final AppDatabase _db;
  final SyncOutboxRepository _outbox;
  final ReplacedValuesRepository _replaced;

  OutboxReceiptHandler(this._db, this._outbox, this._replaced);

  /// Throws [MutationReceiptMismatchException] (changing nothing) unless
  /// [receipt] answers exactly [patch].
  Future<ReceiptOutcome> apply({
    required SyncOutboxEntryEntity entry,
    required EntityPatch patch,
    required MutationReceipt receipt,
  }) async {
    receipt.ensureAnswers(patch);
    return _db.transaction(() async {
      final entity = SyncEntityKind.of(patch.entityType);
      final later = [
        for (final op in await _outbox.operationsOf(entity, patch.entityId))
          if (op.seq > entry.seq) op,
      ];
      final specs = syncFieldSpecs(patch.entityType);

      var settled = true;
      for (final MapEntry(key: field, value: revision)
          in receipt.accepted.entries) {
        await _setRevision(patch, later, field, revision);
        // A held edit (or a newer one) is now the remote value.
        await _replaced.release(patch.entityId, field: field);
      }

      final resend = <String, Object?>{};
      final resendBase = <String, int>{};
      final resendMedia = <MediaDescriptor>[];
      for (final conflict in receipt.conflicts) {
        final field = conflict.field;
        switch (conflict.kind) {
          case FieldConflictKind.field || FieldConflictKind.audio:
            if (specs[field]?.rule == FieldMergeRule.lifecycle) {
              // A lifecycle is state, not a value to keep; the pull
              // converges it. The conflicting patch is not sent again.
              settled = false;
              break;
            }
            await _replaced.record(
              entityType: patch.entityType,
              entityId: patch.entityId,
              field: field,
              value: conflict.remoteValue,
              mediaRef: _mediaRefOf(conflict.remoteValue, conflict.kind),
              source: ReplacedValueSource.remote,
            );
            await _setRevision(patch, later, field, conflict.remoteRevision);
            if (!_changesField(later, field)) {
              resend[field] = patch.fields[field];
              resendBase[field] = conflict.remoteRevision;
              final ref = _mediaRefOf(patch.fields[field], conflict.kind);
              resendMedia.addAll([
                for (final descriptor in patch.media)
                  if (descriptor.ref == ref) descriptor,
              ]);
            }
          case FieldConflictKind.deleteVsEdit:
            settled = false;
            await _replaced.record(
              entityType: patch.entityType,
              entityId: patch.entityId,
              field: field,
              value: conflict.localValue,
              mediaRef: _mediaRefOf(
                conflict.localValue,
                field == ArtworkSyncFields.audio
                    ? FieldConflictKind.audio
                    : conflict.kind,
              ),
              source: ReplacedValueSource.local,
            );
            if (patch.entityType == SyncEntityType.artwork &&
                field != ArtworkSyncFields.audio) {
              await _replaced.hold(
                entityType: patch.entityType,
                entityId: patch.entityId,
                field: field,
                value: conflict.localValue,
              );
            }
        }
      }

      if (resend.isNotEmpty) {
        await _outbox.enqueuePatch(
          EntityPatch(
            opId: _outbox.newOpId(),
            entityType: patch.entityType,
            entityId: patch.entityId,
            baseRevisions: resendBase,
            fields: resend,
            media: resendMedia,
            createdAt: DateTime.now(),
          ),
        );
      }

      await _outbox.markSucceeded(entry.seq);

      if (settled && !await _outbox.hasOperations(entity, patch.entityId)) {
        await _markSynced(patch);
      }

      return ReceiptOutcome(
        accepted: receipt.accepted.length,
        conflicts: receipt.conflicts.length,
        resendQueued: resend.isNotEmpty,
      );
    });
  }

  MediaRef? _mediaRefOf(Object? value, FieldConflictKind kind) =>
      kind == FieldConflictKind.audio && value != null
      ? MediaRef.fromJson(value)
      : null;

  bool _changesField(List<SyncOutboxEntryEntity> later, String field) =>
      later.any((op) => op.patch?.fields.containsKey(field) ?? false);

  Future<void> _setRevision(
    EntityPatch patch,
    List<SyncOutboxEntryEntity> later,
    String field,
    int revision,
  ) async {
    if (_changesField(later, field)) {
      await _rebase(later, field, revision);
    } else {
      await _writeRevision(patch, field, revision);
    }
  }

  /// A later local operation changes [field] on top of the revision the
  /// earlier operation just produced: that revision becomes its base.
  Future<void> _rebase(
    List<SyncOutboxEntryEntity> later,
    String field,
    int revision,
  ) async {
    for (final op in later) {
      final patch = op.patch;
      if (patch == null || !patch.fields.containsKey(field)) continue;
      if (syncFieldSpecs(patch.entityType)[field]!.rule ==
          FieldMergeRule.createOnly) {
        continue;
      }
      final rebased = EntityPatch(
        opId: patch.opId,
        entityType: patch.entityType,
        entityId: patch.entityId,
        baseRevisions: {...patch.baseRevisions, field: revision},
        fields: patch.fields,
        media: patch.media,
        createdAt: patch.createdAt,
      );
      await (_db.update(
        _db.syncOutboxTable,
      )..where((t) => t.seq.equals(op.seq))).write(
        SyncOutboxTableCompanion(
          patchJson: Value(jsonEncode(rebased.toJson())),
        ),
      );
    }
  }

  /// Records [revision] as the last remote revision of [field] on the row.
  /// Create-only fields have no revision column.
  Future<void> _writeRevision(
    EntityPatch patch,
    String field,
    int revision,
  ) async {
    switch (patch.entityType) {
      case SyncEntityType.child:
        final companion = switch (field) {
          ChildSyncFields.name => ChildrenTableCompanion(
            nameRev: Value(revision),
          ),
          ChildSyncFields.birthDate => ChildrenTableCompanion(
            birthDateRev: Value(revision),
          ),
          ChildSyncFields.lifecycle => ChildrenTableCompanion(
            lifecycleRev: Value(revision),
          ),
          _ => null,
        };
        if (companion == null) return;
        await (_db.update(
          _db.childrenTable,
        )..where((t) => t.id.equals(patch.entityId))).write(companion);
      case SyncEntityType.artwork:
        final companion = switch (field) {
          ArtworkSyncFields.story => ArtworksTableCompanion(
            storyRev: Value(revision),
          ),
          ArtworkSyncFields.drawnAt => ArtworksTableCompanion(
            drawnAtRev: Value(revision),
          ),
          ArtworkSyncFields.audio => ArtworksTableCompanion(
            audioRevision: Value(revision),
          ),
          ArtworkSyncFields.lifecycle => ArtworksTableCompanion(
            lifecycleRev: Value(revision),
          ),
          _ => null,
        };
        if (companion == null) return;
        await (_db.update(
          _db.artworksTable,
        )..where((t) => t.id.equals(patch.entityId))).write(companion);
    }
  }

  /// Nothing local is left to send for the entity: its row is in sync.
  Future<void> _markSynced(EntityPatch patch) async {
    switch (patch.entityType) {
      case SyncEntityType.child:
        await (_db.update(_db.childrenTable)
              ..where((t) => t.id.equals(patch.entityId)))
            .write(const ChildrenTableCompanion(syncState: Value('synced')));
      case SyncEntityType.artwork:
        await (_db.update(_db.artworksTable)..where(
              (t) =>
                  t.id.equals(patch.entityId) &
                  t.deletedAt.isNull() &
                  t.syncState.isIn(const ['localOnly', 'syncError']),
            ))
            .write(const ArtworksTableCompanion(syncState: Value('synced')));
    }
  }
}
