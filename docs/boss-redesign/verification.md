# Boss redesign verification — 20 September 2026

New Books use 22 encounters: 16 regular bosses and six finales. Historical Books retain their saved roster version, announced boss and earned results. The 20 encounters retired from new selection remain available for loading historical saves and for QA.

## Implementation

- Added Collateral, Split Edition and Last Edition with saved, engine-owned choices. Pledge identity, two independent score ledgers, and the one-bank limit do not depend on animation completion.
- Added an envelope and wax seal, selectable edition stacks, and a single-sheet printing press. Strengthened the Accountant, Mirror, Royalty Contract, Executive Editor, Bindery and Publicist feedback.
- New selection avoids repeats and consecutive mechanical families when eligible alternatives exist. Inventory-dependent bosses require relevant owned items; an announced encounter stays fixed through Shop changes and resume.
- Split Edition results show both ledgers and name any unfinished edition. Review Board results identify missing approvals. Small-screen titles, locked-control contrast, full target values, independent accessibility controls and the final printed score were checked and corrected.

## Verification evidence

- Full engine gate: **499 tests passed, zero failures**, including 4,536 Book × boss × obstacle combinations and all 18 ordinary skips across nine chapters. Log: `/tmp/nc-boss-roster-engine-clean.log`. A further historical-format test removes the newly introduced nested encounter state and preserves all 39 original boss identities.
- App integration gate: 119 cases, zero failures, one intentional opt-in recording skip. Includes saved choices, stale callbacks, selected card identity, hand/Clue behavior, score presentation, final routing, persistence and the new failure explanations. Result: `/tmp/NumberClub-boss-roster-final-20260920.xcresult`.
- The roster capture tests render the actual production views at 375 × 667 and 402 × 874 points, plus committed choices and Accessibility 3. Capture rendering is checked not to mutate the saved game. Images are in `docs/qa/boss-redesign/screenshots`.
- Final motion/render gate: all 22 active bosses recorded with real production actions; ten tests passed. `/tmp/NumberClub-boss-animation-rosterverified-20260920.xcresult`. Split's two 300-point QA targets illustrate allocation; this clip does not claim a completed encounter. Last Edition's 400-point QA target illustrates its one-bank win.
- Hosted failure gate: four tests passed, including complete production result screens at both iPhone sizes. OCR confirms the two ledgers, unfinished-edition explanation and New book decision are visible; UIKit confirms no vertical scroll overflow at normal text size. `/tmp/NumberClub-boss-failure-hosted-20260920.xcresult`.
- Manual simulator interaction confirms separate accessibility buttons for A/B, preserved selected card, locking after a correct placement, and a 20-point bank sent only to B. Collateral was exercised with duplicate 1 tiles; the pledged UUID returned exactly once while the other copy remained distinct.
- The normal Last Edition flow was also played outside the recording host: its sole bank transitions to Book over when insufficient, with New book and no second-bank/rescue offer. The gallery's stationary terminal gameplay tail is explicitly identified as a showcase-host limitation.
- Independent engine review tests cover exact pledged-card identity, duplicate choices, invalid actions, pending decisions, saved/restored encounters and Last Edition bypass paths.
- The finite-resource balance probe covers six finales, three seeds and four specified builds: 72 encounters. See `final-balance.md`, `.csv` and `.json`. Three developed builds can clear each finale; the basic build cannot. Last Edition's target was raised from one eighth to one quarter after the initial probe.

## Interpretation

Balance probes use solution-assisted placements and catalogue items with documented prices and earned growth. They demonstrate attainable outcomes and resource conservation, not human win rates or universal build viability. Animation recordings use disclosed deterministic QA boards and production actions; the short Split/Last recordings use reduced QA targets. Real chapter-nine targets are exercised in the separate balance probes.

Independent reviewers inspected the roster code, actual captured small/regular-screen states, and action frames from the final recordings. The existing local work and historical simulator saves are preserved; no reset, clean or destructive checkout was used.

The final build is installed on the normal iPhone 17 Pro simulator. `run.json`, `profile.json` and `discarded-runs.json` are byte-identical to their backup after installation and launch. Backup manifest: `/tmp/nc-boss-roster-user-backup.json`. The separate Book Playtest A session was not replaced or restarted.
