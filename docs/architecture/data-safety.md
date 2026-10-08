# Data safety: operations, conflicts, media, deletion

Status: public, vendor-neutral. Describes how the launch version (V1) keeps a
drawing from being lost, and what it does not promise. The wire rules live in
`../sync-contract.md`, the decisions in ADR 0017 and ADR 0018, the status
vocabulary in `current-state.md` ("Backup statuses"). Provider and service
operations are private and are not described here.

## Operations

- Every local edit is one **operation** in the durable outbox (`sync_outbox`):
  a UUID v4 `op_id`, the entity, and a patch of fields. The repository writes
  the row and its operation in the same transaction, so a failed write leaves
  neither.
- A pending operation absorbs later edits of the same entity. A sent
  (`in_flight`) operation never changes; a later edit is a new operation.
  `in_flight` is persisted before the send and kept after any failure, so a
  lost answer is recovered by replaying the same `op_id` and the same patch.
- An acknowledgement removes only its own operation. Replaying an operation
  that was already applied has no second effect (the receipt says
  `alreadyApplied`).
- Operations of one entity are sent in order. An operation that needs media
  descriptors waits until the composition has stored them with it.

## Revisions

Each field of a child or an artwork has its own revision number. A patch
carries, per field, the revision it was based on (`0` when the other side never
had the field). A matching base is accepted; an identical value is accepted
without conflict; anything else is a `FieldConflict`. Fields that differ never
conflict with each other, so concurrent edits of different fields merge.

## Change journal

- The remote side exposes an ordered journal of changes per family. Each
  change carries a complete snapshot of the entity after the change, except a
  purge.
- A device reads it page by page. A page and its cursor are applied in one local
  transaction, so a crash between two pages resumes without a gap or a
  duplicate. The order of commit, not of timestamp, orders the journal.
- A field no pending operation changes takes the remote value. A field a
  pending operation changes keeps its local value.
- An artwork received before its child waits in `deferred_remote_changes` and
  is applied when the child arrives.
- The cursor carries a **generation**. A cursor of another generation (after a
  service restore) is refused; the device reads again from the beginning while
  keeping its local data and pending operations. A remote value older than the
  local revision is applied when the read ends (the remote history went back);
  the local value it replaces is kept in `replaced_values`.

## Versioned media

- A media file is identified by `mediaId` and `version`, with its size and
  SHA-256. A version never changes: replacing a photo or recording a new voice
  creates a new version, and the previous file stays until nothing references
  it (`isMediaReferenced`).
- Local writes go through `writeFileAtomically` (temporary file, flush, size
  check, rename). Leftover temporary files are removed at start-up.
- A remote reference to a media version is accepted only after the bytes were
  checked against their size and SHA-256. A patch that references an unchecked
  version fails and has no effect.
- A downloaded file is verified before it is written; a damaged transfer
  writes nothing and is retried.

## Conflict rule (V1)

- Different fields: merged.
- Same field: the local pending change, or the last one sent, wins. **The value
  it replaces is kept** in the local `replaced_values` history for 30 days.
  For audio, the replaced file is kept on the device.
- There is no conflict screen in V1, and no screen reads `replaced_values`
  yet. The history is recoverable by a developer, not by the user.
- Server answers are always `FieldConflict`s; the device applies the rule.

## Deletions made on the device win

- Moving an artwork to the trash, deleting it forever, emptying the trash and
  deleting a child are queued as lifecycle operations. They apply whatever the
  base revision, a purge is terminal, and they are applied when the network
  comes back, after a restart, and against a concurrent remote edit or remote
  restore.
- Deleting forever offline removes the local rows and files at once and queues
  the purge. An expired local trash entry that was never sent keeps its trash
  operation, so the artwork cannot come back active from the remote side.
- A purge refused for lack of rights is downgraded to a trash operation.
- A concurrent edit of an artwork trashed elsewhere never resurrects it. The
  edit is held (a `held` entry in `replaced_values`, exempt from the 30-day
  clean-up), is not overwritten by the next read, and is sent again if the
  artwork is restored remotely. An audio edit in the same situation stays in
  the history and its file is kept.

## Trash (V1)

- 30 days. The row, its files and its queued operations stay, sent or not.
  An artwork that was never sent is restorable for 30 days, with the same
  bytes, and the remote side never hears of it.
- The only physical deletion is `deleteVaultFileIfUnreferenced`, reached by
  the 30-day expiry and by an explicit "delete forever" or child deletion. It
  asks `isMediaReferenced` first; a version named by `replaced_values` or a
  queued operation stays.
- The remote trash list and the remote restore need the network
  (`QueuedRemoteTrashRepository`: remote list merged with the local trash;
  offline, the local trash). Restoring an artwork the remote side no longer
  knows restores it on this device only (`existsOnlyHere`).

## Backup limits

These are product limits, shown or implied by the interface:

- **The original photo stays on the device.** The cloud copy is an optimized
  image (at most 1600 px and 300000 bytes) and the recorded voice. A new
  device restores optimized photos, not originals.
- **"Saved" means:** the artwork row was acknowledged, nothing is queued for it,
  no voice is waiting, and every referenced media version was verified on the
  remote side. It never means that the original is in the cloud. An artwork the
  remote side purged is never "Saved".
- **No zero-loss promise.** V1 reduces the known ways of losing a drawing; it
  does not guarantee that none is ever lost.
- The export (ZIP of the vault and metadata) is the complete, user-held copy.

## Known V1 limits

- Restoring from the remote trash needs the network; offline, restoring is
  local only.
- An audio edit refused as `deleteVsEdit` is kept in the history but not sent
  again after a remote restore.
- A remote value the local database cannot store blocks the read; the device
  has no quarantine.
- A conflict resolution screen reading `replaced_values`.
