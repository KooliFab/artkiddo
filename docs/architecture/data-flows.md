# Data flows

## Local and optional flow map

```mermaid
flowchart LR
  Capture["Capture / editing"] --> Local["Local repository"]
  Local --> SQLite["Drift"]
  Local --> Files["LocalVault"]
  SQLite --> Outbox["SyncOutbox"]
  Outbox -. "optional capability" .-> Sync["SyncEngine"]
  Sync --> Contract["SyncBackend\nneutral contract"]
  Contract -. "external implementation" .-> External["External service\nnot described by the core"]
  Files --> Rescue["Rescue ZIP export\nwithout database"]
```

## Local creation

```text
capture or edit → local repository → Drift + LocalVault
                                     └─ success after durable write
```

Files use safe writes and failed cleanup is journaled. Active reads exclude
artwork with `deletedAt`.

## Local rescue export

```mermaid
flowchart TD
  A["AppDatabase readable or not"] --> B["VaultRescueExport"]
  B --> C["artworks/\noriginals"]
  B --> D["artworks_derivatives/\ndisplay + thumbnail"]
  B --> E["audio/"]
  B --> F["optional in-flight files"]
  C --> G["ZIP 001..n\nbudget ~3.5 GB/part"]
  D --> G
  E --> G
  F --> G
  G --> H["SharePlus / native share sheet"]
```

The rescue archive intentionally contains technical filenames only. It is a
file recovery mechanism, not a database export or an import/synchronization
format.

## Local recovery

```text
delete → local deletedAt → trash → restore or scheduled purge
                                      └─ deferred file cleanup when needed
```

The local trash has no external scope. An application may implement a separate
shared deletion behavior behind an adapter without changing this path.

## Optional external synchronization

The core produces idempotent operations and independent cursors. An adapter may
translate them to an external protocol. It cannot be read while its
capability is disabled, and local and remote authority never silently replace
one another.

```mermaid
sequenceDiagram
  participant M as Application
  participant L as Local core
  participant B as Neutral contract
  participant S as External service

  M->>L: foreground resume or manual backup
  L->>L: read outbox + independent cursors
  L->>B: adapter SyncBackend
  B->>S: RPC / Data API / Edge Function
  S-->>B: pages, states, URLs, or typed errors
  B-->>L: neutral DTOs
  L-->>M: local state + convergence status
```
