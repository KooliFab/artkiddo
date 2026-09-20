# Current public architecture

Snapshot status: public, offline-first foundation, now hosting the full
account-free gallery experience (feed, capture, sharing, and household UI
behind capability gates). This document is the entry point for a fresh
conversation; read it before scanning the source tree.

Verified on: 2026-09-20 — HEAD `6f019b6de6b3fec384e3d64111e4dc4b3a5af79c`

## Repository shape

```text
app/                              local Flutter composition and native shells
packages/artkiddo_core/
  lib/src/domain/                 domain values, failures, typed results
  lib/src/contracts/              vendor-neutral optional remote interfaces
  lib/src/local/                  Drift, local vault, audio, repositories
  lib/src/sync/                   sync engine, durable outbox, conflict utilities
  lib/src/presentation/
    bootstrap/                    ArtKiddoBootstrap, composition validation
    config/                       AppCapabilities, CloudServices, environment
    navigation/                   AppShell, CompositionActions seam
    gallery/                      feed, capture, artwork detail
    sharing/                      web gallery-link screens and controller
    foyer/                        household screens and controller
    children/, settings/, ui/, theme/, locale/, utils/
  test/                           local persistence, sync, and presentation tests
docs/                             ADRs, operating rules, generated inventory
```

`app/lib/main.dart` creates only `AppCapabilities.local`. It does not require
an account, environment values, network, database server, or object storage.

## Visual overview — local application

```mermaid
flowchart TD
  App["app/lib/main.dart\nlocal composition"] --> Bootstrap["ArtKiddoBootstrap\ncapabilities + providers"]
  Bootstrap --> UI["Core presentation\ngallery · capture · trash · local sharing"]
  UI --> Repos["Local repositories\nchildren + masterpieces"]
  Repos --> DB["AppDatabase\nDrift schema v11"]
  Repos --> Vault["LocalVault\noriginals · derivatives · audio"]
  DB --> Outbox["SyncOutbox + cursors\npresent but inactive locally"]
  Vault --> Rescue["VaultRescueExport\nfile-only ZIP, no database"]
  Bootstrap -. "optional capabilities disabled" .-> NoRemote["NoFoyerApi / NoSharingService\nno fabricated external state"]
```

This separation keeps the application usable and testable without an account,
configuration, or network. Optional contracts remain abstract and contain no
provider or protocol details.

## Composition seam

`ArtKiddoBootstrap.createContainer` builds the provider graph from an
`ArtKiddoBootstrapConfig` (`capabilities`, `cloudServices`, `environment`,
`overrides`), then validates it twice:

1. `config.validate()` checks the *declared* configuration — a capability
   cannot be enabled without its required `CloudService`.
2. `_validateComposition` checks what the `overrides` *actually produced* —
   reading `compositionActionsProvider`, `remoteMediaFetcherProvider`,
   `foyerApiProvider`, and `sharingServiceProvider` after construction, and
   rejecting the container if an enabled capability has no real binding
   behind it.

This second check exists because the first cannot see a composition that
enables a capability and then forgets to override its provider — that
combination used to start normally and degrade into a hidden control or a
no-op service, which is the silent local/remote fallback the architecture
forbids (ADR 0003).

Every optional provider the core declares (`remoteMediaFetcherProvider`,
`foyerApiProvider`, `sharingServiceProvider`, `compositionActionsProvider`)
defaults to an honest local implementation — `NoRemoteMediaFetcher`,
`NoFoyerApi`, `NoSharingService`, `CompositionActions.none` — none of which
fabricate remote state. `NoFoyerApi`/`NoSharingService` throw or return a
typed `ActionFailed` failure rather than a fake success; `CompositionActions`
simply renders nothing when an action is null. An application composition
overrides exactly the providers its enabled capabilities need.

## Dependency direction

```text
presentation → domain / contracts → local repositories → database + local vault

application composition → public contracts and core
external implementation → public contracts only
```

The core has no dependency on an external repository. Optional behavior is
explicit: an application composition supplies compatible implementations and
enables the matching capability before a provider is read.

The rescue export is local-only: it reads vault files and never opens or
reconstructs the database.

## Local persistence

`AppDatabase` is Drift schema v11. `ChildrenTable` and `MasterpiecesTable`
persist the account-free experience. The artwork table stores neutral opaque
object keys only (`displayObjectKey`, `thumbnailObjectKey`, `audioObjectKey`);
their meaning and lifecycle belong to an external implementation. v11 renames historical
provider-named columns without losing data.

`LocalVault` owns local image and audio files. Local deletion is recoverable for
30 days and cleanup is journaled. Local success is reported only after a durable
write.

`VaultRescueExport` parcourt `masterpieces/`,
`masterpieces_derivatives/` and `audio/`, optionally adds in-flight capture
files, splits ZIPs around 3.5 GB, and shares the archives through the native
share sheet. It can recover originals even when `AppDatabase` is unreadable;
in return, the archive contains no child, date, or story metadata because that
information lives in SQLite. Drift migrations v5 through v11 have dedicated
snapshots and test fixtures.

## Flux locaux importants

```mermaid
sequenceDiagram
  participant U as User
  participant C as Capture / editing
  participant R as Repository
  participant D as Drift v11
  participant V as LocalVault

  U->>C: photo, recadrage, audio, anecdote
  C->>V: write original + derivatives
  C->>R: persist relative paths
  R->>D: transaction metadata + outbox
  D-->>U: success after durable write
  U->>V: request rescue export
  V-->>U: file-only ZIP(s), without opening D
```

## Public contracts

- `SyncBackend` models remote metadata synchronization with typed values.
- `ObjectUploader` / `ObjectDownloader` move bytes through opaque object keys.
- `RemoteMediaFetcher` fetches media that exists remotely but not yet locally;
  the local default never fetches anything.
- `FoyerApi` models household membership and invites.
- `SharingService` models web gallery-link creation, listing, and revocation.
- `ShareBackup` is an optional presentation action supplied by an application
  composition when gallery links are enabled. The share controller invokes
  it for one child, then checks that child's persisted artwork sync state before
  allowing link creation. The bootstrap rejects a web-link composition without
  this action. Link visibility is evaluated against an injectable clock and
  excludes revoked and expired links.

Contracts intentionally do not name a database, object store, endpoint,
authentication system, transport, or remote payload format.

## Freshness protocol

1. Run `git status --short` and `git rev-parse HEAD`.
2. If the verified date is recent and architecture-sensitive files are clean,
   trust this map and inspect only files relevant to the task.
3. If a change affects composition, contracts, schema, provider boundaries, or
   top-level layout, update this file and relevant ADRs in the same change.
4. Run `dart run tool/generate_inventory.dart`; never hand-edit its output.

## Rules that must remain true

- The local application works without account, configuration, or network.
- Public code contains no provider SDK, credentials, remote identifier, wire
  parser, or monetization.
- There is no implicit fallback between remote and local authority — enforced
  both by capability gating in the UI and by `_validateComposition` at boot.
- A feature is not complete until its local behavior, optional capabilities,
  compatibility impact, and rollback are stated.

## Publication note

Package distribution is independent from the internal architecture.
This documentation describes only the code in this repository; integrating
applications must provide their own compositions and implementations of the
optional contracts.
