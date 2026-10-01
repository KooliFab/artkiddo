# Neutral synchronization contract

`src/contracts/sync_protocol.dart` defines sync protocol v3 (ADR 0017) without
exposing a provider, endpoint, table or wire format. An application adapter
implements `SyncProtocolBackend` and owns encoding, authentication, family
resolution and protocol compatibility. The previous row-upsert interface,
`SyncBackend` in `src/contracts/sync_backend.dart`, is deprecated and remains
only until the engine and adapters migrate.

The public contract does not assume an account or network. The local journey is
complete with `AppCapabilities.local`.

## Operations and receipts

- A local edit is one `EntityPatch`: `opId` (UUID v4, generated on the
  device), `entityType` (`child` or `artwork`), `entityId`, `fields`,
  `baseRevisions` (one per field; `0` when the remote side never had it),
  `media` (exact descriptors of the referenced versions) and `createdAt`.
- A sent patch never changes. An edit made meanwhile is a new patch.
- `applyPatch` returns a `MutationReceipt`: `accepted` (field → new revision),
  `conflicts` and `alreadyApplied`. Replaying an `opId` returns the same
  receipt with `alreadyApplied` and has no second effect.
- The device keeps these operations in a durable queue (ADR 0018): a sent
  operation is marked `in_flight` before the send and replayed unchanged;
  acknowledging it removes only that operation, and a later local edit of the
  same field rebases on the accepted revision. Values that lose a conflict
  are kept locally for 30 days.
- A receipt answers exactly the fields of its own patch. Call
  `ensureAnswers(patch)` before acknowledging anything; a mismatch leaves the
  operation pending.

## Merge rules

| Entity | Field | Rule |
|---|---|---|
| child | `name`, `birthDate` | independent revisions |
| child | `lifecycle` | `active` or `purged` (no child trash) |
| artwork | `story`, `drawnAt` | independent revisions |
| artwork | `audio` | one indivisible version: file, duration, size, revision |
| artwork | `childId`, `addedAt`, `photo` | create-only |
| artwork | `lifecycle` | `active`, `trashed` or `purged` |
| artwork | `addedBy` | remote-owned, read only |

For each field: a matching base revision is accepted; a value identical to the
remote one is accepted without conflict; anything else is a `FieldConflict`
holding both values (`field`, `audio` or `deleteVsEdit`). Conflicts survive
restarts and are resolved by a new patch. An edit of a trashed, purged or
unknown entity is a `deleteVsEdit` conflict: it is kept for recovery and never
resurrects the entity. A lifecycle change carries no other field.

## Change journal

- `pullChanges(cursor, limit:)` returns a `SyncChangePage` of at most 200
  changes in strictly increasing `seq`, each with a complete `EntitySnapshot`
  (none for `purge`), plus `nextCursor`, `hasMore` and `generation`.
- Apply a page and store its `nextCursor` in one local transaction, then pull
  again while `hasMore`.
- A remote change that collides with a pending local operation is kept as a
  conflict or held for later; it is never dropped.
- `ChangeCursorInvalidException` (unreadable cursor or new generation) means:
  reconcile from a null cursor while keeping local data and pending
  operations. Never erase the vault.

## Media

- `MediaDescriptor`: `mediaId`, `version`, `role` (`original`, `optimized`,
  `audio`), `format`, `byteSize`, `sha256`, `durationMs` (audio), `widthPx` and
  `heightPx` (photos). A version's bytes never change.
- Originals stay on the device and never appear in a patch. Remote photos are
  `optimized` JPEG of at most 1600 px and 300000 bytes; their hash differs from
  the original's.
- Transfer: `reserveMedia` → `uploadMedia` → `confirmMedia` (remote check of
  size, format and SHA-256 over the stored bytes) → a patch references the
  version. Unverified versions make the patch fail with
  `MediaUnavailableException` and no effect.
- A snapshot lists `unavailableMedia` whose bytes cannot be read remotely; the
  reference and any local copy stay, and the UI reports the media as
  unavailable.

## Errors

All protocol errors extend the sealed `SyncProtocolException`:
`ChangeCursorInvalidException`, `OperationIdReusedException`,
`MediaVersionConflictException`, `MutationReceiptMismatchException`,
`SyncRateLimitedException`, `SyncAuthException`, `MediaIntegrityException`,
`MediaUnavailableException`. Any other I/O failure means "outcome unknown":
replay the same `opId`. No error is ever a reason to clear local data.

## Versioned audio writes (v2, deprecated)

`AudioWrite` carries keep/replace/delete and the expected revision. A missing cache means keep, never delete. Replacement uploads immutable bytes before committing metadata; the first photo row is committed before its audio reservation. Conflicts retain local files and pending writes for an explicit choice. An acknowledgement cannot clear a newer local edit. Drift v4 migrates all supported v1–v3 vaults forward without clearing files.
