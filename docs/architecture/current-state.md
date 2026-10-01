# Current public architecture

Status: public, offline-first foundation hosting the full account-free gallery
experience (feed, capture, sharing and household UI behind capability gates).
Read this before scanning the source tree.
Verified on: 2026-10-01 (sync protocol v3 contracts, ADR 0017; operation outbox, ADR 0018; change journal pull).

## Repository shape

```text
app/                              local Flutter composition and native shells
packages/artkiddo_core/
  lib/artkiddo_core.dart          the only supported import surface
  lib/src/domain/                 domain values, failures, typed results
  lib/src/contracts/              vendor-neutral optional remote interfaces
  lib/src/local/                  Drift, local vault, audio, repositories
  lib/src/sync/                   sync engine, durable outbox, conflict utilities
  lib/src/presentation/
    bootstrap/                    ArtKiddoBootstrap, composition validation
    config/                       AppCapabilities, CloudServices, environment
    navigation/                   AppShell, CompositionActions seam
    gallery/                      feed (gallery_screen*.dart), capture, artwork detail (artwork_screen*.dart)
    sharing/, family/, settings/, children/, ui/, theme/, locale/, utils/
  lib/l10n/                       edit the .arb files; generated/ is output
  test/                           local persistence, sync and presentation tests
docs/                             ADRs, operating rules, generated inventory
```

`app/lib/main.dart` creates only `AppCapabilities.local` and overrides no
provider. That empty override list is load-bearing: every destination the
account-free build needs is a local default inside the core (ADR 0016).

```mermaid
flowchart TD
  App["app/lib/main.dart"] --> Bootstrap["ArtKiddoBootstrap\ncapabilities + providers"]
  Bootstrap --> UI["core presentation"]
  UI --> Repos["children + artworks repositories"]
  Repos --> DB["AppDatabase (Drift)"]
  Repos --> Vault["LocalVault\noriginals, derivatives, audio"]
  DB --> Outbox["SyncOutbox + cursors\ninactive locally"]
  Bootstrap -. "capabilities disabled" .-> NoRemote["NoFamilyApi / NoSharingService"]
```

## Composition seam

`ArtKiddoBootstrap.createContainer` builds the graph from
`ArtKiddoBootstrapConfig` (`capabilities`, `cloudServices`, `environment`,
`overrides`) and validates it twice:

1. `config.validate()`: a capability cannot be enabled without its required
   `CloudService`.
2. `_validateComposition`: after construction, an enabled capability must have
   a real binding. `remoteAccount` needs `openAccount`; `household` needs
   `openFamilyHub` and a `FamilyApi`; `webGalleryLinks` needs
   `openGalleryShare`, a `SharingService` and a `ShareBackup`; `remoteBackup`
   needs a `RemoteMediaFetcher` and `syncPhotos`. This blocks the silent
   local/remote fallback forbidden by ADR 0003.

Optional providers default to honest local implementations
(`NoRemoteMediaFetcher`, `NoFamilyApi`, `NoSharingService`,
`CompositionActions.none`) that return typed failures, never fabricated remote
state. `CompositionActions` entries are either capability-gated (`openGalleryShare`,
`syncPhotos`, `openAccount`: control hidden without the pair) or local defaults
(`openSettings`, `openFamilyHub`: they substitute a core destination, so the
control always renders). See ADR 0016.

Dependency direction: `presentation -> domain/contracts -> local repositories ->
database + vault`; compositions depend on the core, external implementations on
public contracts only. Rules: `dependency-rules.md`.

## Local persistence

- `AppDatabase` is Drift schema v7: v1 clean baseline (ADR 0007), v2 adds
  `vault_meta.join_reset_pending`, v3 adds `artworks.added_by`, v4 adds audio revision, explicit write intent and conflict state, v5 adds per-field revisions, the operation queue and `replaced_values` (ADR 0018), v6 adds `media_versions`, v7 adds the change journal cursor (`vault_meta.change_cursor`/`change_generation`), `children.deleted_at` (child purged remotely, kept hidden while its artworks are in the trash), `artworks.remote_purged_at` (purged remotely, kept here only), `deferred_remote_changes` and `older_remote_values`. Each version
  has a snapshot in `drift_schemas/`, covered by
  `test/unit/local_data/migration_test.dart`. No upgrade path from pre-v1
  vaults.
- Tables: `children`, `artworks`, `sync_outbox` (identified operations),
  `replaced_values` (local-only history of values that lost a conflict, 30
  days), `media_versions`, `deferred_remote_changes` (artworks received
  before their child), `older_remote_values` (remote values older than the
  local revision, settled when a journal read ends), `vault_meta`,
  `pending_file_cleanups`, `share_link_url_cache`. Artworks store neutral
  opaque object keys only.
- `LocalVault` owns image and audio files. Every write goes through `writeFileAtomically` (temporary file in the same folder, flush, size check, rename); `*.tmp` leftovers are removed at start-up and an unreferenced final file is kept. Audio lives at `audio/<artworkId>/v<N>.m4a`, a new recording is a new version and the old file stays; `media_versions` registers the files and `isMediaReferenced` tells a cleanup whether one is still needed. Local deletion is recoverable for 30
  days, cleanup is journaled, success is reported only after a durable write.
- `VaultRescueExport` zips vault files (≈3.5 GB parts) without opening the
  database, so it has no child/date/story metadata.
- After a durable save, `CompositionActions.onArtworkSaved` runs best-effort
  and is never awaited. Flow diagrams: `data-flows.md`.

## Public contracts

- `SyncProtocolBackend` (sync protocol v3, ADR 0017): `EntityPatch` operations
  replayed by `opId`, `MutationReceipt` with per-field `FieldConflict`s,
  `MediaDescriptor` versions, and a journal read as `SyncChangePage`s with an
  opaque `ChangeCursor` and a generation. When a `protocolBackend` is
  supplied, the engine pushes operations through it (ADR 0018) and reads its
  journal (`ChangeJournalPull`, rules in `docs/sync-contract.md`). The engine
  requires one: the former `SyncBackend`, the timestamp pull and the key-based
  transfers are removed. Media bytes (upload, download) belong to the
  composition, which sends and fetches them around the engine.
- `ObjectUploader`/`ObjectDownloader` (opaque object keys, no longer used by
  the engine), `RemoteMediaFetcher` (local default fetches nothing).
- `SyncEngine.syncAll(onProgress:)` reports neutral `SyncProgress`
  (`sending` with a known count, then `receiving` with no total).
- `FamilyApi`: membership and invites. `redeemInvite(discardPrevious:)` and
  `RedeemOutcome.sameFamily`/`vaultReset` (ADR 0015) let a composition leave a
  previous family in the same call; `familyVaultResetProvider` (no-op by
  default) erases the vault first. `FamilyInviteScreen`'s `_JoinFamilyDialog`
  is the only path into `FamilyController.redeem` (read-only summary, then a
  checkbox-gated confirmation). Member administration lives in the
  composition's own UI.
- `SharingService`: web gallery links. `ShareBackup` is invoked for one child
  before link creation; revoked and expired links are hidden using an
  injectable clock. The share controller is disposed when its sheet loses
  its last observer, reloads on session changes, and rejects results from an
  earlier build lifetime. List failures expose a retry without disabling new
  creation attempts after a past network error. The sheet scrolls when its
  content exceeds the available height; see `../qa/share-links-p1.md`.
- `CompositionActions.syncPhotos` is the only trigger for `remoteBackup`; the
  gallery binds it to pull-to-refresh only when the capability is enabled and
  the action is bound.
- Contracts never name a database, object store, endpoint, auth system,
  transport or payload format.

The gallery feed is one masonry wall, newest first, placed exactly by
`SliverGridDelegateWithMasonryPlan` from known aspect ratios; its scroll extent
is computed, never estimated (ADR 0006).

## Freshness protocol

1. Run `git status --short` and `git log --oneline -10`.
2. If nothing since the verified date touches composition, contracts, schema,
   provider boundaries or top-level layout, trust this map and open only the
   files the task needs.
3. Otherwise update this file and the relevant ADRs in the same change, then
   run `dart run tool/generate_inventory.dart` (never hand-edit its output).

## Rules that must remain true

- The local app works without account, configuration, network, or any provider
  override. Every `local-only` row of `feature-matrix.md` is reachable from
  `AppCapabilities.local` alone.
- Public code contains no provider SDK, credentials, remote identifier, wire
  parser or monetization.
- No implicit fallback between remote and local authority: enforced by UI
  capability gating and by `_validateComposition` at boot.
- A feature is not complete until its local behavior, optional capabilities,
  compatibility impact and rollback are stated.

## Audio writes

Audio saves remain local-first. A new recording replaces the previous local voice only after a durable save; cancellation preserves it. `AudioWrite` distinguishes keep, replace and delete. Optional backup checks the expected audio revision and keeps conflicting local files until the user chooses a version. Backup controls and statuses require `remoteBackup`. See ADR 0014 and `docs/sync-contract.md`.

## Trash convergence and previews (2026-09-27)

Artwork deletion emits the capability-gated `CompositionActions.onArtworkDeleted` hook only after its local transaction succeeds. The sync engine coalesces simultaneous lifecycle/manual/trash runs so they cannot drain the same entry twice. Shared trash refreshes on entry and resume, supports pull-to-refresh, and refreshes every 20 seconds only while its route is visible and the app is active. Local trash reads only local rows and files. `TrashedArtwork` exposes an optional vault path or authorized temporary preview URI; the UI shows a tappable, zoomable preview or an explicit unavailable state. See ADR 0003.
