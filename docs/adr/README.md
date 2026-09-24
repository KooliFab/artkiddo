# ADR index

Pick the one ADR that matches the task from this table; do not read them all.
Cite ADRs by file name. Missing numbers (0005, 0008–0013) are intentional: the
numbering is shared with decisions recorded outside this repository.

| File | Decision | Status |
|---|---|---|
| `0001-local-first-foundation.md` | The public app creates, edits and recovers artwork with no account, configuration or network | Current |
| `0002-public-foundation-boundary.md` | The public foundation is self-contained; consumers and external services are not its concern | Current |
| `0003-capabilities-and-neutral-adapters.md` | Optional remote behavior through neutral contracts and explicit capabilities validated at boot | Current; boot validation extended by 0016 |
| `0004-neutral-object-keys.md` | Artworks store opaque `displayObjectKey`/`thumbnailObjectKey`/`audioObjectKey` | Current |
| `0006-staggered-grid-dependency.md` | Rules and justification for every third-party dependency of `artkiddo_core` | Current |
| `0007-family-artwork-vocabulary-and-clean-schema-baseline.md` | English `family`/`artwork`/`contributor` vocabulary, clean schema v1 baseline | Current; schema has since grown to v3 by additive migrations |
| `0014-immediate-native-background-upload.md` | `CompositionActions.onArtworkSaved` fires best-effort after the local commit | Current |
| `0015-discard-previous-family-on-join.md` | Joining another family requires confirmation, then discards the previous one | Current |
| `0016-local-default-destinations.md` | Capability-gated vs local-default `CompositionActions`; local features never disappear | Current |
