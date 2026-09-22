# Public capability matrix

Every feature includes this local ownership check in its plan or pull request.

| Capability | Classification | Local implementation | Optional boundary |
|---|---|---|---|
| Offline profiles and artwork | `local-first` | complete local behavior | none required |
| Recoverable local deletion | `local-only` | repository, cleanup journal, `TrashScreen` reachable from settings | none required |
| Local vault rescue export | `local-only` | file-only ZIP export, split by byte budget, no database open | native share sheet |
| Local schema baseline | `local-only` | schema v3, one snapshot per version, fresh-vault and migration tests | none required |
| Optional synchronization | `capability-gated` | typed contracts, outbox, cursors, honest no-op defaults | application-provided adapter |
| Household UI | `capability-gated` | invite/join screen, controller (wider than that screen: it also drives a composition's family-settings surface), neutral `FamilyApi` contract | application-provided service |
| Gallery-link UI | `capability-gated` | screens, controller, neutral `SharingService` contract | application-provided service |
| Account-free settings | `local-only` | `SettingsScreen` reachable from the gallery app bar with no binding; language, trash, about, debug | composition may substitute the surface, never gate it (ADR 0016) |
| Local capture and voice notes | `local-only` | camera, crop, audio recording and playback | platform permissions |

For every feature, state the local invariant, the optional capability involved,
the tests, compatibility window, and rollback. Keep external protocol details
outside this repository.

A `local-only` row means the feature is reachable in a composition that binds
nothing. If reaching it requires a `CompositionActions` entry, the row is
wrong or the code is — ADR 0016 covers why, and which of the two to fix.
