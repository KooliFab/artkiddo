# Current public architecture

Snapshot status: public, offline-first foundation. This document is the entry
point for a fresh conversation; read it before scanning the source tree.

Verified commit: 6fd6a6ab234a912e8326e9319e6f35fc7411385a
Verified on: 2026-09-13

## Repository shape

```text
app/                              local Flutter composition and native shells
packages/artkiddo_core/
  lib/src/domain/                 domain values, failures, typed results
  lib/src/contracts/              vendor-neutral optional remote interfaces
  lib/src/local/                  Drift, local vault, audio, repositories
  lib/src/sync/                   durable outbox and conflict utilities
  lib/src/presentation/           capabilities, UI, controllers, theme
  test/                           local persistence and contract tests
docs/                             ADRs, operating rules, generated inventory
```

`app/lib/main.dart` creates only `AppCapabilities.local`. It does not require
an account, environment values, network, database server, or object storage.

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
- `ObjectUploader` uploads bytes and returns an opaque object key.
- `ObjectDownloader` obtains bytes from an opaque object key.

Contracts intentionally do not name a database, object store, endpoint,
authentication system, transport, or remote payload format.

## Freshness protocol

1. Run `git status --short` and `git rev-parse HEAD`.
2. If the verified commit matches and architecture-sensitive files are clean,
   trust this map and inspect only files relevant to the task.
3. If a change affects composition, contracts, schema, provider boundaries, or
   top-level layout, update this file and relevant ADRs in the same change.
4. Run `dart run tool/generate_inventory.dart`; never hand-edit its output.

## Rules that must remain true

- The local application works without account, configuration, or network.
- Public code contains no provider SDK, credentials, remote identifier, wire
  parser, or monetization.
- There is no implicit fallback between remote and local authority.
- A feature is not complete until its public/local, private mobile, private web,
  and private backend impacts and release order are stated.
