# Feature workflow across the four artkiddo repositories

Status: active design rule for the split public foundation.

Use this workflow for every feature, behavioral refactor, storage change,
contract change, provider change, or new dependency. The target owners are the
public/local core, private mobile app, private web client, and private backend.

## 1. Start from the architecture map

Read `docs/architecture/current-state.md` and inspect `git status --short`. If its
verified commit is `HEAD` and no architecture-sensitive worktree file changed,
do not inventory the whole repository again. Open only the named composition
root, feature slice, contract, storage code, tests, and relevant ADRs.

If the snapshot is stale, first determine whether the commits since its marker
touch architectural boundaries. A documentation-only or leaf UI change does not
justify a full rescan. If a boundary changed, refresh the snapshot and generated
inventory before implementation.

## 2. Classify the feature

Choose exactly one primary class:

| Class | Public/local result | Private/cloud result |
|---|---|---|
| `shared-local-first` | Complete offline feature in the public core/app | Same feature, optionally enhanced by cloud |
| `public-local-only` | Complete offline feature | Private app inherits it from the core; no private adapter required |
| `shared-shell-private-service` | Neutral contracts and capability-gated UI only | Concrete remote adapter and enabled experience |
| `private-only` | No code or dead UI | Entire feature stays private |

Default to `shared-local-first` when the user value can be delivered meaningfully
without an account, network, secret, proprietary service, or monetization.

Use `shared-shell-private-service` only when shared UI/domain language is useful
but execution necessarily needs the private service. In the public application,
disabled actions must be absent or replaced by an honest local alternative—never
left broken.

Use `private-only` for backend operations, provider-specific behavior, billing,
store entitlements, proprietary algorithms, operational tooling, and anything
whose public presence would expose private infrastructure.

## 3. Write the impact matrix before coding

Add this block to the issue or plan and fill every row:

```markdown
## Cross-repository impact

- Classification: shared-local-first | public-local-only |
  shared-shell-private-service | private-only
- Public/local behavior:
- Private mobile/cloud behavior:
- Web behavior:
- Backend behavior:
- Public contracts or domain models changed:
- Private backend contract changed:
- Capability or composition change:
- Local schema/file migration:
- Remote protocol/backend migration:
- Public tests:
- Private mobile tests:
- Web tests:
- Backend tests:
- Compatibility window:
- Release order, SHA locks, and rollback:
- Architecture/ADR documents to update:
```

“Not applicable” is valid. An empty row is not.

## 4. Place code according to ownership

Place in the public core:

- domain entities, value objects, named failures, and business invariants;
- local persistence, local files, and deterministic migrations;
- UI and controllers that work locally or are fully capability-gated;
- vendor-neutral contracts and typed DTOs required by a private adapter;
- conformance tests and reusable test fakes.

Place in the private mobile repository:

- provider SDKs, HTTP/RPC details, remote identifiers, authentication details,
  and object-store conventions;
- wire codecs and `Map<String, dynamic>` parsing;
- publishable client configuration, environment selection, billing,
  entitlements, and private analytics; privileged secrets remain server-side;
- concrete remote adapters, store integrations, entitlements, and mobile-only
  proprietary features.

Place in the private web repository:

- Astro pages/components, SEO, legal pages, and guest gallery behavior;
- the single web backend client and web contract tests.

Place in the private backend repository:

- migrations, authorization policies, RPC/endpoints, object-store integration,
  secret-loading code, and operational jobs; secret values remain in environment
  stores;
- the authoritative language-neutral backend contract, schemas, and fixtures.

The dependency direction is always:

```text
private app -> private adapters -> public contracts/core
      │             └---------> pinned private backend contract
web client -------------------> pinned private backend contract
backend ----------------------> no client
public local app -------------> public core
```

No arrow may point from public code to private code.

## 5. Design compatibility and release order

- **Non-breaking shared change:** merge and test the public core, tag it, pin its
  full SHA privately, then release the private app.
- **Breaking public contract:** first add a backward-compatible public bridge;
  update and release private adapters; remove the old API only in a later public
  major version after all private consumers migrated.
- **Private-only change:** name mobile, web, and/or backend as owner; change the
  public core only when a genuinely vendor-neutral capability is missing.
- **Backend change:** pin the contract SHA in every affected consumer. Breaking
  changes use expand/migrate/contract: expand backend, migrate web/mobile, wait
  through the compatibility window, then remove the old path.
- **Shared schema change:** land public migration tests first, then run the
  private app against realistic upgraded data before either production release.

Never coordinate repositories through an unpinned branch reference.

## 6. Implement in thin vertical slices

For a shared feature, use the applicable steps in this order:

1. public domain rule and typed contract;
2. public local implementation and offline tests;
3. public capability-gated presentation;
4. public tag/SHA candidate;
5. backward-compatible backend contract/implementation and staging tests;
6. private mobile adapter/composition and conformance tests;
7. web client/UI and contract tests;
8. immutable core/backend locks and end-to-end tests;
9. documentation, compatibility notes, deployment, and rollback evidence.

## 7. Definition of done

- The public application still starts and completes its core journeys without
  account, environment variables, or network.
- Public/local, private mobile, web, and backend rows are all answered.
- Disabled capabilities are checked before any provider is read.
- Vendor types, wire maps, backend names, secrets, and private identifiers have
  not crossed into public code.
- New dependencies satisfy the rules in `public-code-rules.md` when public.
- Errors are typed; no new silent `catch` or implicit fallback exists.
- Public, mobile, web, and backend tests for every affected repository pass.
- Version compatibility, SHA pin, release order, and rollback are explicit.
- Any changed boundary updates its ADR and architecture map in the same PR.
- The generated inventory freshness check passes.
