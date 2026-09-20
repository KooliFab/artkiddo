# ADR 0002: Keep the public foundation self-contained

## Decision

Keep the public foundation self-contained. It owns local behavior, local
persistence, neutral presentation, and abstract capability contracts. The
working directory, consuming applications, and external services are not
dependencies of this repository and are intentionally not described here.

## Consequences

The repository contains reusable domain behavior, local persistence, neutral UI,
and contracts. Concrete external adapters, deployments, infrastructure,
monetization, and product-specific configuration belong outside the public
boundary. External applications may consume immutable public revisions but the
public code never depends on them.
