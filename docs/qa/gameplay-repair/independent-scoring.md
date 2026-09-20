# Independent scoring review

Reviewer: a separate scoring QA agent, 19 September 2026. This is independent arithmetic and source review; actual Simulator QA-menu playtesting is **pending** until exclusive Simulator ownership is assigned. Automated Engine results do not prove touch interaction or animation appearance.

## Method

Read the accepted gameplay-repair prompt, the version-2 scoring specification, the production scoring/placement/banking/save paths, the catalogue, and the app's ledger projection. Added a separate `IndependentOrderedScoringTests.swift` file. Fixtures construct a known Latin Sudoku; expected totals are written constants and never computed from production scoring helpers. Production placement, Buff use, End Turn, sale, reorder, cash-out, Shop navigation and JSON save/resume are exercised after fixture arrangement. Random streams are not used to manufacture expected arithmetic.

Command: `swift test --package-path Engine --scratch-path /tmp/nc-independent-score-build --filter IndependentOrderedScoringTests`. The separate scratch directory avoids interfering with the implementation agent's full Engine gate.

## Arithmetic cases

| Case | Independent expectation | Current result |
|---|---|---|
| Final Clue or censored eight, all event Points zero, Morning Edition, target 100 | Last card still ends Turn; +100 direct payout wins | Pass after repair |
| Five + Gossip + Crane, Crimson, Double Down, Op-Ed then Stop | `(50+30+50)×4×2 = 1,040` Points; ×6 banks 6,240; coins unchanged | Pass |
| Last eight clears row/column/box/full board, Sports, Society, Extra, Finance, Emerald, Second Print, Op-Ed | Event Points `[80,840,420,420,3000]`; 4,760×2 = 9,520; exactly 3 coins | Pass |
| Sleeping duplicate Op-Ed, Stop, active Op-Ed; reorder/sell/save/resume | Exact sleeping UUID remains excluded; locked current Turn remains 50×4 = 200 | Pass |
| Mirror with Double Down/Second Print and Finance | Eight scores 160, unit clears score zero, full board 500; 660 total, 3 coins; Second Print remains armed | Pass |
| Rolling Presses, one clear followed by three clears | First batch 95×1; next 215×2.5 floors to 537; preview cannot grow state | Pass |
| Historical missing-version save, reversed Stop/Op-Ed, existing queue 40 | Continue v1: (40+50)×6 = 540; next Turn v2 four scores 40×4 = 160; old coins/Clipping unchanged | Pass |
| Banked score ten below 9e15, 50 Points, Stop and Morning | Actual new bank delta 10; direct payout saturates; resume cannot replay it | Pass |
| Finite JSON saved Crane modifier 1e20 | Safe conversion, capped 9e15 award and encodable ledger | Pass after repair |
| Bird Seed consumed copy, three clears, next Puzzle, save/resume, three clears | All six coin operations retain the consumed UUID; exactly three new coins on second board | Pass after encoder repair |

The first eight tests passed. The expanded ten-case run produced one genuine failure: Bird Seed provenance disappeared after save/resume. Original failure evidence is retained at `/tmp/nc-independent-scoring-bird-seed-failure.log`. After the explicit encoder repair, **all 10 independent tests pass** in `/tmp/nc-independent-scoring-final.log` (2026-09-19 01:30:05).

## Findings sent to implementation

1. **Final zero-point card could fail before End Turn.** `resolveCorrect` called `updatePhase` with zero queued Points, marking the full board failed before the automatic bank. Morning/Evening direct payouts were skipped. The implementation agent deferred that decision to the actual Turn boundary and aligned legacy direct-Clue final-card behavior. Source diagnosis was confirmed; the fix landed before this agent's first compile, so there is no claimed executed pre-fix failure. The independent Clue and Censor regression passes.
2. **Large saved Paper Crane modifier could trap before bounding.** Direct `Int(Double)` conversion preceded the promised score bounds. Replaced by bounded conversion; the independent finite 1e20 saved-input regression passes and its ledger round-trips.
3. **Bird Seed operation lacked exact consumed-copy identity across Puzzles.** A Run-level source identity was added. The independent test then exposed an omitted explicit encoder field: decode and CodingKeys were present, but `RunState.encode(to:)` did not write it. That executed failure is preserved above; the repaired across-Puzzle save/resume regression now passes.
4. **Bank animation HUD uses the next Turn's reset values.** Source review found banking presentation has no initial queued snapshot or presented Mult. The HUD read the already-reset Puzzle, displaying `Queued 0 × 1` while ordered multiplier beats played; automatic banking could briefly combine old queued Points with reset Mult 1. The implementation agent added ledger-owned presentation values and a model regression; root is updating the HUD binding. Runtime visual verification and app gate are pending.
5. **Direct-payout animation preceded its product bank.** The banking projection filtered Mult and direct payouts, then appended a combined BANKED stamp, although the engine ledger explicitly banks the product before applying Morning/Evening. Sent to implementation for ordered bank/direct score snapshots. The full detail ledger was already in correct order. App regression and runtime verification are pending.

## Catalogue and design audit

All 23 Bookmarks, 12 Markers, 11 Buffs and 19 bosses have entries in the scoring specification. The mapping correctly separates placement/clear Points, ordered held Mult, direct payouts and coins. Extra! Extra! affects full-board and unit-clear Points; Emerald affects only unit clears. Onyx restores placement Points only. Score doublers preserve one hook invocation, which the simultaneous-clear fixtures verify through coin counts. Rolling growth and v1 continuation are tested with independently written intermediate values. The balance report is appropriately labelled a perfect-placement single-Turn ceiling; it is not evidence of normal human win rate or Shop acquisition balance.

## Pending manual evidence

The catalogue picker replaces one slot per kind, so root authorized five bounded Debug-only fixtures. `QAScoringFixtures.swift` and a QA-menu section now arrange a known Latin board for Op-Ed/Stop order, simultaneous row-and-box clear with Second Print, final zero-score Clue with Morning, Turn-10 Morning/Evening direct payouts, and eight-then-wrong-one penalty. All start with zero banked and queued score, no effect fired, conserved cards and owned Buffs. Fixture preparation tests check those conditions. The final-Clue fixture requires activating the actual Peek item before selecting the eight; it does not pre-reveal the square. Fixtures disable progress saving before state replacement to preserve the user's stored Book. The tester still must trigger all effects with actual inventory, hand, board and End Turn controls. No Simulator interaction has been performed by this reviewer yet.
