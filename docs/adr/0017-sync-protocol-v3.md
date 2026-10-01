# ADR 0017: Sync protocol v3

Status: accepted 2026-10-01; contracts in `src/contracts/sync_protocol.dart`,
engine and private adapter migrated (L07, L08). Supersedes the row-upsert and
timestamp-cursor parts of the former `SyncBackend`, removed in L08.

## Context

Two losses were reproduced with the v2 contract
(`test/unit/sync/loss_repro_*_test.dart`):

1. A rename made while a child is being pushed disappears. The outbox entry
   names only the entity, so the acknowledgement of the first push clears the
   newer edit, and the following pull writes the old row back.
2. A pull misses rows. `PullPage.nextCursor` is a timestamp: a row committed
   late with an older `updated_at`, or rows sharing the `updated_at` of a page
   boundary, end up behind a cursor that was already stored.

## Decision

- **Operations.** Every local edit is one immutable `EntityPatch` with an
  `opId` (UUID v4) generated on the device, the changed fields, the remote
  revision each field was based on and the exact `MediaDescriptor` of every
  referenced media version. An edit made while a patch is in flight is a new
  patch. The remote side applies an `opId` at most once and answers a replay
  with the same `MutationReceipt`, flagged `alreadyApplied`.
- **Receipts.** A receipt answers every field of its own patch exactly once,
  either accepted with its new revision or as a `FieldConflict`, and nothing
  else (`MutationReceipt.ensureAnswers`). It can therefore never acknowledge a
  newer local edit.
- **Merge rules.** Per-field revisions: independent fields merge, identical
  concurrent values are accepted, different values for one field become a
  conflict that keeps both values until a resolution patch. The audio
  recording is one indivisible version. `childId`, `addedAt` and the photo are
  create-only. Trash, restore and purge are a `lifecycle` field; an edit of a
  trashed, purged or unknown entity is a `deleteVsEdit` conflict and never
  resurrects it. The full table is in the library documentation of
  `sync_protocol.dart`.
- **Journal.** Changes are read as `SyncChangePage`s of at most 200 changes,
  strictly ordered by a per-family sequence assigned inside the writing
  transaction, each with a complete snapshot. The cursor is opaque and carries
  a generation; a generation change or an unreadable cursor raises
  `ChangeCursorInvalidException` and the device reconciles from the beginning
  while keeping local data and pending operations.
- **Media.** A media version (`mediaId`, `version`) is immutable and described
  by role, format, size, SHA-256 and duration or dimensions. The original
  photo stays on the device; remote photos are optimized JPEG of at most
  1600 px and 300000 bytes. A version is reserved, uploaded and verified over
  its stored bytes before a patch may reference it.
- **Errors.** `SyncProtocolException` is sealed: invalid cursor, operation id
  reuse, media version conflict, receipt mismatch, rate limit, authentication,
  media integrity and unavailable media. Field conflicts are data, not errors.
- **Boundary.** The types are plain Dart with a neutral JSON encoding used for
  durable local persistence. Adapters own their transport mapping, sessions
  and family resolution; nothing in the contract names a provider.

## Alternatives rejected

- **A global database sequence as the journal position.** Sequence values are
  allocated before commit, so a transaction holding a lower value can commit
  after a higher one has been read; the device would skip it exactly like the
  timestamp cursor does. A per-family counter taken under a transactional lock
  serializes the writers of one family and keeps commit order.
- **Whole-row last-writer-wins.** Cheap, but it silently discards one of two
  concurrent edits to different fields and one of two edits to the same field,
  which the product forbids.
- **Keeping the v2 interface and fixing the engine only.** A timestamp cursor
  cannot express a commit position and a row upsert cannot report which fields
  were accepted; both losses come from the contract shape.

## Consequences

- The local schema gains per-field revisions and an operation table, written
  in the same transaction as the edit; conflicts become durable local state.
- The old `SyncBackend` (row upserts, timestamp cursors, key-based transfers)
  was deprecated by L01 and removed in L08, with the timestamp pull, the
  legacy push and the engine's key-based downloads. The engine takes a
  `SyncProtocolBackend` and a family resolver; nothing else.
- A device restored on new hardware rebuilds its state from the start of the
  journal; the journal is not compacted.
- Remote restores must bump the generation so devices reconcile instead of
  trusting stale cursors.
