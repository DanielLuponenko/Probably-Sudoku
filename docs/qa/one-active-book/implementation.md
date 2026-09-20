# One current Book and visible obstacle effects

Implemented September 20, 2026. Native walkthrough and screenshots are in [native-review.md](native-review.md).

## Player behavior

- Home presents Continue with the saved Book title, chapter, puzzle or Shop, turn when applicable, and coins. A completed receipt says View final page. Failed Books do not present Continue.
- Play browses Books without abandoning the current attempt. Opening a selected Book while an attempt exists offers Continue current Book, Abandon & start new, or Back to the shelf. This also applies to selecting the same cover again.
- Continue re-reads the saved game at acceptance. Starting a replacement checks the exact named saved state, writes the new Book atomically, and then opens its cover. Repeated callbacks cannot accept the old decision again. Failed writes leave the old Book available.
- The retired device-copy picker is removed. The valid local Book remains the current attempt; different cloud snapshots are preserved privately as rollback evidence, never offered as additional playable Books. A cloud-only Book can be adopted durably when there is no local save. Invalid local or cloud data is protected from accidental replacement.
- Abandonment, failure and completion retirement remember observed alternate attempts so delayed cloud delivery cannot bring them back as another Continue choice. Existing completion receipts and unlocks remain compatible.
- The existing chalk sign keeps the Book benefit and prints the selected obstacle's engine-derived restrictions. Standard Obstacle I keeps its previous benefit-only sign. The top edge and width stay fixed; VI–IX extend the face slightly downward to make their larger effect lettering readable. The existing erase/write animation is reused, including interruption by another selection. Native accessibility exposes the full effect explanation.

Local authority is intentional: historical saves have no causal revision or attempt UUID that safely determines which of two divergent checkpoints is the player's intended one. This change does not promise server-enforced exclusivity between two offline devices. Received alternatives are archived before a write would supersede them.

## Verification

Focused simulator gates: **93 distinct tests passed, zero failures** on iOS 26.3. The first gate passed 80 tests; the final sign refinement passed a focused 29-test gate, including 13 additional tests and 16 relevant rechecks.

| Suite | Tests | Coverage |
| --- | ---: | --- |
| DiscardedRunPersistenceTests | 37 | One authority, explicit replacement, delayed cloud data, retirement, atomic failures, rollback receipts, corrupt data, unknown envelopes and legacy saves |
| CloudRunConflictTests / CloudRunTransportTests | 9 | Exact comparison and compatible transport |
| RunStoreCompletionCompatibilityTests / CompletionDurabilityTests | 8 | Completion receipts and durable unlock preservation |
| RunPersistenceLifecycleTests | 3 | Abandoned owners reject delayed preparation and callbacks |
| SavedBookSummaryTests | 4 | Real saved state, completed/failed presentation, rendered home controls at 280/346 pt and largest accessibility text |
| PaperDesignSystemTests | 3 | Paper decision presentation |
| BookstoreSignPresentationTests | 4 | All 108 Book/Obstacle combinations; rendered text and readable glyph size; fixed top/width and exact downward extension; bounded cache; rapid SceneKit animation interruption |
| BookScenePresentationTests | 13 | Existing Book scene behavior |
| BookstoreObstacleTests | 12 | Selection, per-Book unlocks, ribbons and obstacle presentation |

Result bundle: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.20_00-15-11-+0300.xcresult`.

Log: `/tmp/nc-one-active-book-gate-2.log`. Final refinement result: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.20_00-36-29-+0300.xcresult`; log: `/tmp/nc-one-active-sign-readability-gate.log`.

Initial gate failures were corrected before the passing gate: the summary fixture incorrectly advanced instead of starting a puzzle; the SceneKit animation test used synthetic timestamps with two renderers sharing the scene. The animation test now uses real frame time and retains its partial-erasure, latest-artwork and completion assertions.

An independent source review found no actionable regression in the start/continue/replacement flow. Native QA uses a separate simulator and the Debug-only `-isolateCloudQA` flag, which disables all real cloud reads, delivery and publishing while keeping real local persistence. The user's simulator is not used for destructive QA.

Native review identified small IX restriction text. Effects were increased from 44 to 56 texture points, with a less dominant benefit heading and a matching-aspect face extended downward by 0.06 scene units. The revised tests verify complete text fit, larger actual rendered glyph bounds, fixed top/width, restoration to the standard size, and interruption of the chalk animation.

Final plain build passed: `/tmp/nc-one-active-book-final-build.log`.
Final candidate: `/tmp/NumberClub-one-active-book-final-20260920-0038.app`.
Debug dylib SHA256: `16dac052f2d3fedddaa9914e87f857c57c9f21f20a3b4aa044e0d32988c51733`.

## Native walkthrough and handoff

The independent native report records successful resume, cancellation, explicit replacement and relaunch, plus final obstacle text/geometry/animation checks. Native QA identified and rechecked the typography refinement. Its isolated simulator's original eight files were restored and cloud blobs/timestamps remained unchanged.

The final candidate was installed on the user's iPhone 17 Pro simulator (`223A4227-A28E-4939-BB5E-3AAB820EB635`) and launched normally without QA arguments. Backup: `/tmp/NumberClub-one-active-book-user-backup-20260920-004449`. Preservation record: `/tmp/nc-one-active-book-user-install.json`.

All 14 original Application Support/Preferences files matched after installation and initial launch. Later, only the Game Center banner metadata key changed (`GKSignInBannerPresentationDataKey`); game preferences and progress stayed intact. There was **no active run.json before installation**, so this simulator correctly shows Play alone until a Book is started. The Continue feature was verified against a real saved run on the isolated QA device. The user's simulator is foregrounded on its normal home screen.
