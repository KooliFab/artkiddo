# Public dependency rules

- `lib/artkiddo_core.dart` is the supported package surface; production
  consumers must not import `lib/src`.
- A dependency must serve the offline path, be license-compatible, and not
  require telemetry or network configuration.
- Public code cannot include provider SDKs, remote wire maps, private endpoint
  or schema identifiers, credentials, environment values, or billing logic.
- Camera, microphone, files, and image dependencies are allowed only to support
  an account-free local capability.
- Record a non-obvious dependency in an ADR or feature matrix and refresh the
  generated boundary inventory after dependency changes.

The dependency direction is `app -> artkiddo_core`. A private client may depend
on public contracts and a pinned backend contract; no public code may depend on
private code.
