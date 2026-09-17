# ADR 0006: Public third-party dependencies in `artkiddo_core`

Status: accepted
Date: 2026-09-17

## Context

The offline-first public core package (`artkiddo_core`) contains the domain model, local database, offline vault, and the full gallery presentation layer. To render rich multimedia experiences, take photos, record voice stories, display QR codes, and share artworks without cloud infrastructure, the core depends on select Flutter packages.

### The Seam Rule: Core Owns Neutral Presentation

Under the consolidation architecture:
- **Generic never knows specific**: `artkiddo_core` owns the complete visual and interactive presentation for all neutral features (Gallery, Artwork viewer/editor, Capture flow, Audio recording, Children/Trash management, Settings About/Language, and account-free Share & Family interfaces).
- **Core declares slots, compositions fill them**: generic controllers and screens declare honest default affordances and abstract hooks (`GalleryActions`, `CompositionActions`, `foyerConvergenceProvider`, `RemoteMediaFetcher`). When a destination or capability is unsupported in local offline mode, affordances are hidden or display honest account-free interfaces—they never crash or present inert broken controls.
- Private compositions (`artkiddo-cloud`) override these contracts via typed Riverpod overrides and action callbacks to connect proprietary backend features (Supabase sync, cloud foyer join/invite, web gallery public links, R2 remote media downloading).

Under `public-code-rules.md`, public dependencies must satisfy four strict criteria:
1. **Product necessity**: Required for offline product behavior, local media capture/playback, or offline UI rendering.
2. **Permissive Open-Source License**: BSD, MIT, or Apache-2.0.
3. **No telemetry or remote SDKs**: Self-contained packages with zero tracking, proprietary backend SDKs, or cloud analytics.
4. **Stability & Community Adoption**: Well-maintained, standard Flutter plugins vetted across the ecosystem.

## Decision

The following third-party dependencies are declared in `artkiddo_core/pubspec.yaml` and justified under the four criteria:

### 1. Presentation & UI Layout
- `flutter_staggered_grid_view` (^0.7.0): Required for the responsive, multi-column masonry feed displaying artworks with variable aspect ratios without artificial cropping (MIT).
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

- `mobile_scanner`: **stays private.** Rendering a QR code is a pure Dart
  drawing operation, but reading one requires the camera for a purpose the
  account-free product never has: joining a household. The public core exposes
  `CompositionActions.openQrScanner`, and only the private mobile composition
  binds it. A local build therefore ships no scanning code and requests no
  permission for it.

## Cross-repository impact

- `artkiddo_core` remains completely self-contained and account-free. None of these packages communicate with any remote backend.
- Private mobile compositions (`artkiddo-cloud`) consume these features directly from `artkiddo_core` while injecting backend capabilities (cloud synchronization, authentication, and QR scanning) via clean composition seams (`overrides` and `CompositionActions`).
