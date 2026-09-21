# ADR 0014 — Immediate native background upload

After the local artwork row and its outbox entry commit, the public core emits
`CompositionActions.onArtworkSaved(artworkId)` as a best-effort callback. The
callback is not awaited by the capture save path and cannot change its result.

The private cloud composition owns the upload policy: it snapshots local
metadata and display/audio files, obtains a scoped backend ticket, and enqueues
one multipart task in the platform background transfer system. Active native
tasks are excluded from the neutral outbox drain. Completion acknowledges the
outbox only when the local artwork still matches the submitted snapshot.

URLSession on iOS and WorkManager/UIDT on Android can continue the byte
transfer while the Flutter process is suspended. An explicit user force-quit
remains an operating-system limitation; the next launch reconciles the native
task database and durable outbox.
