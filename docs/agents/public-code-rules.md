# Coding rules for the public artkiddo repository

Status: target contract for code classified as public during extraction, and for
all code in the public repository after the split.

## Architecture and dependencies

- Keep domain and contracts independent from Flutter widgets, Riverpod,
  databases, filesystems, and vendor SDKs.
- Depend inward: presentation -> application/controllers -> domain/contracts;
  local adapters implement public contracts at the edge.
- Inject clocks, UUID generation, filesystem access, and network-like services
  when determinism matters. Do not reach global SDK singletons from reusable
  code.
- Make required dependencies constructor parameters. Do not hide production
  defaults in a constructor or provider.
- Export supported APIs only through `lib/artkiddo_core.dart`; treat `lib/src/`
  as internal.

## Public/private boundary

- Prohibit provider SDK imports and provider-owned types in public code.
- Prohibit table, bucket, RPC, endpoint, Edge Function, and private product
  identifiers in public contracts, comments, fixtures, and logs.
- Prohibit untyped wire payloads across the boundary. Private adapters decode
  wire data and return typed public DTOs or domain results.
- Name concepts by their role (`objectKey`, `remoteRevision`, `SyncBackend`), not
  by their current vendor.
- A public dependency must be necessary for the offline product, license
  compatible, actively maintained, and free of required telemetry or network
  setup. Record non-obvious choices in an ADR.

## Local-first behavior

- Creating, reading, editing, deleting/restoring supported local entities, and
  restarting the app must work without an account or network.
- Report success only after the authoritative local write is durable.
- Treat remote synchronization as an enhancement after local persistence, not
  as a prerequisite for local success.
- Never erase or reset the local vault as automatic error recovery.
- Do not announce a cloud guarantee from the public/local experience.

## Capabilities and presentation

- Validate capability/service combinations before `runApp`.
- Check capability availability before constructing or reading its provider.
- Hide unavailable remote actions or provide an honest local alternative. Do
  not show disabled controls that imply a broken service.
- Keep native sharing separate from remote gallery-link sharing.
- Cover loading, empty, error, retry, double-submit, navigation-away, semantic
  labels, focus, contrast, and French/English formatting where affected.
- Put user-facing text in localization resources, not inline strings.

## Data, sync, and files

- Give every Drift schema change an exported schema snapshot, migration test,
  integrity check, forward-only production recovery plan, and realistic fixture.
- Make active-record queries explicitly exclude soft-deleted rows.
- Keep slow image/audio/network work outside database transactions.
- Use write-then-rename or an equivalent atomic file strategy; persist deferred
  cleanup work before reporting a logical purge as complete.
- Make sync operations idempotent, paginated, and bounded in memory.
- Keep an independent cursor per remote stream; advance a cursor only after the
  page is durably committed. Document conflict resolution in the contract.

## Errors, privacy, and observability

- Convert technical exceptions to named `AppFailure` variants at boundaries.
- Prohibit new `catch (_) {}` blocks unless best-effort behavior is documented,
  observable, and tested.
- Do not log tokens, personal data, artwork/story contents, raw payloads, or full
  local paths. Log stable error categories and anonymous operational context.
- Keep telemetry absent from the public app unless a separately approved,
  explicit opt-in design is adopted.

## Verification

Before completion, format changed Dart files and run the smallest relevant test
set, then the workspace analyzer and full public tests. Run dependency-boundary,
secret, license, and generated-inventory checks when dependencies or boundaries
change.

Comments should explain invariants and tradeoffs. They must not preserve private
provider details that the code intentionally abstracts.
