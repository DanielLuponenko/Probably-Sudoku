# One active Book: independent native QA

## Baseline

Device: isolated Book Playtest A — iPhone 17 Pro, iOS 26.3 (`D04D3836`). User simulator 223A and physical devices are outside this audit. Original Application Support and Preferences (eight files) were backed up before launch to `/tmp/NumberClub-one-active-native-original-D04`, with SHA256 manifest.

Normal launch, without debug arguments, shows Play alone even though an unfinished Book is saved. The saved run is Volume 1, Obstacle I, Level 1, Puzzle 1, seed `39FA8`, five coins. There is no home Continue control (`baseline-home.png`).

Actual reproduction: Play → select first Book → Open the Book displays **Which copy stays open?** This is not the `-presentRunConflict` fixture: process 87250 launched without flags. The choices are local Book 1 versus another-device Book 6, both Level 1/Puzzle 1 (`baseline-copy-conflict.png`). The current RunStore gates both Open and Continue on any unequal local/remote decoded states.

Read-only, app-scoped inspection of the simulator's KVS cache confirms the second value: `sync.run.v1` holds Book `snackBreak` (Volume 6), seed `3HVVT`, Obstacle I, Level 1, slot 0, five coins. One discarded-run identity accompanies it. No KVS account association was present, but that alone is not treated as a guarantee that publishing is isolated. NumberClub's two cached KVS values were preserved as raw blobs plus hashes under the backup's `cloud-evidence` directory; no KVS database or remote value was modified. Persistent QA will use an explicitly isolated transport.

Opening the locked Obstacle II ribbon shows a separate details popup, while the existing chalkboard continues to show only `+1 HAND SIZE` (`baseline-obstacle-popup.png`).

## Revised-flow verification

Candidate: `/tmp/NumberClub-one-active-book-candidate-20260920-0017.app`. Every candidate launch used `-isolateCloudQA`, which disables all CloudSync run/profile/equipped reads and publications while preserving real app-local persistence. Normal lifecycle checks used no other launch flags.

- **Home Continue:** displays the actual title, Book and chapter, puzzle, coins, and (after play begins) Turn. See `final-home-continue.png`.
- **Exact existing Book:** Continue opened original seed `39FA8` at its saved briefing. Started the puzzle normally, selected a card, and used Toss. Closed the app with simctl terminate, relaunched, and selected Continue. All 91 projected gameplay AX records matched exactly: board, six remaining card UUIDs, coins, score, Turn, and three Tosses left.
- **Raw persistence:** after that action and resume, `run.json` was byte-identical, SHA256 `49afcb7f2fe984c535eb44e8d500101c2128a321b6da2ea414215d2bb014733b`.
- **Browse and cancel:** Play → choose Volume 2 → Open showed the current Book and explicit Continue current / Abandon & start new choices. Back to the shelf preserved the same raw save hash. See `final-replacement-choice.png`.
- **Continue from the decision:** returned to original Volume 1, again preserving all 91 gameplay records.
- **Accept replacement:** Abandon & start new opened Volume 2 (`slightlyHarder`), seed `24LIH`, Obstacle I, first briefing, with its correct 15 starting coins. Only `run.json` remained active; the old identity was in the discarded receipt and recovery backup. Replacement SHA256: `e675c65b04738c467c6d65300f7378f469bc8eeffd64299402d764ce47c984f3`.
- **Replacement survives relaunch:** the next normal isolated launch offered only Volume 2 in Continue, with correct chapter/puzzle/coins. See `final-replaced-home.png`.

Native terminal outcomes and deliberately repeated acceptance taps were not replayed in this bounded pass; the parent ran their focused storage/lifecycle gates. There is no Save & Exit control in this change: closure/relaunch was the requested route and was tested directly.

## Chalkboard review

Used `-isolateCloudQA -mainMenu -unlockAll` for an in-memory unlock fixture. Selecting II and IX updated the same chalkboard, without a popup; switching back to I removed the restrictions. Accessibility descriptions matched the selected obstacle and explained its complete effects. Actual frame capture shows the prior chalk erasing, a briefly empty plaque, and new lines writing in. The plaque and Book layout remain stationary.

**Readability issue found and fixed:** IX's two restriction rows were too small. Root agreed and assigned a focused sign layout refinement. The evidence below is explicitly from *before* that refinement:

- `pre-readability-fix-obstacle-II.png`
- `pre-readability-fix-obstacle-IX.png`
- `pre-readability-fix-obstacle-chalk.mp4` — trimmed native recording; uncut capture retained in `/tmp/NumberClub-one-active-native-observations/obstacle-chalk-uncut.mp4`.
- `pre-readability-fix-chalk-wipe-contact.png` — consecutive actual frames of II's erase/write transition.

### Final sign recheck

Installed `/tmp/NumberClub-one-active-book-final-20260920-0038.app` (debug dylib SHA256 `16dac052f2d3fedddaa9914e87f857c57c9f21f20a3b4aa044e0d32988c51733`) and launched with `-isolateCloudQA -mainMenu -unlockAll`. II and IX are now readable with complete wording. IX extends the plaque downward while retaining its top edge and width; it clears the Book and screen cutout. Returning to I restores its original height and benefit-only text.

Selected I → IX → II → I and captured actual motion frames. The chalk still wipes and writes, with the correct final text and no leftover restriction lines. Native checks used discrete selections, not a deliberately overlapping touch sequence; central animation cancellation tests cover that case.

- `final-obstacle-II.png`
- `final-obstacle-IX.png`
- `final-obstacle-I-restored.png`
- `final-chalk-motion.mp4` — ten-second excerpt of the final native transitions.
- `final-chalk-motion-contact.png` — actual transition frames.

## Restoration

Restored the isolated D04 app's original Application Support and Preferences offline. All eight original files matched the initial SHA256 manifest immediately and after reboot. Test state is retained in `/tmp/NumberClub-one-active-native-test-state-D04`.

Read-only KVS verification confirmed both original NumberClub cloud blobs **and their modification timestamps** were unchanged through the persistent tests and final sign recheck. The final sign session was also restored from the same original eight-file backup; its temporary state is retained under `/tmp/NumberClub-one-active-native-sign-test-state-D04`. No OS settings were changed. User simulator 223A and physical devices were untouched. Native review is complete and CUA is released to the parent.
