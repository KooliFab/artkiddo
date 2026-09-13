# Cross-repository feature matrix

Every feature includes this ownership check in its plan or pull request.

| Capability | Classification | Public/local | Private mobile | Private web | Private backend |
|---|---|---|---|---|---|
| Offline profiles and artwork | `shared-local-first` | complete core behavior | consumes the core | not applicable | not applicable |
| Recoverable local deletion | `public-local-only` | local repository and migration | inherits the core | not applicable | not applicable |
| Remote convergence contracts | `shared-shell-private-service` | neutral types and capability gate | concrete adapters | consumer when needed | authoritative implementation |
| Accounts and household behavior | `private-only` | absent | private | not applicable | private |
| Web gallery links | `private-only` | absent | private adapter | private UI | private service |
| Billing and entitlements | `private-only` | absent | private | not applicable | private validation |

For every feature, state all four impacts, the enabled capability, tests,
compatibility window, release order, and rollback. Use **not applicable** rather
than leaving a cell blank.
