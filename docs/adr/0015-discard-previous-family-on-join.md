# ADR 0015 — Confirm, then discard, a previous family on join

Redeeming another family's invite code used to fire straight from the
submit button — and, worse, straight from a QR scan with zero
friction — with no warning that the local vault can only ever be bound
to one family at a time (`VaultMetaRepository.attachFamily` already
throws `FamilyMismatchException` on a mismatch; nothing ever resolved
that exception). A parent could lose every local child and artwork by
mis-scanning a code.

`FamilyScreen` now routes both entry points through a single
`_JoinFamilyDialog`: a read-only local bilan (child/artwork counts,
never a server call) followed by an explicit, checkbox-gated
acknowledgement. Nothing is touched until that second step is
confirmed.

`FamilyApi.redeemInvite` gained `discardPrevious`. `RedeemOutcome`
gained two booleans: `sameFamily` (the code was the caller's own — no
membership change happened) and `vaultReset` (a previous family was
actually discarded — the local vault must be rebuilt before
convergence). Both default to `false`, so an adapter that never sets
them degrades to the old behavior.

`FamilyController.redeem` reads `vaultReset` and, only then, calls a
new `familyVaultResetProvider` hook (no-op by default, like
`familyConvergenceProvider`) before chaining convergence. The reset
step is tracked as its own `AsyncAction` (`FamilyState.joinReset`),
distinct from `redeem` and `convergence`: the server-side join already
committed by the time this step runs, so its failure is retryable in
isolation (`FamilyController.retryJoinReset`) without re-redeeming an
already-consumed code — re-redeeming would now see `sameFamily: true`
and silently skip the reset it was meant to retry.

Whether a previous family is purged outright or merely left is a
server-side decision (does the caller's departure leave zero active
members?), never inferred client-side.
`FamilyController.isAloneInFamily()` mirrors
`AccountController.isLastActiveFamilyMember()` exactly — both answer
the same question for two different destructive actions — but it only
ever picks which warning copy the dialog shows; it has no bearing on
what the server actually does.
