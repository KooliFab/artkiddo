# ADR 0002: Separate public foundation from private products

## Decision

Maintain four sibling repositories: public `artkiddo`, private `artkiddo-cloud`,
private `artkiddo-web`, and private `artkiddo-backend`. The shared container is
not a Git repository.

## Consequences

The public repository contains reusable domain behavior, local persistence,
neutral UI, and contracts. Private repositories own distributed products,
monetization, web delivery, deployments, infrastructure, and concrete remote
adapters. Private consumers pin immutable public and backend revisions.
