import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:artkiddo_core/artkiddo_core.dart';

const _op1 = '11111111-1111-4111-8111-111111111111';
const _op2 = '22222222-2222-4222-8222-222222222222';
const _child = '00000000-0000-4000-8000-000000000003';
const _artwork = '00000000-0000-4000-8000-000000000005';
const _photoId = '00000000-0000-4000-8000-000000000006';
const _audioId = '00000000-0000-4000-8000-000000000007';
final _hash = 'a' * 64;
final _at = DateTime.utc(2026, 10, 1, 12);

MediaDescriptor _photo() => MediaDescriptor(
  mediaId: _photoId,
  version: 1,
  role: MediaRole.optimized,
  format: MediaFormat.jpeg,
  byteSize: 250000,
  sha256: _hash,
  widthPx: 1600,
  heightPx: 1200,
);

MediaDescriptor _audio({int version = 2}) => MediaDescriptor(
  mediaId: _audioId,
  version: version,
  role: MediaRole.audio,
  format: MediaFormat.m4a,
  byteSize: 1024,
  sha256: 'b' * 64,
  durationMs: 1000,
);

EntityPatch _artworkCreation() => EntityPatch(
  opId: _op1,
  entityType: SyncEntityType.artwork,
  entityId: _artwork,
  baseRevisions: const {'childId': 0, 'addedAt': 0, 'photo': 0, 'audio': 0},
  fields: {
    ArtworkSyncFields.childId: _child,
    ArtworkSyncFields.addedAt: syncInstantValue(_at),
    ArtworkSyncFields.photo: _photo().ref.toJson(),
    ArtworkSyncFields.audio: _audio().ref.toJson(),
  },
  media: [_photo(), _audio()],
  createdAt: _at,
);

EntityPatch _rename() => EntityPatch(
  opId: _op2,
  entityType: SyncEntityType.child,
  entityId: _child,
  baseRevisions: const {'name': 3, 'birthDate': 1},
  fields: {
    ChildSyncFields.name: 'Léa',
    ChildSyncFields.birthDate: syncDateValue(DateTime(2019, 4, 12)),
  },
  createdAt: _at,
);

/// Encodes to a JSON string and back, as a durable store would.
Object? _throughJson(Object value) => jsonDecode(jsonEncode(value));

void main() {
  group('round trip', () {
    test('EntityPatch survives JSON encoding', () {
      for (final patch in [_artworkCreation(), _rename()]) {
        final decoded = EntityPatch.fromJson(_throughJson(patch.toJson()));
        expect(decoded, patch);
        expect(decoded.hashCode, patch.hashCode);
      }
    });

    test('MediaDescriptor survives JSON encoding', () {
      for (final media in [_photo(), _audio()]) {
        expect(MediaDescriptor.fromJson(_throughJson(media.toJson())), media);
      }
    });

    test('MutationReceipt and FieldConflict survive JSON encoding', () {
      final receipt = MutationReceipt(
        opId: _op2,
        accepted: const {'birthDate': 2},
        conflicts: [
          FieldConflict(
            field: 'name',
            localValue: 'Léa',
            remoteValue: 'Léonie',
            baseRevision: 3,
            remoteRevision: 4,
            kind: FieldConflictKind.field,
          ),
        ],
      );
      final decoded = MutationReceipt.fromJson(_throughJson(receipt.toJson()));
      expect(decoded, receipt);
      expect(decoded.conflicts.single.remoteValue, 'Léonie');
    });

    test('a null conflict value stays explicit', () {
      final conflict = FieldConflict(
        field: 'audio',
        localValue: _audio().ref.toJson(),
        remoteValue: null,
        baseRevision: 2,
        remoteRevision: 3,
        kind: FieldConflictKind.audio,
      );
      final json = _throughJson(conflict.toJson())! as Map;
      expect(json.containsKey('remoteValue'), isTrue);
      expect(FieldConflict.fromJson(json), conflict);
    });

    test('SyncChangePage survives JSON encoding, purge included', () {
      final page = SyncChangePage(
        changes: [
          SyncChange(
            seq: 41,
            kind: SyncChangeKind.mediaVersion,
            entityType: SyncEntityType.artwork,
            entityId: _artwork,
            opId: _op1,
            snapshot: EntitySnapshot(
              fields: {
                'childId': _child,
                'addedAt': syncInstantValue(_at),
                'photo': _photo().ref.toJson(),
                'audio': _audio().ref.toJson(),
                'story': null,
                'lifecycle': 'active',
                'addedBy': null,
              },
              revisions: const {
                'childId': 1,
                'addedAt': 1,
                'photo': 1,
                'audio': 3,
                'lifecycle': 1,
              },
              media: [_photo(), _audio()],
              unavailableMedia: [_audio().ref],
            ),
          ),
          SyncChange(
            seq: 42,
            kind: SyncChangeKind.purge,
            entityType: SyncEntityType.child,
            entityId: _child,
            snapshot: null,
          ),
        ],
        nextCursor: ChangeCursor(value: 'opaque-42', generation: 2),
        hasMore: true,
        generation: 2,
      );
      expect(SyncChangePage.fromJson(_throughJson(page.toJson())), page);
    });

    test('ChangeCursor survives JSON encoding', () {
      final cursor = ChangeCursor(value: 'opaque', generation: 1);
      expect(ChangeCursor.fromJson(_throughJson(cursor.toJson())), cursor);
    });
  });

  group('EntityPatch rules', () {
    test('a creation is recognised only with every required field', () {
      expect(_artworkCreation().isCreation, isTrue);
      expect(_rename().isCreation, isFalse);
    });

    test('every field needs exactly one base revision', () {
      expect(
        () => EntityPatch(
          opId: _op1,
          entityType: SyncEntityType.child,
          entityId: _child,
          baseRevisions: const {},
          fields: const {'name': 'Léa'},
          createdAt: _at,
        ),
        throwsArgumentError,
      );
    });

    test('opId must be a UUID v4', () {
      expect(
        () => EntityPatch(
          opId: '00000000-0000-1000-8000-000000000000',
          entityType: SyncEntityType.child,
          entityId: _child,
          baseRevisions: const {'name': 1},
          fields: const {'name': 'Léa'},
          createdAt: _at,
        ),
        throwsArgumentError,
      );
    });

    test('unknown, remote-owned and late create-only fields are refused', () {
      for (final (field, value, base) in [
        ('colour', 'red', 1),
        ('addedBy', _child, 0),
        ('childId', _child, 1),
      ]) {
        expect(
          () => EntityPatch(
            opId: _op1,
            entityType: SyncEntityType.artwork,
            entityId: _artwork,
            baseRevisions: {field: base},
            fields: {field: value},
            createdAt: _at,
          ),
          throwsArgumentError,
          reason: field,
        );
      }
    });

    test('values are checked against their field type', () {
      for (final (field, value) in [
        ('name', ''),
        ('name', null),
        ('birthDate', '2019-02-30'),
        ('birthDate', '2019-04-12T00:00:00Z'),
        ('lifecycle', 'trashed'),
      ]) {
        expect(
          () => EntityPatch(
            opId: _op1,
            entityType: SyncEntityType.child,
            entityId: _child,
            baseRevisions: {field: 1},
            fields: {field: value},
            createdAt: _at,
          ),
          throwsArgumentError,
          reason: '$field=$value',
        );
      }
    });

    test('a lifecycle change carries no other field', () {
      final trash = EntityPatch(
        opId: _op1,
        entityType: SyncEntityType.artwork,
        entityId: _artwork,
        baseRevisions: const {'lifecycle': 1},
        fields: const {'lifecycle': 'trashed'},
        createdAt: _at,
      );
      expect(trash.fields, {'lifecycle': 'trashed'});
      expect(
        () => EntityPatch(
          opId: _op1,
          entityType: SyncEntityType.artwork,
          entityId: _artwork,
          baseRevisions: const {'lifecycle': 1, 'story': 1},
          fields: const {'lifecycle': 'trashed', 'story': 'x'},
          createdAt: _at,
        ),
        throwsArgumentError,
      );
    });

    test('media descriptors match the referenced versions exactly', () {
      EntityPatch withAudio(List<MediaDescriptor> media) => EntityPatch(
        opId: _op1,
        entityType: SyncEntityType.artwork,
        entityId: _artwork,
        baseRevisions: const {'audio': 2},
        fields: {'audio': _audio(version: 3).ref.toJson()},
        media: media,
        createdAt: _at,
      );

      expect(withAudio([_audio(version: 3)]).media, hasLength(1));
      expect(() => withAudio(const []), throwsArgumentError);
      expect(() => withAudio([_audio(version: 2)]), throwsArgumentError);
      expect(
        () => withAudio([_audio(version: 3), _photo()]),
        throwsArgumentError,
      );
    });

    test('an audio deletion is a null version without media', () {
      final patch = EntityPatch(
        opId: _op1,
        entityType: SyncEntityType.artwork,
        entityId: _artwork,
        baseRevisions: const {'audio': 3},
        fields: const {'audio': null},
        createdAt: _at,
      );
      expect(patch.fields['audio'], isNull);
    });

    test('fields are frozen once the patch exists', () {
      final patch = _rename();
      expect(() => patch.fields['name'] = 'x', throwsUnsupportedError);
      expect(() => patch.baseRevisions['name'] = 9, throwsUnsupportedError);
    });

    test('malformed JSON is a FormatException', () {
      final json = _rename().toJson()..['opId'] = 'nope';
      expect(() => EntityPatch.fromJson(json), throwsFormatException);
      expect(
        () => EntityPatch.fromJson({..._rename().toJson(), 'extra': 1}),
        throwsFormatException,
      );
    });
  });

  group('MediaDescriptor rules', () {
    test('optimized photos respect the cloud quality bounds', () {
      MediaDescriptor photo({int bytes = 1000, int edge = 1600}) =>
          MediaDescriptor(
            mediaId: _photoId,
            version: 1,
            role: MediaRole.optimized,
            format: MediaFormat.jpeg,
            byteSize: bytes,
            sha256: _hash,
            widthPx: edge,
            heightPx: 10,
          );

      expect(photo(bytes: kOptimizedPhotoMaxBytes).byteSize, 300000);
      expect(() => photo(bytes: 300001), throwsArgumentError);
      expect(() => photo(edge: 1601), throwsArgumentError);
    });

    test('audio carries a duration and originals never enter a patch', () {
      expect(
        () => MediaDescriptor(
          mediaId: _audioId,
          version: 1,
          role: MediaRole.audio,
          format: MediaFormat.m4a,
          byteSize: 10,
          sha256: _hash,
        ),
        throwsArgumentError,
      );
      final original = MediaDescriptor(
        mediaId: _photoId,
        version: 1,
        role: MediaRole.original,
        format: MediaFormat.heic,
        byteSize: 5000000,
        sha256: _hash,
      );
      expect(
        () => EntityPatch(
          opId: _op1,
          entityType: SyncEntityType.artwork,
          entityId: _artwork,
          baseRevisions: const {'photo': 0},
          fields: {'photo': original.ref.toJson()},
          media: [original],
          createdAt: _at,
        ),
        throwsArgumentError,
      );
    });
  });

  group('MutationReceipt rules', () {
    test('a receipt answers exactly the fields of its own opId', () {
      final patch = _rename();
      MutationReceipt(
        opId: _op2,
        accepted: const {'name': 4, 'birthDate': 2},
      ).ensureAnswers(patch);

      for (final receipt in [
        MutationReceipt(
          opId: _op1,
          accepted: const {'name': 4, 'birthDate': 2},
        ),
        MutationReceipt(opId: _op2, accepted: const {'name': 4}),
        MutationReceipt(
          opId: _op2,
          accepted: const {'name': 4, 'birthDate': 2, 'lifecycle': 2},
        ),
      ]) {
        expect(
          () => receipt.ensureAnswers(patch),
          throwsA(isA<MutationReceiptMismatchException>()),
        );
      }
    });

    test('a field is either accepted or in conflict', () {
      expect(
        () => MutationReceipt(
          opId: _op2,
          accepted: const {'name': 4},
          conflicts: [
            FieldConflict(
              field: 'name',
              localValue: 'a',
              remoteValue: 'b',
              baseRevision: 3,
              remoteRevision: 4,
              kind: FieldConflictKind.field,
            ),
          ],
        ),
        throwsArgumentError,
      );
    });

    test('a replay returns the same receipt flagged alreadyApplied', () {
      final first = MutationReceipt(opId: _op2, accepted: const {'name': 4});
      final replay = first.asReplay();
      expect(replay.alreadyApplied, isTrue);
      expect(replay.accepted, first.accepted);
      expect(replay.conflicts, first.conflicts);
      expect(replay, isNot(first));
    });
  });

  group('SyncChangePage rules', () {
    SyncChange upsert(int seq) => SyncChange(
      seq: seq,
      kind: SyncChangeKind.upsert,
      entityType: SyncEntityType.child,
      entityId: _child,
      snapshot: EntitySnapshot(
        fields: const {'name': 'Léa', 'lifecycle': 'active'},
        revisions: const {'name': 1, 'lifecycle': 1},
      ),
    );

    test('pages are bounded, ordered and bound to one generation', () {
      final cursor = ChangeCursor(value: 'c', generation: 1);
      expect(
        () => SyncChangePage(
          changes: [for (var i = 1; i <= 201; i++) upsert(i)],
          nextCursor: cursor,
          hasMore: true,
          generation: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SyncChangePage(
          changes: [upsert(2), upsert(2)],
          nextCursor: cursor,
          hasMore: false,
          generation: 1,
        ),
        throwsArgumentError,
      );
      expect(
        () => SyncChangePage(
          changes: [upsert(1)],
          nextCursor: cursor,
          hasMore: false,
          generation: 2,
        ),
        throwsArgumentError,
      );
      expect(
        SyncChangePage(
          changes: [for (var i = 1; i <= 200; i++) upsert(i)],
          nextCursor: cursor,
          hasMore: true,
          generation: 1,
        ).changes,
        hasLength(kMaxChangePageSize),
      );
    });

    test('only a purge has no snapshot and children have no trash', () {
      expect(
        () => SyncChange(
          seq: 1,
          kind: SyncChangeKind.upsert,
          entityType: SyncEntityType.child,
          entityId: _child,
          snapshot: null,
        ),
        throwsArgumentError,
      );
      expect(
        () => SyncChange(
          seq: 1,
          kind: SyncChangeKind.trash,
          entityType: SyncEntityType.child,
          entityId: _child,
          snapshot: upsert(1).snapshot,
        ),
        throwsArgumentError,
      );
    });

    test('unavailable media must be referenced by the snapshot', () {
      expect(
        () => SyncChange(
          seq: 1,
          kind: SyncChangeKind.upsert,
          entityType: SyncEntityType.artwork,
          entityId: _artwork,
          snapshot: EntitySnapshot(
            fields: const {'lifecycle': 'active'},
            revisions: const {'lifecycle': 1},
            unavailableMedia: [_audio().ref],
          ),
        ),
        throwsArgumentError,
      );
    });
  });
}
