# Cross-repository feature matrix

Every feature includes this ownership check in its plan or pull request.

| Capability | Classification | Public/local | Private mobile | Private web | Private backend |
|---|---|---|---|---|---|
| Offline profiles and artwork | `shared-local-first` | complete core behavior | consumes the core | not applicable | not applicable |
| Recoverable local deletion | `public-local-only` | local repository and migration | inherits the core | not applicable | not applicable |
| Remote convergence contracts | `shared-shell-private-service` | neutral types and capability gate | concrete adapters | consumer when needed | authoritative implementation |
| Household screens (`FamilyScreen`, `FoyerController`) | `shared-shell-private-service` | screens, controller, neutral `FoyerApi` contract, capability gate | concrete Supabase adapter, QR scan action injected via `CompositionActions.openQrScanner` | not applicable | private |
| Web gallery-link screens (`ShareScreen`, `ShareController`) | `shared-shell-private-service` | screens, controller, neutral `SharingService` contract, capability gate | concrete Supabase adapter injected via override | private consumer of the resulting link | private service |
| Account and sign-in (`AccountScreen`, `AuthGateway`, session) | `private-only` | absent | private | not applicable | private |
| Billing and entitlements | `private-only` | absent | private | not applicable | private validation |

For every feature, state all four impacts, the enabled capability, tests,
compatibility window, release order, and rollback. Use **not applicable** rather
than leaving a cell blank.
