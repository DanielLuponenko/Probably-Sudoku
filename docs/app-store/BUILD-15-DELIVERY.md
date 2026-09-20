# Version 1.1.0 — build 15

Updated 20 September 2026. The owner authorized committing, pushing, merging to main, uploading the new App Store version, and replacing outdated store screenshots. **Version 1.1.0 (15) is uploaded and Waiting for Review.** Both refreshed screenshot galleries are saved and included in the submission.

## Changes

- Expanded catalogue: 50 Bookmarks, 50 Markers and 40 Buffs, with shared artwork and player-facing definitions.
- New Books use 22 distinct bosses: 16 regular encounters and six finales. Historical boss identities remain loadable.
- Unlimited ordinary-puzzle skips award a previewed consumable Buff. Bosses remain mandatory. Full inventory requires an explicit replacement choice; skip, reward and progression commit together.
- Live ordered Points × Mult scoring and readable score receipts; direct marker inspection, Clue selection and hand arrangement.
- One unfinished Book, clear Continue/abandon choices, durable results and per-Book local completion achievements.
- Revised tutorial, Help media, settings and audio controls; independent in-game Reduced Motion preference.
- Responsive Shop/results/briefing layouts, page-turn and boss animation improvements, enlarged-text controls and numerous lifecycle fixes.

Exact English update, product description and reviewer copy: [metadata](metadata/1.1.0-en-US.json). The update notes use “Version 1.1.0”, “Changes:” and the owner's requested closing thanks.

## Validation

- Full engine suite: **500 tests passed**, zero failures, 382.162 seconds.
- Focused app release gate: **206 tests passed**, zero failures, covering distribution/ad configuration, skip transactions, persistence, completion, progression, scoring, marker inspection, inventory identity, motion and boss state.
- Achievement punctuation/registration follow-up: **7 tests passed**, zero failures. This overlaps the earlier gate; it is not seven additional distinct cases.
- The prior [visual audit](../qa/visual-audit-20260920/review.md) and [independent native playtest](../qa/visual-audit-20260920/native-playtest.md) retain the visual and interaction evidence and its physical-device limits.
- App Store version 1.1.0 was created and English release notes, current description, promotional text and review notes were saved. Manual release is selected, preserving the preceding release policy.
- Twelve per-Book awards are intentionally local; the existing 19 registered Game Center IDs are unchanged. No claim of new Game Center server awards is made.

Local build, test and distribution evidence: `/Users/daniel/Downloads/ProbablySudoku-Build15-20260920/`.

## Repository evidence

Written QA reports, reproducible fixtures and source assets are committed. Large native QA screenshot/movie collections and private simulator save backups remain on disk and are ignored by Git; they were not deleted or reset. Shipped app images and videos remain tracked. Historical source artwork and rollback evidence are preserved.

Physical-device Display Zoom, haptic quality, sustained hardware performance and complete VoiceOver traversal remain outside the simulator verification scope. Current player saves and the separate Book Playtest A session were preserved.

## Source and upload receipt

- Source commit `025defbbfb7d55cbdb528f3f337092be00e9a8c5` pushed and merged through [PR #123](https://github.com/DanielLuponenko/Probably-Sudoku/pull/123) to main `3de344e1e0e0a2a4edd6d1cae3c11b00e717f92d`.
- Signed Production archive succeeded. Verified bundle `com.numberclub.app`, version 1.1.0, build 15, both device families, live production ad configuration, three privacy manifests, valid signature and no test bundles. The bundled expanded catalogue is byte-identical to the release source.
- App executable and dSYM UUID match: `4A12349E-34EC-3E46-813A-5547255EF56A`. All 249 recorded app/engine/configuration source hashes match the merged main source.
- Apple upload succeeded at **14:52:09 Asia/Jerusalem, 20 September 2026**. Xcode reported `Uploaded package is processing`, `Upload succeeded` and `EXPORT SUCCEEDED`.
- Apple processing completed. Build ID `2f166158-3281-48f0-8293-ac890af7136e` is **Ready to Submit** in TestFlight and was selected and saved for App Store version 1.1.0. This is not a claim of external-beta distribution or App Review approval.
- The two Google vendor frameworks again emitted non-blocking missing-dSYM warnings. The app's own matching dSYM was verified; Apple accepted the upload without a validation error.
- Fresh [iPhone and iPad screenshots](screenshots/version-15/CAPTURE-MANIFEST.md) include gameplay with live scoring, active-roster Garry the Gray, Shop, next-puzzle Buff choice and Book selection. Five native captures per device family; source images and verification hashes are retained with the manifest.

## App Review and screenshot receipt

- Submitted **20 September 2026 at 15:25 Asia/Jerusalem**. Apple confirmed “1 Item Submitted” and **Waiting for Review** for **1.1.0 (15)**.
- Submission ID: `4efbb69a-b277-4b32-b462-553c927b5cbf`. [App Review receipt](https://appstoreconnect.apple.com/apps/6808968186/distribution/reviewsubmissions/details/4efbb69a-b277-4b32-b462-553c927b5cbf).
- Replaced the outdated galleries with five iPhone 6.5-inch and five iPad 13-inch screenshots. Both saved galleries show the same order: gameplay, Garry the Gray bricks, Shop, next-puzzle Buff offer, Book selection.
- An independent reviewer verified every screenshot hash, dimensions, opacity and absence of private image metadata. The final metadata correctly says players **start** with two Buff slots; Pocket Insert can increase capacity.
- **Manual release remains selected.** This submission is awaiting Apple's review; version 1.0.2 remains the current public version. No approval or public release is claimed.
