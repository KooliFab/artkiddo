# Feature workflow for the public foundation

Status: active design rule for this repository.

Use this workflow for every feature, behavioral refactor, storage change,
contract change, provider change, or new dependency. Keep this document local
to the public foundation: external implementations are intentionally outside
its scope.

## 1. Start from the architecture map

Read `docs/architecture/current-state.md` and inspect `git status --short`. If
the snapshot is fresh and no architecture-sensitive file changed, inspect only
the named composition root, feature slice, contract, storage code, tests, and
relevant ADRs.

If the snapshot is stale, determine whether the commits since its marker touch
composition, dependency direction, schema, contracts, provider boundaries, or
top-level layout. Refresh the snapshot and generated inventory before
implementation when they do.

## 2. Classify the feature

Choose exactly one primary class:

| Class | Meaning |
|---|---|
| `local-first` | Complete behavior works without account, configuration, or network |
| `local-only` | Behavior belongs entirely to local persistence or presentation |
| `capability-gated` | Local UI and neutral contracts exist; an application may provide an implementation |
| `composition-only` | A provider or action seam is exposed without a concrete external integration |

Default to `local-first` when the user value can be delivered meaningfully
without an account, network, secret, proprietary service, or monetization.

In the public application, disabled capabilities must be absent or replaced by
an honest local alternative—never left broken or silently simulated.

## 3. Write the local impact block before coding

Add this block to the issue or plan and fill every row:

```markdown
## Local impact

- Classification: local-first | local-only | capability-gated | composition-only
- Local behavior and invariant:
- Public contract or domain model changed:
- Capability or composition change:
- Local schema/file migration:
- Error and fallback behavior:
- Tests and fixtures:
- Compatibility window:
- Rollback:
- Architecture/ADR documents to update:
```

## 4. Place code according to ownership

Place in this repository:

- domain entities, value objects, named failures, and business invariants;
- local persistence, local files, deterministic migrations, and recovery;
- UI and controllers that work locally or are fully capability-gated;
- vendor-neutral contracts and typed DTOs;
- conformance tests and reusable test fakes.

Do not place here:

- provider SDKs, credentials, endpoint details, remote identifiers, wire
  codecs, backend schemas, billing, monetization, or proprietary analytics;
- concrete implementations that require an external service.

The dependency direction inside this repository is:

```text
presentation → domain / contracts → local repositories
                                      ├─ Drift database
                                      └─ local vault
```

Optional implementations depend on the public contracts. The public code never
depends on those implementations.

## 5. Design compatibility

- The local database began with a clean-break v1 baseline (ADR 0007): schemas
  that predate v1 remain unsupported and must be cleared, not migrated. Every
  version from v1 onward is a supported forward-upgrade source.
- Add an exported schema snapshot for every Drift schema version and test each
  supported upgrade path against the current schema. Include a realistic
  preservation fixture whenever the migration can affect stored rows.
- Use opaque identifiers and typed contracts when an optional capability needs
  to cross the composition boundary.
- Never introduce an implicit fallback between local authority and an optional
  external authority.
- Document error states, retry behavior, and rollback before merging.

## 6. Implement in thin vertical slices

1. domain rule and typed contract;
2. local implementation and deterministic tests;
3. capability-gated presentation, if needed;
4. migration fixtures and recovery behavior;
5. architecture/ADR documentation;
6. generated inventory and verification commands.

## 7. Definition of done

- The account-free application still starts and completes its core journeys.
- No provider SDK, credential, remote identifier, wire payload, or monetization
  crossed into public code.
- Disabled capabilities are checked before any provider is read.
- Errors are typed; no new silent `catch` or implicit fallback exists.
- Relevant analyzer, unit, migration, UX, and app tests pass.
- The architecture map and ADRs describe the new local boundary.
- The generated inventory freshness check passes.
