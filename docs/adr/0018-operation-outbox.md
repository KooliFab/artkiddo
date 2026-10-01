# ADR 0018: Operation outbox and replaced-value history

Status: accepted 2026-10-01; schema v5. Implements the device side of ADR 0017
for scalar fields; media descriptors, the change journal and the adapters are
later work.

## Context

The outbox recorded "entity X needs a push" and was acknowledged by row
number. An edit made while a push was in flight was collapsed into the entry
being sent, and the acknowledgement erased the only record of it (the first
loss of ADR 0017).

## Decision

- **Rows are operations.** `sync_outbox` holds `op_id` (UUID v4, unique),
  `entity`, `entity_id`, `op`, `patch_json` (`EntityPatch.toJson`, null while
  the content is read from the row when sent), `state` (`pending` or
  `in_flight`), `attempts`, `last_error`. The repositories write the operation
  in the same transaction as the edit; a failed write leaves neither.
- **Pending operations merge, sent ones never change.** An edit is merged
  into the entity's last operation when that one is `pending`; otherwise it
  is a new operation. `in_flight` is persisted before the send and kept after
  any failure, because the outcome may be unknown: the replay carries the
  same `op_id` and patch. Operations of one entity are sent in order.
- **Acknowledgement is per operation.** A receipt (checked by `ensureAnswers`)
  removes its own operation. An accepted field records its revision on the
  row unless a later operation also changes that field; that operation takes
  the revision as its base instead.
- **Conflicts keep both values.** On a `field` or `audio` conflict the remote
  value is written to `replaced_values` and the local value wins: it is sent
  again on top of the remote revision. A `deleteVsEdit` conflict keeps the
  edit on the local row, records it in `replaced_values` too (the entity may
  be purged remotely) and never sends it again. There is no resolution screen.
- **`replaced_values`** is local only, never sent, cleaned after 30 days,
  read through `ReplacedValuesRepository.listReplacedValues(entityId)`.
- **Compatibility.** Without a `protocolBackend` the engine sends rows through
  the deprecated `SyncBackend` exactly as before, with the same operation
  bookkeeping. The `entity`, `entity_id`, `op`, `attempts` columns keep their
  names. Artwork operations that need media descriptors (creation, audio)
  have no patch yet and wait in protocol mode.

## Consequences

- Schema v5: `*_rev` columns on `children` and `artworks` (audio keeps
  `audio_revision`), the operation columns, the `replaced_values` table.
  Existing entries become pending operations with fresh identifiers.
- Rollback: restoring a v4 database file; there is no downgrade path.
