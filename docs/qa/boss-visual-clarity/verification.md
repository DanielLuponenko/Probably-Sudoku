# Boss visual clarity verification — 20 September 2026

Implemented a presentation pass for 15 bosses, centered on Galley Queue, Bookends, Reprint Ban and Chain Stitcher. The separate audit covers all 39 bosses and explicitly identifies proposals that remain unimplemented. Gameplay rules, scoring transactions and random-number streams were not changed by this presentation pass.

## Validation

- Simulator build succeeded after the final Chain animation lifecycle fix (`/tmp/nc-boss-clarity-build4.log`).
- Focused regression gate: 95 tests executed, 94 passed, one opt-in recording skipped, zero failures. Covers boss state, exact Hand identities, arrangement, Clues, geometry and scoring-source presentation. Result: `/tmp/NumberClub-boss-clarity-20260920.xcresult`.
- Updated visual and recording gate: 14 tests passed, zero failures. Includes 30 production-view captures at 375×667 and 402×874, state/score projection checks and all 15 updated recordings. Result: `/tmp/NumberClub-boss-animation-clarity-20260920.xcresult`.
- After the final animation lifecycle fix, the four-boss recording test passed again. Result: `/tmp/NumberClub-boss-animation-clarity-final-20260920.xcresult`. These final four clips replaced their earlier versions.
- Independent review found two issues during development: queue selection looked too similar to its playable treatment; Chain guidance resembled ordinary matching-number highlights. A separate dark selection ring and gold scoring wells resolved them. The reviewer checked the final recordings and confirmed both fixes.
- Independent frame inspection confirmed a visible gold linked stitch at 5.47–6.05 seconds, gone by 6.30 seconds; a broken red stitch and half-points label at 8.62–9.20 seconds, gone by 9.50 seconds. Evidence: `final-chain-linked.png`, `final-chain-broken.png`, `final-chain-settled.png`.
- Reprint's other duplicate becomes USED after the actual correct fill and returns to PLAY after the committed turn boundary. Bookends highlights both separate copies of the lowest digit and the actual highest digit. Queue eligibility continues to follow arrival identity after sorting.
- Chain highlights derive only from the public anchor, board availability and Passage exception, never the solution. Clues/wrong attempts do not move the anchor. Status diagrams compare actual pending score-ledger values and do not mutate saved gameplay.
- The final gallery retains all 39 working clips, with 15 refreshed clips and descriptions. Browser verification confirmed the refreshed content and playable review controls. Video/poster URLs include recording timestamps to prevent stale cached media.
- `git diff --check` passed.

## Installation and rollback

Final build installed and launched on the normal **iPhone 17 Pro** simulator (`223A4227-A28E-4939-BB5E-3AAB820EB635`). All 15 backed-up save/preferences files were byte-identical after installation. Run, profile and discarded-run records remained byte-identical after normal launch. `installation.json` contains hashes and the backup path.

The separate Book Playtest A simulator was not restarted. Gallery rollback evidence remains in `/tmp/NumberClub-boss-clarity-gallery-before-20260920-112935`.

Recordings use deterministic QA fixtures hosted in production iOS views and real accepted game actions. They demonstrate the transitions; they are not recordings of completing every boss encounter. Extra motion honors the in-game Reduced Motion preference and pauses while covered or inactive.
