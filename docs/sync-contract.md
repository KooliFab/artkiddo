# Neutral synchronization contract

`src/contracts/sync_protocol.dart` defines sync protocol v3 (ADR 0017) without
exposing a provider, endpoint, table or wire format. An application adapter
implements `SyncProtocolBackend` and owns encoding, authentication, family
resolution and protocol compatibility. The previous row-upsert interface,
`SyncBackend`, no longer exists.

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
- A field no pending local operation changes takes the remote value and
  revision. A remote revision older than the local one is held
  (`older_remote_values`) until the read ends: a newer change normally
  follows; if none does, the remote history went back (a restore) and the
  remote value is applied, the local one kept in `replaced_values` (`local`).
  The same revision with another value is that case too. No conflict screen
  in V1. A field a pending operation changes keeps its local value; the
  remote value goes to `replaced_values` unless the device already knows it
  (a revision the operation is based on, the same value). Nothing is dropped
  silently.
- A change carrying the `opId` of an in-flight operation (its echo, when the
  answer was lost) acknowledges that operation as its receipt would: a field
  holding the operation's value is accepted, another one lost a conflict. The
  operation is never replayed, so a later remote change of the same field
  applies normally.
- A remote trash or purge moves the artwork to the local trash and keeps its
  files and pending operations; a remote child purge does the same with its
  artworks and hides the child. Physical deletion belongs to the local trash.
  An artwork kept here after a remote purge gets `remote_purged_at` (it
  exists on this device only; cleared if a later snapshot brings it back).
  A purged artwork with no local file and no operation (a copy of what is
  gone, e.g. on a new device) is removed, with its waiting downloads; a hidden
  child goes when nothing depends on it any more.
- Deleting an artwork here is a trash, never a removal: the row, its files and
  its queued operations stay for 30 days, sent or not. With an account a
  `lifecycle: trashed` patch follows the operations already queued (a creation
  that never went out is not dropped). The only physical deletion is
  `deleteVaultFileIfUnreferenced`, reached by the 30-day purge and by an
  explicit "delete forever" or child deletion; it asks `isMediaReferenced`
  first, so a version named by `replaced_values` or a queued operation stays
  and its cleanup is retried at the next start. No sync error path (network,
  auth, `CURSOR_INVALID`) reaches it.
- Restoring an artwork marked `remote_purged_at` (or whose child was purged)
  brings it back active on this phone only: its hidden child is shown again,
  nothing is queued (the server refuses `lifecycle: active` for a purged
  artwork), and the person is told it will no longer be backed up or visible
  on other devices (`TrashedArtwork.existsOnlyHere`).
- An artwork received before its child waits in `deferred_remote_changes` and
  is applied when the child arrives.
- A new remote media version is registered in `media_versions` as
  `pendingDownload` (`missing` when listed in `unavailableMedia`); the
  download queue reads those rows. At most one audio version of an artwork
  waits; the photo waits at the artwork's display derivative path.
- `ChangeCursorInvalidException` (unreadable cursor or new generation) means:
  reconcile from a null cursor while keeping local data and pending
  operations. Never erase the vault, and never delete an entity because it
  is absent remotely.

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
