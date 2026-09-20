# Live gain and modifier feedback — 19 September 2026

The production score header leads with the exact pending gain and keeps Points × Mult smaller beside it. Empty turns leave the secondary row blank; Keep Filling says “Score frozen.” The existing HUD allocation and board geometry are unchanged. Tapping the score retains the detailed engine-authored breakdown.

One brief source label explains each actual modifier. Crimson's local placement Points multiplier, additive Mult, and multiplicative Mult are distinguished. The matching visible marker square or exact Bookmark copy gets a restrained outline. Consuming Fresh Ink leaves the Buff inventory normally; only an empty former slot can pulse, so an item sliding into that slot is never identified as the consumed copy.

End Turn moves a visual copy of the last visible gain into the banked score. The flight retains its original frame and font instead of measuring the hidden zero that replaces it. These effects do not score, draw, consume, mutate saves, or rerun engine hooks. Performance IDs guard delayed callbacks. New Buff feedback waits until its closing panel uncovers the board. Covering ongoing playback or leaving the app cancels it. Reduce Motion retains readable receipts and steady outlines without the flight.

Fog conceals marker feedback and marker rows in the displayed score breakdown, while preserving the engine and saved ledger. VoiceOver's score action explicitly excludes the hidden empty-turn calculation. Longer accessibility receipts receive two lines within the existing accessibility HUD band.

## Verification

- Initial integration: 62 tests passed for score presentation, production HUD rendering, scoring fixtures, gameplay geometry, hand arrangement and Clue controls. Log: `/tmp/nc-score-modifiers-test1.log`.
- Expanded verification: 37 tests passed for score presentation, hidden/large/accessibility HUD states, source matching, marker gestures and fixed board geometry across phone/iPad sizes. Log: `/tmp/nc-score-modifiers-test3.log`.
- Corrected playback build: 30 tests passed, including the hosted view test proving Fresh Ink waits while covered and cannot replay after cancellation. Log: `/tmp/nc-score-modifiers-test5.log`.
- Final source identity check: all 5 source-highlight tests passed after preventing a surviving Buff from being highlighted when it slides into a consumed copy's slot. Log: `/tmp/nc-score-modifiers-test6.log`.
- Final HUD build: all 8 render tests passed, including a positional regression proving the main score stays still when source feedback appears/disappears and every line stays inside the fixed score band. Log: `/tmp/nc-score-modifiers-test8.log`.
- The QA fixture “Crimson, Bookmarks and Fresh Ink” uses normal gameplay actions: correct 4 at R1C4 gives 160 × 6 = 960; using Fresh Ink gives 160 × 12 = 1,920; End Turn banks 1,920. The fixture also tests conservation and save/resume.
- Final independent native iPhone 17 Pro and iPhone SE playtesting verified that sequence, empty Buff inventory after use, stable board and score positions, and opening/dismissing the detailed ledger without extra awards. The complete SE board, hand, controls and turn line fit without scrolling. Empty calculations are absent visually and from VoiceOver; the score retains its Button role. The final video confirms the gain stays fully on-screen and Fresh Ink feedback appears after its panel closes. See `independent-review.md` and `17pro-final-bank-contact.png`.

Across the focused suites, 82 distinct tests passed. The final app is `/tmp/NumberClub-score-modifiers-build3.app`, installed and launched on the user's iPhone 17 Pro simulator. All five Application Support files matched the fresh pre-install backup byte for byte before launch: `/tmp/NumberClub-score-modifiers-user-backup-20260919-final`.

No engine scoring rules or save schema changed for this implementation.
