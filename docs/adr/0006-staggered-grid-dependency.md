# ADR 0006: Gallery presentation dependencies (staggered grid and share_plus)

Status: accepted
Date: 2026-09-17

## Context

The ArtKiddo gallery feed (`GalleryScreen`) and detail view (`ArtworkScreen`) require:
1. A responsive, multi-column masonry/staggered grid layout to display artwork items with varied aspect ratios without awkward letterboxing or uniform cropping (`flutter_staggered_grid_view: ^0.7.0`).
2. Native system share sheet invocation for exporting and sharing local artwork images via standard OS channels (`share_plus: ^13.3.0`).

To consolidate the public core (`artkiddo_core`) and enable the offline account-free app to render the identical gallery feed and allow standard OS artwork export without cloud accounts, `GalleryScreen` and `ArtworkScreen` live in `artkiddo_core`.

## Decision

Add `flutter_staggered_grid_view: ^0.7.0` and `share_plus: ^13.3.0` to `artkiddo_core` dependencies.

Justification under `public-code-rules.md`:
1. **Product necessity**: Required for offline layout rendering of the photo wall and native OS image sharing.
2. **License**: BSD / MIT open-source packages.
3. **No telemetry or remote SDKs**: Pure Flutter plugins interacting only with local layout and native system share intents.
4. **Stability**: Widely adopted in Flutter community and already vetted in `artkiddo-cloud`.

## Cross-repository impact

- `artkiddo_core` can now host `GalleryScreen` and `ArtworkScreen`, providing the complete feed and artwork detail UI to both public local compositions and private cloud apps.
- No schema or backend changes.
