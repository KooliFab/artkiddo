# Repository map

| Area | Entry points | Responsibility | Must not depend on |
|---|---|---|---|
| `app/lib/main.dart` | `ArtKiddoLocalApp` | account-free composition | remote services, secrets |
| `src/domain` | values and failures | business language and invariants | Flutter, storage, network |
| `src/contracts` | typed interfaces | optional remote boundaries | vendor types and wire payloads |
| `src/local/database` | `AppDatabase` | local Drift schema v1 baseline | network |
| `src/local/storage` | `LocalVault` | images, audio, and durable cleanup | remote object URLs |
| `src/local/repositories` | local repositories | children, artwork, local trash | remote adapters |
| `src/sync` | outbox and conflict primitives | durable local sync state | provider SDKs and HTTP parsing |
| `src/presentation` | UI, controllers, capabilities | account-free user journeys | private implementation details |

Dependencies point inward from presentation to domain/contracts and outward to
local adapters only. Remote adapters do not exist in this checkout.
