# ADR 0006: Public third-party dependencies in `artkiddo_core`

Status: accepted
Date: 2026-09-17

## Context

The offline-first public core package (`artkiddo_core`) contains the domain model, local database, offline vault, and the full gallery presentation layer. To render rich multimedia experiences, take photos, record voice stories, display QR codes, and share artworks without cloud infrastructure, the core depends on select Flutter packages.

### The Seam Rule: Core Owns Neutral Presentation

Under the consolidation architecture:
- **Generic never knows specific**: `artkiddo_core` owns the complete visual and interactive presentation for all neutral features (Gallery, Artwork viewer/editor, Capture flow, Audio recording, Children/Trash management, Settings About/Language, and account-free Share & Family interfaces).
- **Core declares slots, compositions fill them**: generic controllers and screens declare honest default affordances and abstract hooks (`GalleryActions`, `CompositionActions`, `familyConvergenceProvider`, `RemoteMediaFetcher`). When a destination or capability is unsupported in local offline mode, affordances are hidden or display honest account-free interfaces—they never crash or present inert broken controls.
- Application compositions may override these contracts via typed Riverpod
  overrides and action callbacks to connect optional external features. The
  public core does not name or implement those external services.

Under `public-code-rules.md`, public dependencies must satisfy four strict criteria:
1. **Product necessity**: Required for offline product behavior, local media capture/playback, or offline UI rendering.
2. **Permissive Open-Source License**: BSD, MIT, or Apache-2.0.
3. **No telemetry or remote SDKs**: Self-contained packages with zero tracking, proprietary backend SDKs, or cloud analytics.
4. **Stability & Community Adoption**: Well-maintained, standard Flutter plugins vetted across the ecosystem.

## Decision

The following third-party dependencies are declared in `artkiddo_core/pubspec.yaml` and justified under the four criteria:

### 1. Presentation & UI Layout
- `photo_view` (^0.15.0): Enables interactive pinch-to-zoom and pan on artwork details in the full-screen view (MIT).
- `qr_flutter` (^4.1.0): Renders QR codes in pure Dart without native platform permissions or network access, used for displaying invite and share codes offline (BSD-3-Clause). Note: QR *scanning* (`mobile_scanner`) remains private in the composition and is injected dynamically.

### 2. Media Capture & Playback
- `camera` (^0.12.1): Official Flutter plugin providing direct access to the device camera for artwork photography (BSD-3-Clause).
- `image_picker` (^1.2.3): Official Flutter plugin allowing the user to pick photos from the local photo gallery (BSD-3-Clause).
- `image_cropper` (^12.2.1): Allows local cropping, perspective adjustment, and rotation of captured artworks prior to persistence (Apache-2.0 / MIT).
- `record` (^7.1.1): Native audio recording for children's voice recordings attached to artworks (MIT).
- `just_audio` (^0.10.5) & `audio_session` (^0.2.4): Low-latency local audio playback and audio focus management for artwork voice stories (Minor-style BSD).

### 3. Platform & System Integration
- `share_plus` (^13.3.0): Triggers native system share sheets to share local artwork images via standard OS channels (BSD-3-Clause).
- `url_launcher` (^6.3.2): Official Flutter plugin for opening external standard URLs (e.g. system settings or documentation) (BSD-3-Clause).

### 4. Deliberately excluded

- `flutter_staggered_grid_view`: removed on 2026-09-23. Its lazily measured
  masonry sliver estimates its scroll extent and corrects the offset as it
  discovers tile heights, which pulled the viewport back up near the end of
  a long gallery and made the oldest artworks unreachable. Every gallery tile
  already knows its aspect ratio, so the core places the feed exactly with a
  `SliverGridDelegate` of its own (`masonry_layout.dart`) on Flutter's
  `SliverGrid`. The dependency bought nothing that exact placement does not.
- `mobile_scanner`: stays outside the public package. Rendering a QR code is a
  pure Dart drawing operation, but reading one requires a device capability the
  account-free product does not need. The public core exposes
  `CompositionActions.openQrScanner`; an application composition may bind it.
  A local build therefore ships no scanning code and requests no permission for
  it.

## Boundary impact

- `artkiddo_core` remains self-contained and account-free. None of these
  packages communicate with an external service.
- Optional application compositions consume the public contracts and inject
  capabilities through `overrides` and `CompositionActions`.
