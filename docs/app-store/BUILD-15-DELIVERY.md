# Version 1.1.0 — build 15

Prepared 20 September 2026. The owner authorized committing, pushing, merging to main, uploading the new App Store version, and replacing outdated store screenshots. Delivery receipts will be added after upload and submission are confirmed.

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
- The prior [visual audit](../qa/visual-audit-20260920/review.md) and [independent native playtest](../qa/visual-audit-20260920/native-playtest.md) retain the visual and interaction evidence and its physical-device limits.
- App Store version 1.1.0 was created and English release notes, current description, promotional text and review notes were saved. Manual release is selected, preserving the preceding release policy.
- Twelve per-Book awards are intentionally local; the existing 19 registered Game Center IDs are unchanged. No claim of new Game Center server awards is made.

Local build, test and distribution evidence: `/Users/daniel/Downloads/ProbablySudoku-Build15-20260920/`.

## Repository evidence

Written QA reports, reproducible fixtures and source assets are committed. Large native QA screenshot/movie collections and private simulator save backups remain on disk and are ignored by Git; they were not deleted or reset. Shipped app images and videos remain tracked. Historical source artwork and rollback evidence are preserved.

Physical-device Display Zoom, haptic quality, sustained hardware performance and complete VoiceOver traversal remain outside the simulator verification scope. Current player saves and the separate Book Playtest A session were preserved.
