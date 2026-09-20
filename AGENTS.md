# ArtKiddo public repository contract

Read `docs/architecture/current-state.md`, `CONTEXT.md`, and the relevant ADRs
before changing code. Follow `docs/agents/feature-workflow.md` for every
feature, refactor, contract, schema, provider, or repository change. Follow
`docs/agents/public-code-rules.md` for all public code.

The account-free local path is non-negotiable: it must remain persistent,
functional, and testable without configuration or network access. Classify
every feature by its local ownership and optional capability boundary. State
explicitly when an optional boundary is not affected.

Public code owns domain behavior, local persistence, local files, neutral UI,
and vendor-neutral contracts. It must not contain a provider SDK, credential,
remote identifier, wire payload parsing, provider-specific object-key format,
or monetization. Application compositions inject optional capabilities and
validate them before reading any capability-owned provider.

Use English for public documentation, comments, identifiers, and commit
messages. User-facing localizations remain translated. Regenerate, never
hand-edit, `docs/architecture/generated-inventory.md`.
