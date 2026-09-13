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
