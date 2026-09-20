# Public capability matrix

Every feature includes this local ownership check in its plan or pull request.

| Capability | Classification | Local implementation | Optional boundary |
|---|---|---|---|
| Offline profiles and artwork | `local-first` | complete local behavior | none required |
| Recoverable local deletion | `local-only` | repository, trash, cleanup journal | none required |
| Local vault rescue export | `local-only` | file-only ZIP export, split by byte budget, no database open | native share sheet |
| Drift migrations v5 → v11 | `local-only` | schema snapshots, legacy fixtures, migration guards | none required |
| Optional synchronization | `capability-gated` | typed contracts, outbox, cursors, honest no-op defaults | application-provided adapter |
| Household UI | `capability-gated` | screens, controller, neutral `FoyerApi` contract | application-provided service |
| Gallery-link UI | `capability-gated` | screens, controller, neutral `SharingService` contract | application-provided service |
| Account-free settings | `local-only` | about, language, debug and local settings | none required |
| Local capture and voice notes | `local-only` | camera, crop, audio recording and playback | platform permissions |

For every feature, state the local invariant, the optional capability involved,
the tests, compatibility window, and rollback. Keep external protocol details
outside this repository.
