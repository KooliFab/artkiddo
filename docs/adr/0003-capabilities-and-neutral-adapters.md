# ADR 0003: Use explicit capabilities and neutral adapters

## Decision

Optional remote behavior is represented by vendor-neutral contracts and explicit
capabilities. A composition validates the required services before building a
provider graph.

## Consequences

Widgets and controllers do not instantiate or read a remote provider when its
capability is disabled. The public local application never falls back silently
between local and remote authority. Private adapters own wire formats, vendor
SDKs, authentication, and operational policy.

## Trash preview and deletion notification (2026-09-27)

A durable local deletion may emit the optional onArtworkDeleted callback when remoteBackup is enabled. Optional integrations own transfer cancellation and remote convergence. Trash preview DTOs carry either an opaque local vault path or a temporary URI; providers, signing and wire decoding remain outside public code. Local trash never reads remote providers. Shared trash refreshes while visible with a bounded 20-second cadence, rather than requiring a backend realtime publication. The timer is disposed with the screen and suspended outside its active route/application.
