# Current public architecture

Snapshot status: public, offline-first foundation, now hosting the full
account-free gallery experience (feed, capture, sharing, and household UI
behind capability gates). This document is the entry point for a fresh
conversation; read it before scanning the source tree.

Verified on: 2026-09-17

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
simply renders nothing when an action is null. A private composition
overrides exactly the providers its enabled capabilities need.

## Dependency direction

```text
presentation → domain / contracts → local repositories → database + local vault

app transfer adapter → local_data_transfer (external package, optional)

private mobile adapters → public contracts and core
private web client      → private backend contract
private backend         → no client repository
```

The public repository has no dependency on a private repository. Optional
remote behavior is explicit: a private composition supplies compatible adapter
implementations and enables the matching capability before a provider is read.

Manual local transfer is also opt-in. It does not alter the local database or
vault until the application validates a received manifest and explicitly
commits staged files.

## Local persistence

`AppDatabase` is Drift schema v11. `ChildrenTable` and `MasterpiecesTable`
persist the account-free experience. The artwork table stores neutral opaque
object keys only (`displayObjectKey`, `thumbnailObjectKey`, `audioObjectKey`);
their meaning and lifecycle belong to a private adapter. v11 renames historical
provider-named columns without losing data.

`LocalVault` owns local image and audio files. Local deletion is recoverable for
30 days and cleanup is journaled. Local success is reported only after a durable
write.

## Public contracts

- `SyncBackend` models remote metadata synchronization with typed values.
- `ObjectUploader` / `ObjectDownloader` move bytes through opaque object keys.
- `RemoteMediaFetcher` fetches media that exists remotely but not yet locally;
  the local default never fetches anything.
- `FoyerApi` models household membership and invites.
- `SharingService` models web gallery-link creation, listing, and revocation.

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
- A feature is not complete until its public/local, private mobile, private web,
  and private backend impacts and release order are stated.

## Publication note

This package is not yet re-published. The private `artkiddo-cloud` checkout
still consumes it through a local `path:` override
(`docs/architecture/public-core-pin.md` records the last published pin,
`core-v0.1.0`). Tagging and pushing a new public revision that includes the
gallery/sharing/foyer consolidation is a separate, explicit step — not
something a change in this repository does on its own.
