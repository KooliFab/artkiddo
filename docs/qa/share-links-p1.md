# Share-link lifecycle and retry fixes

## Local impact

- Classification: capability-gated.
- Local behavior and invariant: the account-free image-sharing path stays usable without an optional service.
- Public contract or domain model changed: no change to SharingService or ShareLink; additive load failure and retry presentation state.
- Capability or composition change: the share controller lives only while its sheet is observed and reloads when the session changes.
- Local schema/file migration: not applicable.
- Error and fallback behavior: list failures have an explicit retry; a past transport failure does not prevent a new create attempt; late results cannot update a disposed or rebuilt controller.
- Tests and fixtures: controller lifecycle, session transitions, retry, late responses and widget interaction using local repositories and a fake sharing service.
- Compatibility window: additive presentation behavior, no backend protocol change.
- Rollback: revert the core change; no persisted data migration is needed.
- Architecture/ADR documents to update: current-state sharing lifecycle description; no architectural ownership boundary changes.

## Cross-repository impact

- Public/local: neutral capability-gated share controller and UI, with unit/widget regression coverage.
- Private mobile: consumes the corrected core after its release; concrete adapters and current development are not changed here.
- Web: not applicable to this P1 slice.
- Backend: not applicable to this P1 slice.
- Backend contract and locks: no change.
- Release order: validate and release the public core first, then pin its resulting immutable commit in the private mobile integration change. Local worktree validation is not a mobile release.
- Follow-up: browser audio/configuration fixes and full adapter/backend/staging coverage remain separate work.

## Validation

- 19 targeted share tests passed, including 12 lifecycle, retry and widget regressions added for this change.
- The full core suite passed: 172 tests. The local application suite passed: 1 test.
- Workspace analysis passed without diagnostics. The public boundary guard and generated inventory freshness check passed.
- The widget regressions exercise a 390 x 844 viewport, retry after a network failure, link creation, reopening after sign-in and capability-disabled local sharing.
- The original development checkouts were not edited. This candidate is validated in the isolated core worktree; the private app still needs to adopt the released core commit.
