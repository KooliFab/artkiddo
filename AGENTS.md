# ArtKiddo public repository contract

## Read only what the task needs

| Task | Read first |
|---|---|
| Local fix, UI tweak, test, single-file change | nothing more; open the files involved |
| Domain wording or invariant | `CONTEXT.md` and the one related ADR in `docs/adr/` |
| Feature, refactor, contract, schema, provider or repository change | `docs/agents/feature-workflow.md` and `docs/architecture/current-state.md` |
| Adding a dependency or public API | `docs/agents/public-code-rules.md` |

`docs/agents/public-code-rules.md` applies to all public code even when you do
not reread it; the rules below are its non-negotiable core.

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
messages. User-facing localizations remain translated (edit the `.arb` files).
Regenerate, never hand-edit, `docs/architecture/generated-inventory.md`.
