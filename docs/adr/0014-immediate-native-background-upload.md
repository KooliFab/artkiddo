# ADR 0014 — Immediate native background upload

After the local artwork row and its outbox entry commit, the public core emits
`CompositionActions.onArtworkSaved(artworkId)` as a best-effort callback. The
callback is not awaited by the capture save path and cannot change its result.

A composition that enables remote backup owns the upload policy and its
transport. The public core only guarantees the callback timing and the outbox
rules: tasks the composition reports as active are excluded from the neutral
outbox drain, and completion acknowledges the outbox only when the local
artwork still matches the submitted snapshot. A transfer interrupted by the
operating system is reconciled against the durable outbox on the next launch.

## Versioned audio acknowledgement (2026-09-27)

Local schema v4 stores explicit keep/replace/delete intent, the last acknowledged audio revision and a conflict flag. Missing cached bytes never imply deletion. A submitted snapshot acknowledges only matching local state; if the user records again during transfer, its pending intent and file survive while the acknowledged revision advances. Conflicts expose an explicit shared/local choice. New photo metadata must exist before reserving its first audio upload. The local-only composition saves audio without reading remote providers.
