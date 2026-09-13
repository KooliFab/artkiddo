# Data flows

## Local creation

```text
capture or edit → local repository → Drift v11 + LocalVault
                                     └─ success after durable write
```

Files use safe writes and failed cleanup is journaled. Active reads exclude
artwork with `deletedAt`.

## Local recovery

```text
delete → local deletedAt → trash → restore or scheduled purge
                                      └─ deferred file cleanup when needed
```

The local trash has no remote scope. A private product may implement a separate
shared deletion behavior behind a private adapter without changing this path.

## Optional remote synchronization

The core produces idempotent operations and independent cursors. A private
adapter may translate them to its remote protocol. It cannot be read while its
capability is disabled, and local and remote authority never silently replace
one another.
