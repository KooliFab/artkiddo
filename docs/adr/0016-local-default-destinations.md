# ADR 0016: Local-default destinations, and capability gating that means one thing

Status: accepted
Date: 2026-09-22

## Context

Moving options and features into the screens that own them left the gallery's
app bar deciding, per control, whether to render — and it ended up with two
incompatible rules applied inconsistently:

```dart
if (capabilities.webGalleryLinks && actions.openGalleryShare != null)  // share
if (actions.syncPhotos != null)                                        // sync
if (actions.openFamilyHub != null)                                     // family
if (actions.openSettings != null)                                      // settings
```

Three consequences followed.

**A capability-backed control escaped both gates.** `syncPhotos` is the user's
only handle on `remoteBackup`, yet nothing checked the capability and
`_validateComposition` had no rule for it. A composition could enable
`remoteBackup`, forget the action, and ship a build that backs up in the
background with no way to trigger or observe it — the hidden-control
degradation ADR 0003 exists to prevent.

**Local-only features became composition-gated.** Settings rendered only when
a composition supplied `openSettings`. The account-free composition supplies
nothing, so `LanguageScreen`, `AboutScreen` and `TrashScreen` became
unreachable code and `DebugSettingsScreen` survived only through a hardcoded
button on the children list. `docs/architecture/feature-matrix.md` classifies
"Account-free settings" and "Recoverable local deletion" as `local-only` with
optional boundary "none required"; the code had quietly contradicted both, and
with them AGENTS.md's non-negotiable account-free path.

**A destination was labelled as something it is not.** The account-free build
bound `openFamilyHub` to `ChildrenScreen` and tooltipped it "Famille",
promising a household that no account-free composition has.

## Decision

1. **Two rules, and only two, decide whether an app-bar control renders.**

   * *Capability-gated* (share, sync): rendered only when the capability is
     enabled **and** the composition bound the action. Both halves are
     required, and `_validateComposition` guarantees they agree, so either one
     missing means the feature genuinely is not in this build.
   * *Local-default* (people, settings): always rendered, because each has an
     honest account-free destination inside this package.

2. **A `CompositionActions` entry for a local-default control substitutes the
   destination; it does not gate the control.** `openSettings` and
   `openFamilyHub` replace `SettingsScreen` and `ChildrenScreen` with a
   composition's richer surface. A composition that substitutes one owns
   keeping the local rows it replaces reachable from its own surface.

3. **`SettingsScreen` is public core.** It hosts language, trash, about, and —
   in debug builds — the debug tools. Every row is local-only: no capability,
   no account, no network.

4. **`remoteBackup` requires `CompositionActions.syncPhotos`**, enforced by
   `_validateComposition` like every other capability/binding pair.

5. **A control whose destination varies names what it actually opens.** The
   people control reads "Famille" only when a household hub is bound, and
   "Enfants" otherwise.

## Consequences

- `app/lib/main.dart` overrides nothing. That is the point: the account-free
  composition is now a genuine demonstration that the core stands alone, and
  any future need for an override there is a signal that something local-only
  has drifted behind a capability again.
- Compositions enabling `remoteBackup` must bind `syncPhotos` or fail at boot.
  This is a deliberate breaking change for existing cloud compositions; the
  failure is loud and names the missing binding.
- A composition substituting `openSettings` inherits the duty to expose
  language, trash and about. The core cannot verify this, so it is stated here
  rather than pretended to be enforced.
- `AuthGateway` is deleted. It modelled identity a second time alongside
  `FamilyApi`'s `UserProfile`, had no provider, no default implementation and
  no reference anywhere — an orphan interface, not a seam.
