# Marker inspection verification — 19 September 2026

## Scope and implementation

- Removed board-only decorative boss underprints, receipt lines, perimeter artwork, clock rings, Fog washes and Censor underlines. Sudoku wells/grid, numerals, marker symbols, Clue/Litmus feedback, real fouled squares and Garry bricks remain.
- Each live cell has mutually exclusive native tap/400 ms hold recognizers. A recognized hold consumes its release, even after movement, cancellation or lost eligibility. A new touch can tap normally. The touch surface is limited to the cell and does not cover the Hand, inventory or its scrolling/drag controls.
- The temporary ivory/sage popup uses the same catalogue-backed `MarkerInspectionInfo` as the question-mark marker map. It reads no solution, changes no gameplay selection and owns no saved state or random stream.
- Given-covered, filled and temporarily barred positions have distinct availability messages. Filled-square copy explicitly preserves previously earned effects for their stated duration. Jade's catalogue text explicitly says it does not cancel the wrong-placement penalty.
- Fog hides marker information, outlines, inspection actions and feedback. The question-mark map previously leaked hidden positions; it now uses the same visibility projection.
- The accessibility action exposes the same content with an always-visible Dismiss footer and Escape action. Long text scrolls inside the paper popup at large accessibility sizes. Touch-held content dismisses on release. The popup has no presentation animation and leaves the board layout stationary.
- Viewport changes, navigation, obscuring overlays, backgrounding, new turns and Fog changes invalidate the presentation. Popup bounds are defensively clamped even for a stale anchor.

## Automated evidence

89 distinct focused tests passed across the verification runs. The 87-test combined run passed before two additional presenter/bounds tests were added. The final build reran all 25 directly affected marker/geometry tests after the fixed dismissal footer was added; all passed.

| Suite | Tests | Coverage |
| --- | ---: | --- |
| BossBoardVisualTests | 31 | Clean passive-boss board parity; real restrictions/bricks; Fog concealment |
| GameplayGeometryTests | 5 | All 81 actual cells, Hand geometry, Litmus shapes and Fog accessibility |
| HandCluePresentationTests | 18 | Existing Hand, Clue and Peek behavior |
| InventoryDragTests | 9 | Existing selling, reordering, cancellation and action-row geometry |
| MarkerInspectionContentTests | 8 | All 12 catalogue explanations, Jade, availability, Fog, immutable run, one feedback and owner-aware dismissal, stale-anchor bounds |
| MarkerInspectionGestureTests | 10 | Ordinary placement, consumed releases, repeated callbacks, movement/cancellation, next-touch recovery, Hand/Clue/Peek/Litmus preservation |
| MarkerInspectionLayoutTests | 2 | Production hosted UI on 375×667 and 402×874; all four corners; complete normal text; AX5 long explanations; visible Dismiss; unchanged cells, Hand and encoded game |
| PuzzlePageLayoutTests | 6 | Existing live page layouts, bosses, large scores and text sizes |

The recognizer tests invoke production coordinator callbacks with recognizer states. They are not a claim of physical touch-event arbitration or measured haptic feel. Layout tests host the production `GameplayShell`, `PuzzlePageView`, grid and popup and inspect the actual rendered views/OCR.

Final app snapshot: `/tmp/NumberClub-marker-inspection-build6.app`.
`ProbablySudoku.debug.dylib` SHA-256: `ca2677cbbc453818ef2288681314dce3fb7d551810c9ba3404963f617e9db65a`.

Relevant result bundles:

- Combined 87-test run: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_15-43-50-+0300.xcresult`.
- Final 25-test run: `/tmp/NumberClub-gameplay-redesign/Logs/Test/Test-ProbablySudoku-2026.09.19_15-54-55-+0300.xcresult`.
- Final screenshot attachments: `hosted-final/manifest.json`.

Build-for-testing and `git diff --check` passed. Existing SceneKit concurrency warnings outside this interaction were left unchanged.

## Native review and limits

Native captures are in `native/`; the independent review is in [native-review.md](native-review.md). The reviewer verified the final dismissal fix on SE at AX5 and iPhone 17 Pro, including popup-only accessibility focus, complete accessible text, and unchanged selected card/resources after dismissal. Root also verified a real coordinate tap placed a selected 2 once, while accessible Jade inspection and dismissal retained the same card and unchanged score/turn.

The reviewer found that AX5 dismissal required scrolling in the first version. The final build moves Dismiss outside the scrolling content, and hosted tests now assert its visibility both before and after scrolling.

The available native automation API has clicks and two-point drags, but no held-finger duration. A same-point drag behaved as an ordinary tap, so physical hold timing/release and the haptic sensation remain a manual-device check. Native scrolling returned a tool-level window-position error; hosted scrolling and complete accessibility text were verified. The native Reduce Motion setting was not toggled; the popup deliberately has no animation for either setting. These limitations do not replace the passing cancellation/consumption and layout tests.

## Save preservation

The user's main iPhone 17 Pro simulator received the final build. Its existing run and profile were backed up under `/tmp/NumberClub-marker-inspection-user-backup-20260919`; SHA-256 comparisons verified both files remained byte-identical after installation. Native QA used separate devices and non-saving fixtures. No historical rewards or save schema were changed by this interaction.
