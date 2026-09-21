# ADR 0007: Adopt `family`/`artwork`/`contributor` vocabulary and a clean schema baseline

Status: accepted
Date: 2026-09-20

## Context

The public foundation's domain types, local schema, and documentation
previously used a mix of legacy identifiers (`Masterpiece`, `Foyer`/`foyerId`,
`contributeur`) inherited from early French-first naming. These identifiers
leaked technical vocabulary that did not match the neutral, English,
vendor-agnostic contracts this repository is meant to expose (ADR 0002, ADR
0003, ADR 0004).

Separately, the local Drift database carried migration history, upgrade code,
and generated fixtures from earlier schema iterations. Preserving that history
while renaming identifiers would have required either compatibility aliases
(old and new names resolving to the same thing) or backward-compatible
migrations bridging the old and new schemas. Both options would keep legacy
names alive in the codebase indefinitely, defeating the purpose of the rename.

## Decision

1. **Canonical vocabulary.** Public code, local schema, presentation, and
   documentation use `family`/`Family`/`familyId`, `artwork`/`Artwork`, and
   `contributor`/`Contributor` as the sole English domain vocabulary. No
   occurrence of the legacy `foyer`, `masterpiece`, or `contributeur`
   identifiers remains in source, docs, fixtures, or generated artifacts.
2. **No compatibility aliases.** There are no re-exported legacy type names,
   no dual-named columns, and no deprecated-but-supported API surface. A
   caller must use the new vocabulary; there is nothing to migrate onto
   gradually.
3. **Clean-break schema baseline.** The local Drift database is rebuilt as a
   fresh `schemaVersion = 1` with no migration history, no legacy upgrade
   code, and one freshly generated schema snapshot. This is a deliberate,
   permanent reset of non-production data: existing local databases from any
   prior schema are unsupported and must be cleared before running a build
   against this baseline. There is no migration path from the old schema, by
   design — this is a hard cut, not a staged rollout.
4. **Vendor and boundary neutrality unaffected.** This rename does not change
   the public/private boundary. The public foundation continues to expose
   only opaque, generic object-key concepts (`displayObjectKey`,
   `thumbnailObjectKey`, `audioObjectKey`, ADR 0004) and no provider SDK,
   vendor identifier, or private-repository reference. Storage-vendor-specific
   terminology stays entirely inside private consumers of this repository;
   this document does not name those consumers.

## Consequences

- Any local install predating this baseline must clear its local database;
  there is no automatic upgrade. This is intentional: no production or beta
  user data is preserved across this change.
- Because there are no compatibility aliases, any code or documentation still
  referencing the legacy vocabulary is a bug, not a supported transition
  state — repository guard scans (see the guard scripts under this
  repository's CI configuration) reject the legacy identifiers outside
  localized French UI copy.
- Future schema changes resume normal practice (schema snapshot, and a
  migration test once a second schema version exists); this ADR only
  describes the one-time reset to `schemaVersion = 1`.
- French user-facing localized strings are unaffected by this decision: they
  may continue to say "foyer" and "œuvre" per this project's bilingual
  localization policy. Only code, database identifiers, contracts, docs, and
  diagrams are standardized on the English vocabulary above.
