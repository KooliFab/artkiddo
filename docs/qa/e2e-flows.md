# Local application E2E flows

Status: test specification, not an execution report. Defined from the current
checkout on 2026-10-12. No device E2E run was performed for this document.

## Scope and execution rules

The target is `app/lib/main.dart`, composed with `AppCapabilities.local`.
Exercise the installed application, real SQLite persistence, vault files and
native permission/picker/share surfaces. Controller or widget tests alone do
not establish an E2E pass.

Run these flows in the private mobile app too, except L01's capability-specific
assertions: that app exposes optional account/cloud entry points. Cloud-specific
flows and different trash behavior belong to the consuming application's own
QA catalog. This local specification is usable independently of that repository.

- P0: release-blocking data durability or core journey.
- P1: full regression and device/platform behavior.
- P2: extended resilience and boundary conditions.
- Each scenario starts from its own fixture, unless a dependency is stated.
- A restart means terminate and relaunch without clearing application data.
- Reset only disposable test installations; use synthetic images and voices.
- For persistence checks, reopen the entity after restart. A toast is not proof.
- Run P0 on iOS and Android; run native camera, audio and share cases on real
  devices. Add a tablet viewport for L16.

## Fixtures and evidence

Use a unique run suffix for two children, `E2E Ada` (2021-03-14) and `E2E Sam`
(2023-11-02), two distinct synthetic images, and two distinguishable short voice
clips. Use an explicit drawing date of 2026-09-01 in one artwork and no drawing
date in another. Record child/artwork IDs through a read-only test probe or an
export when identity checks are required.

Debug builds automatically seed Léa, Noah and eight artworks when no child
exists. A data reset followed by a debug launch therefore does not test the
production empty state. Use a release/profile test build for L01, or a dedicated
test entry point that disables seeding. Such a test entry point is not supplied
by this specification. Keep demo fixtures separate from newly created E2E data.

For each run retain: build/commit, OS/device, locale, fixture, scenario ID,
pass/fail/blocked, screenshots at checkpoints, relevant logs, and exported files
when applicable. Sanitize personal information. Missing setup or unavailable
native features mean **blocked**, not passed.

## Flows

### L01 — Account-free first launch [P0]

**Given:** empty production-style installation, network disabled, no remote
configuration.

1. Launch; open Gallery, Children and Settings.
2. Create the first child and return to Gallery.
3. Restart while still offline.

**Expect:** usable empty states before creation; the child survives restart;
capture is reachable; no account requirement, family UI, web-gallery link or
backup claim appears. No remote service is initialized or called, as checked by
device/network logs in addition to UI observations.

### L02 — Create, edit and cancel a child [P0]

**Given:** healthy local vault, offline.

1. Try to save a blank name; correct it and create Ada with a birth date.
2. Edit the name/date; cancel a changed draft, then reopen.
3. Edit again, save, and restart.

**Expect:** invalid input cannot create a profile; cancellation keeps the stored
values; saved values persist; only one child exists after repeated save taps.

### L03 — Capture an artwork from the camera [P0]

**Given:** Ada exists; camera access can be granted; offline.

1. Open Capture, grant access, photograph the synthetic drawing and crop it.
2. Select Ada, enter a story and explicit drawing date, then save.
3. Open the gallery card, zoom the image, restart and reopen it.

**Expect:** exactly one artwork attached to Ada; the saved crop, story and date
remain readable offline after restart. Success appears only after durable save.

### L04 — Import from Photos and preserve a cancelled crop [P0]

**Given:** Ada and Sam exist, offline, synthetic images in device Photos.

1. Start from Sam's filtered gallery; import an image from Photos.
2. Cancel the crop; verify the source is retained, then retry and confirm the
   mandatory crop before continuing.
3. Save without a drawing date and reopen after restart.

**Expect:** Sam remains selected; a cancelled crop does not destroy the source;
the artwork is saved once. Unknown drawing date remains unknown; age presentation
uses the documented added-date fallback without inventing a drawing date.

### L05 — Abandon drafts and recover permission denial [P1]

**Given:** reset native permission state in a disposable installation.

1. Deny camera access and verify the recovery action; grant access in OS Settings
   and return. Repeat the applicable denied/limited Photos permission branches.
2. Cancel the native photo picker; verify that no artwork was created.
3. Prepare a changed capture draft, navigate back, keep editing when prompted,
   then leave and confirm discard.

**Expect:** no crash or false save; another source remains usable; abandoning a
draft creates no gallery item; permission recovery works without reinstalling.

### L06 — Edit and clear an artwork story [P0]

**Given:** a saved artwork with a known story, offline.

1. Change its story, leave without saving and confirm discard.
2. Reopen, change and save; restart and verify.
3. Clear the story, save, restart and reopen.

**Expect:** cancellation keeps the original story; saves persist; clearing removes
the story. Keyboard and back navigation do not bypass the discard guard.

### L07 — Record, replace and delete a local voice [P0]

**Given:** a saved artwork, microphone access, offline.

1. Record a short voice, save, play it and restart.
2. Start replacement; cancel and verify the previous voice still plays.
3. Record/save a different voice; restart and play it.
4. Cancel voice deletion once, then confirm it; restart.

**Expect:** the saved voice survives restart; replacement requires confirmation;
cancel preserves the prior recording; the new voice replaces it only on save;
confirmed deletion removes audio without deleting the artwork/image/story.

### L08 — Microphone denial, recording limit and interruption [P1]

**Given:** disposable device installation; one saved artwork.

1. Deny microphone access, recover through OS Settings, and record again.
2. Record to the two-minute limit; inspect duration and playback.
3. In separate runs, background the app during recording and leave the recording
   screen before save; then resume and reopen.

**Expect:** clear denied-permission state; no recording longer than the limit;
no phantom saved voice, stuck recorder or unexpected overwrite of an existing
voice. Only recordings explicitly saved are required to survive termination.

### L09 — Filter children and return through navigation [P1]

**Given:** two children with at least two artworks each.

1. Select Ada, open an artwork and return; switch to Sam and then All Children.
2. Open Children → View artworks for Ada; return from detail and Settings.
3. Restart.

**Expect:** each filter shows only matching artwork; navigation does not create
duplicates or lose data. Filter and scroll position are session state, not a
promise of persistence across launch; startup returns to the default filter.

### L10 — Delete to local trash and restore [P0]

**Given:** an artwork with image, text and voice, offline.

1. Cancel artwork deletion; verify that it remains visible.
2. Confirm deletion; restart and open Settings → Trash.
3. Preview/zoom the deleted image; restore; restart and open Gallery.

**Expect:** confirmed deletion removes the gallery card, retains the trash item
and its media for the retention period; restore preserves its ID, child, story,
image and voice. No account or network is required.

### L11 — Purge and retention boundary [P1]

**Given:** disposable local trash containing two artworks; for expiry, a fixture
with deletion dates just inside and just beyond the 30-day boundary.

1. Cancel permanent deletion; then purge one item and restart.
2. Cancel Empty Trash; then confirm and restart.
3. In an independent expiry fixture, open Trash and relaunch the app.

**Expect:** cancellation preserves recoverability; confirmed purge cannot be
restored; expiry removes only eligible items; live artwork/media remain intact.
Use controlled fixture timestamps, not a 30-day wait or a system-clock change.

### L12 — Delete a child and reset its active filter [P0]

**Given:** Ada has artwork and is the active gallery filter; Sam has artwork too.

1. Delete Ada from Children; inspect the irreversible-deletion warning and cancel.
2. Confirm deletion in a second attempt, return to Gallery and restart.

**Expect:** cancelling changes nothing; confirmed child deletion removes Ada and
associated artwork rather than offering child recovery in Trash. Sam remains
intact; the orphaned filter resets to All Children with its one-shot notice.

### L13 — Complete archive round trip and duplicate import [P0]

**Given:** disposable vault containing both children, live artwork, a voice and a
trashed artwork; offline; native file picker/share available.

1. Settings → Archive: export and save the ZIP to device Files; inspect it.
2. Import into a separate empty test installation; restart and inspect Gallery
   and Trash, then play the voice.
3. Import the same archive a second time.

**Expect:** IDs, relationships, metadata, available media and trash state survive;
the second import produces no duplicates. The export message asks the user to
verify the file destination and does not claim a remote backup. Cancelling the
share sheet does not prove the ZIP was stored elsewhere.

### L14 — Partial/invalid archives and import collisions [P1]

**Given:** disposable vault; fixtures for missing media, invalid manifest,
unsupported version, corrupted bytes and a valid same-ID/different-content import.

1. Export with one media file unavailable; inspect the partial-export warning.
2. Cancel import in the picker; then try each invalid archive independently.
3. Import the conflicting valid archive; inspect the kept-aside result and restart.

**Expect:** partial export identifies missing content; invalid files are rejected
without damaging existing data; cancellation is inert; conflicting local data
is preserved and the kept-aside result is disclosed rather than overwritten.

### L15 — Save failure and unreadable-vault rescue [P1]

**Given:** disposable test container copied beforehand. Fault injection requires
a dedicated test setup; never corrupt an actual user vault.

1. Inject a local write failure during capture/story save; retry after recovery.
2. Separately make the copied SQLite vault unreadable; launch twice.
3. Export rescue ZIP parts; open each and inspect available images, voices and
   an in-progress capture file if present.

**Expect:** failed writes never produce a success message or discard retryable
input; retries save once. An unreadable vault shows error/retry/rescue, not a
new-user empty gallery; rescue does not need to open SQLite and discloses missing
files or insufficient space. Restore the copied healthy container after the test.

### L16 — Local image sharing, language and large text [P1]

**Given:** saved artwork, native share target, offline.

1. Share the image from artwork detail; cancel once, then save to a test target.
2. Switch French ↔ English in Settings; restart after each saved preference.
3. At 200% system text and a tablet viewport, traverse Gallery, Capture, detail,
   Children, Trash and Settings, including keyboard-visible sheets.

**Expect:** a readable image reaches the target without requiring a web link;
cancellation changes no data; language persists; controls remain reachable,
labels readable and screen-reader actions identifiable.

## Suites and existing coverage

| Suite | Flows | Purpose |
| --- | --- | --- |
| Local smoke | L01, L02, L03 or L04, L06, L07, L10 | Main offline journey and restart durability |
| Release P0 | All P0 cases, with both capture sources | Durability, deletion and archive gate |
| Full regression | L01–L16, each listed branch | Permissions, resilience and accessibility |

Existing automated tests live in `packages/artkiddo_core/test/` and `app/test/`.
Useful anchors include `capture_controller_regression_test.dart`,
`artwork_audio_confirmation_test.dart`, `local_trash_test.dart`,
`vault_archive_test.dart`, `vault_rescue_export_test.dart`,
`safe_file_writes_test.dart`, `vault_error_states_test.dart`,
`gallery_filter_reset_test.dart` and `core_independence_scenario_test.dart`.
They cover lower layers; there is no installed-device E2E suite supplied here.

## Change impact

- Public/local: documentation only; no behavior, persistence or API change.
- Optional capabilities: unchanged; enabled-capability behavior is specified in
  the private catalog, not assumed for the local build.
- Private mobile: run the shared local subset against the resolved core version.
- Web/backend: not applicable to implementing this local documentation.
- Compatibility/release order: no deployment or pin update needed for these docs.
