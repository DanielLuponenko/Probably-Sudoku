# Inventory, effects and boss playtest

Status: **72/72 catalogue smoke scenarios completed** using public QA setup and actual player controls on the SE Simulator. This includes 11 Buffs, 23 Bookmarks, 12 Markers, 19 bosses and 7 historical Subscriptions. The Paywall and The Fine Print cases explicitly reuse the independent [Flow/Clue playtest](flow-clue-playtest.md); the other 70 items were exercised during this sweep. Probability, persistence and arbitrary drag paths have separate evidence and limitations below.

## Environment and method

- Device: SE-test, `60D48736-12BA-4D48-ADCB-DC2DBB834730`, iOS 26.3. Builds 14–16 were installed during the sweep. Build 15 fixed the stale accessibility reorder actions found here; build 16 retained precise fractional Mult text. Build 18's Shredder visual correction awaits independent review.
- The original SE backup at `/tmp/nc-clue-qa-original-20260919-013540` was preserved. The user's large-phone device/save (`C4A89359-C3E2-4CFD-B6B3-F5D13242807D`) was not touched.
- QA menus only arranged state. Real inventory panels, Hand selection, board cells, Toss, End Turn, Cash Out, Shop purchase/reroll and accessibility actions triggered effects. QA fixtures are ephemeral and do not replace the normal saved run.
- Fixture seed: `QA-ORDERED-SCORING-V2`. The Latin Sudoku solution begins with row 1 = 1–9; row offsets are 0, 3, 6, 1, 4, 7, 2, 5, 8. The ordinary fixture has no boss difficulty. The genuine boss checks instead resumed normal seed `6C4C3`, pressed Play on its mandatory boss briefing, and solved placements from visible givens.
- QA Bookmark/Boss/Subscription selections refresh normal limits and refill the Hand. This can restore the fixture target to 1,000. Numeric expectations below use the actual displayed state, not an assumed untouched fixture. Marker/Buff selections preserve the arranged board.
- Every action used a fresh accessibility state before the next decision. QA catalogue scrolling used the exposed `Scroll Down` accessibility action because native CUA drag/scroll delivery did not move Simulator lists.

## Reusable setups

| Fixture | Arranged state and baseline |
| --- | --- |
| `ordered` | Empty Latin board, Hand 5,5,9, Op-Ed then Stop, no Buffs. Correct 5 at R1C5 queues 50 × 6. Reversed before scoring gives 50 × 4. |
| `simultaneousClears` | 5 at R1C5 completes row 1 and box 2. Hand 5,9; Finance and Crossword; Second Print held but inactive. Baseline 140 Points, +2 coins, +2 drawn cards. |
| `finalClue` | Only R9C9 is blank, held 8, Morning and Peek, target 100. Ordinary final 8 gives 815 including Morning. Pure Peek's final 100 is a separate Flow scoring case; this sweep exercised Onyx + Peek = 180. |
| `tenthTurn` | Turn 10, blank board, Hand 5,9; Morning, Evening, Op-Ed, Stop. Combined direct-payout arithmetic is covered by the separate scoring playtest. |
| `penalty` | Blank board, held 8,1,9; Stop and Insurance. Correct 8 at R1C8 then wrong 1 at R1C2. |
| `duplicateInventory` | Blank board, held 5,5,9; Op-Ed then Stop; two separately owned Peek copies. Sale refunds: Peek 1, Op-Ed 2, Stop 4. |

## Buffs — 11/11

All were activated through their real custom paper panels. Unmentioned score, coin and Toss budgets stayed unchanged.

| Buff | Actual trigger | Observed result |
| --- | --- | --- |
| Peek | Final Clue + Onyx: Choose Number → held 8 → R9C9 hint → placement. | Passed: Peek consumed at reveal; placement 80, clear/full bonuses 0, Morning +100; final bank 180. Flow also covers ordinary reveal/cancel/restart. Pure final Peek 100 is separate S12 evidence, not claimed here. |
| Redraw | Ordered; Use. | Passed: original three held copies replaced by seven fresh UUIDs; Toss 4, score 0, coins 5; one Buff consumed. |
| Overtime | Ordered; Use. | Passed: Turn 1/10 → 1/12, same three cards, one Buff consumed. |
| Double Down | Ordered; Use; 5 at R1C5 then second 5 at R2C2; End Turn. | Passed: queue 100 then 150, Mult 6, bank 900. Second placement was not doubled. |
| Insurance | Penalty; Use; correct 8 then wrong 1; End Turn. | Passed: wrong card removed, queue stayed 80 × 3, bank 240. One protection consumed. |
| Second Print | Simultaneous; Use; 5 at R1C5; End Turn. | Passed: 185 Points, coins 5→7, Hand 2→3. Bank 185; no repeated coin/draw grant. |
| Lucky Dip | Ordered; Use. | Passed: three original UUIDs retained, two new distinct 3 cards added; Hand 5, Toss 4. |
| Bird Seed | Simultaneous; replace Buff; Use; 5 at R1C5. | Passed: 140 Points, coins 5→9 (+2 Finance, +2 Bird), two draws. |
| Fresh Ink | Ordered; Use; 5 at R1C5; End Turn. | Passed: 50 × 12 = 600. Next Turn empty queue has seed Mult 3, preserving +2. |
| Litmus | Ordered; Use; select 5; inspect R1C4/R1C5, then place R1C5. | Passed: wrong square red × / AX mismatch; correct square green check / AX match. Placement queued 50 × 6 and removed cues; copy consumed. |
| Paper Crane | Ordered; choose 5 then Keep It; reopen, choose 5, Use; place both 5 s. | Passed: cancellation retained copy. Real activation consumed it; matching placements queued 100 then 200 Points, proving persistent +50 each. |

## Bookmarks — 23/23

All custom Bookmark detail panels were opened.

| Bookmark | Actual trigger | Observed result |
| --- | --- | --- |
| Morning Edition | Ordered; select through QA, open details, empty End Turn. | Passed: direct bank +100. Also observed after Onyx/Silver final placements. |
| Evening Edition | Tenth Turn; replace Bookmark; open details; empty End Turn. | Passed: bank 300. QA restored target 1,000, so the resulting Failure was correct. |
| Local Gossip | Ordered; replace Bookmark; open details; 5 at R1C5. | Passed: 80 Points (50 + 30). |
| Sports Section | Simultaneous; replace Bookmark; open details; 5 at R1C5. | Passed: 190 Points (50 + 70 + 70). |
| Society Pages | Final Clue; replace Bookmark; open details; ordinary 8 at R9C9. | Passed: real full-board bank 1,215 (80 + 135 + 1,000); Results showed Board complete. |
| Op-Ed Column | Ordered inventory order tests; custom details opened. | Passed: +1 applies before/after Stop according to visible order; real banks 300 and 200. Locked batch stayed 300 after reorder. |
| Editorial Board | Ordered; replace Bookmark; details; 5; End Turn. | Passed: 50 × 3 = 150. |
| Front Page Splash | Ordered; only this Bookmark; details; 5; End Turn. | Passed: one owned Bookmark gave Mult 2, bank 100. |
| Letters to the Editor | Ordinary fixture and genuine seed `6C4C3` boss; details opened. | Passed: ordinary 5 queued 50 × 1. True boss held 1 at R2C4 queued 10 × 4 and banked 40. |
| Rolling Presses | Simultaneous; replace Bookmark; details; 5 then 9 at R3C3; End Turn. | Passed: first dual clear queued 140 × 1.5; later placement used grown factor, 230 × 2; bank 460. |
| Syndication | Ordered; details; 5/End Turn; QA Meet Target; real Cash Out → Shop → Continue → Play. | Passed: initial 50 × 1. On next normal puzzle, solved 6 at R1C2 from visible givens and queued 60 × 1.25. Ownership survived progression. |
| Stop the Presses | Ordered inventory order tests; custom details opened. | Passed: ×3 applied at visible slot; actual banks 300/200 and locked-order transition demonstrated both factors. |
| The Sunday Supplement | Ordinary fixture and genuine seed `6C4C3` boss; details opened. | Passed: ordinary 5 queued 50 × 2. True boss 8 at R2C9 queued 80 × 3; score 40→280, Turn 3. |
| Extra! Extra! | Simultaneous; replace Bookmark; details; 5 at R1C5. | Passed: 320 Points (50 + 135 + 135). |
| Finance Pages | Simultaneous fixture across Buff/Marker cases; custom details opened. | Passed: two actual clear events repeatedly paid exactly +2 coins. Bird/Copper/Azure additional coins were separately visible. |
| Paper Route | Ordered; details; QA Meet Target; real Cash Out. | Passed: payout 17 = base 5 + unused 10 + Paper Route 2; coins 5→22 once. |
| Market Wrap | Ordered; details; QA +1000 coins and Meet Target; real Cash Out. | Passed: balance 1,005, payout 30 includes Interest 15; final balance 1,035. |
| Auction Notices | Ordered; details; arrange Results; Cash Out; two real rerolls. | Passed: free first reroll changed stock with 20 coins unchanged; next cost 2 changed balance 20→18; next displayed cost 3. |
| Help Wanted | Ordered; details; real Toss. | Passed: starting Hand 8 (baseline 7 +1); selected copy removed, Hand 7, Toss 4→3. |
| Weather Forecast | Ordered; details; real Toss. | Passed: allowance 6→5, exact selected copy removed. |
| Puzzle Corner | Ordered; details; top Clue resource → held 5 → hinted R1C5. | Passed: resource 1 consumed at reveal, real placement 0 Points; no Buff slot used. Flow separately proves stored Clue under Fine Print. |
| Late City Final | Ordered; details; End Turn. | Passed: Turn 2/11, advancing exactly once. |
| Crossword Daily | Simultaneous fixture across Buff/Marker cases; details opened. | Passed: Hand 2→3 from −1 played +2 distinct draws. Sapphire independently added a third draw. |

## Markers — 12/12

All Markers selected through QA at the first blank, followed by real Hand/cell input.

| Marker | Actual trigger | Observed result |
| --- | --- | --- |
| Crimson | Simultaneous; 5 at marked R1C5. | Passed: 290 Points; +2 Finance coins. |
| Golden | Same. | Passed: 240 Points; +2 Finance coins. Fog also preserved this hidden effect. |
| Azure | Same. | Passed: 140 Points; +3 coins total (1 placement +2 Finance). |
| Ivory | Simultaneous; wrong 9 then correct 5 at marked R1C5. | Passed: wrong 9 left Hand with no penalty; correct 5 remained and scored 140/+2 coins. |
| Emerald | Simultaneous; correct 5 at R1C5. | Passed: 230 Points (50 +90 +90), +2 coins. |
| Onyx | Final Clue; Peek reveal then 8 at marked R9C9. | Passed: 80 placement Points, zero clear/full bonuses, Morning 100; final 180. |
| Silver | Final Clue; ordinary 8 at marked R9C9. | Passed: final 975 =80 +160 from prior copies +135 +500 +100 Morning. |
| Sapphire | Simultaneous; correct 5. | Passed: 140 Points, Hand 2→4 (−1 play +1 Marker +2 Crossword). |
| Rose | Simultaneous; correct 5; End Turn. | Passed: 140 ×2 =280; next Turn seed 2 persisted. |
| Copper | Simultaneous; correct 5. | Passed: 140 Points; coins 5→13 (+6 Marker +2 Finance). |
| Violet | Simultaneous; correct 5. | Passed: 180 Points (90 placement +45 +45). |
| Jade | Simultaneous; wrong 9 at marked R1C5; open preview receipt. | Passed: same held 9 UUID 08023EDE-050F-499C-AA63-D4385ACAC3E5 retained. Receipt −450, queued/banked 0→0 due to floor. No duplicate or disappearance. |

## Bosses — 19/19

Seventeen cases exercised here; two explicitly attributed to Flow. Force Boss tests rules on a valid fixture, while true boss difficulty and mandatory routing were tested separately.

| Boss | Actual trigger | Observed result |
| --- | --- | --- |
| The Censor | Ordered; Force Boss; rule chose digit 5; place 5 then 9. | Passed: censored 5 queued 0; other 9 queued 90, with normal Mult 6. |
| The Editor | Ordered; Force; Toss one card; End Turn. | Passed: starting/refilled Hand 6, baseline 7−1. |
| The Deadline | Ordered; Force; End Turn. | Passed: Turn 2/8. |
| The Fog | Simultaneous; Golden Marker; Force; inspect then place 5. | Passed: Marker absent visually and from cell AX; actual 240 Points, +2 coins. |
| The Critic | Penalty; Force; leave Insurance unused; correct 8 then wrong 1. | Passed: receipt −100; queue 80→0, bank 0 floor. Unused Insurance remained held. |
| The Mirror | Simultaneous; Force; correct 5. | Passed: placement 50, both clear Points 0; Finance+2 coins and Crossword+2 draws still occurred. |
| The Paywall | Independent Flow/Clue report, exact blocked Peek scenario. | Passed by Flow: use/reveal blocked with explanation, copy retained; no charge consumed. See linked report; not relabelled as this tester’s touch. |
| The Erratum | Ordered; Force; select card, inspect Toss; End Turn. | Passed: Toss disabled 0, rule shown; End Turn 2/10. |
| The Collector | Ordered; Force; QA balance 1005/result; actual Cash Out. | Passed: payout 15 with no Interest; balance 1020. |
| The Final Draft | Ordered; Force; correct 5; End Turn. | Passed: target 4000 (normal 1000 ×4); bank 300; Turn 2. |
| The Executive Editor | Ordered; Force; Op-Ed asleep; move Stop earlier; correct 5; End Turn. | Passed: Op-Ed stayed asleep in new slot 2, queue 50×3/bank 150; next Turn selected Stop asleep, Op-Ed active. |
| The Fine Print | Independent Flow/Clue report, exact blocked Buff and stored Clue scenarios. | Passed by Flow: Peek use blocked and copy retained; separate Puzzle Corner stored Clue worked. See linked report. |
| The Budget Cut | Ordered; Force; correct 5; End Turn. | Passed: final Mult 3 = (1+1)×3×0.5; bank 150. Empty next Turn seed 0.5. |
| The Shredder | Ordered; Force; blocked R5C1 tap, legal 5 at R1C5; two End Turns. | Passed gameplay: blocked tap retained selected card and 0 queue; legal 5 bank 300. Initial R5C1/R5C4 expired by Turn 3; new blocks appeared. Separate visual defect below. |
| Natural Born Accountant | Ordered; Force; correct 5 then wrong 9. | Passed: coins 5→4→3, one debit per attempt; normal score/penalty remained separate. |
| Tik Tak | Ordered; Force; active time, Run Info overlay, resume 5/End Turn. | Passed smoke: active 237→227 seconds; overlay open >20 s, close 221 (transition time only); input then End Turn showed 200, bank 300, Turn 2. No reset. This is not a stopwatch-precision test. |
| Handy Dandy | Duplicate fixture; Force; ascending sort; blocked 3 then allowed 3 Toss. | Passed: barred 9 UUID 0FB8… and barred 3 UUID 6ACB… survived sort; selecting barred 3 disabled Toss. Different 3 UUID 568C… tossed, allowance 4→3, barred copies retained. |
| Gray the Garry | Ordered; Force; blocked row tap, Run Info, End Turn, legal 5. | Passed: nine R5 cells disabled; overlay preserved same row; End Turn changed to R4; legal 5 at R1C5 queued 50×6. |
| Garry the Gray | Ordered; Force; blocked box tap, Run Info, legal 5, End Turn. | Passed: central R4–6/C4–6 redclay cells blocked; overlay stable; allowed 5 queued 50×6/bank 300; next box R4–6/C1–3. |

## Subscriptions — 7/7

These are historical/QA items; they are intentionally absent from normal Shop sales.

| Subscription | Actual trigger | Observed result |
| --- | --- | --- |
| Home Delivery | QA select; Run Info; Toss/End Turn. | Passed: ownership and +1 description shown; starting/refilled Hand 8, no held inventory slot used. |
| Weekend Edition | QA select; End Turn; Run Info. | Passed: Turn 2/11 and ownership/+1 Turn description. |
| Wire Service | QA select; actual Toss; Run Info. | Passed: allowance 6→5 and ownership shown. |
| Clipping Service | QA select; arrange Results; actual Cash Out and Continue. | Passed: six Shop offers, including Lucky Dip and Insurance as two Buff offers. Ownership shown; Continue reached round 2 briefing. |
| Trade Journal | QA select; Run Info; actual Cash Out; Shop Run Info. | Passed UI smoke: ownership/effect retained, five valid Shop offers generated. Probability established separately by deterministic test below, not one observed roll. |
| Annual Rate | QA select; Run Info; arrange 1,005 balance/result; actual Cash Out. | Passed: cap 20 description; payout 35 includes Interest 20; balance 1005→1040. |
| Overseas Edition | QA select; Run Info; actual Onyx purchase/place R1C5. | Passed legacy/no-active-effect case: truthful unlimited-storage copy shown; no replacement reward. Buy 20→13 coins, one Onyx Marker placed; historical subscription ownership retained. |

## Inventory and cross-screen checks

| Scenario | Result and limits |
| --- | --- |
| Before-score reorder | Passed custom paper controls: Move Op-Ed later produced Stop→Op-Ed; real 5/End Turn bank 200. Named accessibility reorder also restored the original order successfully on build 15. |
| Locked reorder | Passed: first 5 queued 50×6; Stop moved first with explicit next-Turn notice; current bank 300. Next 5 at R2C2 queued 50×4, cumulative bank 500. |
| Bookmark sale | Passed custom paper Sell: Op-Ed paid 2 once, leaving Stop/Peek and board/score 500 unchanged. |
| Duplicate Buff sale | Passed named accessible Sell: two Peek copies→one, coins 5→6; other inventory, board and Hand unchanged. Exact UUID safety is additionally covered by automated identity tests; touch AX does not expose owned Buff UUIDs. |
| Full Buff inventory in Shop | Passed: two Peeks, 20 coins. Lucky Dip detail said no open slot and disabled Buy. Attempting disabled action then Close kept both copies and 20 coins. Explicit sale paid 1; real Lucky Dip purchase cost 3; final Peek+Lucky Dip exactly 2, 18 coins, offer sold. |
| Full skip inventory | Passed by independent Flow: Cancel and pending-panel restart preserved exact save; replacing chosen UUID advanced once, one history entry, two items, unchanged coins. See Flow snapshots. |
| Buff cancellation | Passed Paper Crane number choice then Keep It retained copy. Flow separately verifies pending Peek and skip replacement cancellation. |
| Navigation/overlays | Inventory, boss bars and active effects remained stable across custom panels, Results, Shop and briefing. Fresh Ink and Syndication persistence across Turns/progression demonstrated above. Active pointer-drag interruption remains tool-blocked; automated session cancellation tests cover the model/presenter. |
| Cross-screen appearance | Visually reviewed gameplay, actual full-board Results, Failure, Shop and normal briefing on SE. Shared compact inventory, paper background, no former book edges/tails; decision footers remained visible. Large text/iPad/Reduce Motion belong to root/reviewer geometry and accessibility coverage, not a pass claimed from this SE sweep. |
| Freeform/diagonal/curved drag | **Live test blocked by CUA delivery.** See independent control below. Automated changing-direction geometry evidence is separate and is not labelled live proof. |

## Findings and verification

1. **Stale accessible reorder directions, fixed and retested.** Build 14 changed row order and position labels, but retained earlier custom actions: Stop in slot 1 incorrectly offered Move Earlier; invocation was a harmless no-op. Its custom paper panel correctly offered Move Later. Root keyed the action subtree to slot/count while retaining item UUID ownership. Build 15 exact repro passed: Stop in slot 1 offered Later, Op-Ed in slot 2 offered Earlier; invoking Stop Later restored original order. Build 16 Executive reordering also retained correct actions.
2. **Overseas Edition misleading benefit, fixed and retested.** Storage was already unlimited but copy promised a finite-capacity upgrade. Root authorized a copy-only clarification: “Legacy subscription. Marker storage is now unlimited.” Build 16 QA and Run Info showed this text, a normal Marker purchase worked, and no old reward/state/currency was converted. Existing deterministic ownership/capacity tests supplement this visible smoke.
3. **Shredder perimeter ticks, confirmed clarity defect, correction pending independent live recheck.** Settled screenshot `se-shredder-top-edge-artifact.png` shows faint V marks inside first-row wells, before input and after two Turns. Root traced them to deliberate perimeter art and the independent reviewer confirmed they were confusing. Build 18 suppresses only that gameplay vignette, retaining actual fouled-cell blots, rule text and route art. This sweep remained on build 16 after the finding; do not mark 18's visual recheck completed here.

Trade Journal odds are proven by `ShopTests.testTradeJournalMovesRarityBoundariesByTenPercentagePointsWithoutExtraRandomDraws`: 72 fixed boundary cases across chapters 1–9, actual owned subscription→stock, Rare odds 5→15%,12→22%,20→30%, same 15 Shop random draws and untouched other streams. The independent Flow agent ran it successfully; log `/tmp/nc-repair-trade-journal.log`. The manual row above proves ownership/Shop wiring, not odds from one sample.

## Reproducible CUA limitation

The documented native API is `drag(from: Vec2, to: Vec2): Promise<void>`, with each `Vec2` a two-number coordinate pair. There is no documented duration, arbitrary path, held-pointer or pointer-move API.

- On the app, after raising the window, `sim.drag([68,262],[180,565])` opened Bookmark details like a tap; no lift/movement appeared.
- Independent native QA List control `sim.drag([218,756],[218,350])` did not scroll. Exposed `Scroll Down` accessibility actions did work.
- To distinguish app gesture interception from tool delivery, launched Apple's built-in `com.apple.Preferences` on the same SE. Fresh screenshot showed Apple Account through Search. Called `sim.performSecondaryAction(0,'Raise'); sim.drag([217,706],[217,408]);` wholly inside the native Settings list. The call returned success, but screenshot/AX were unchanged and the cursor stayed at the starting Search row. Returned to the game without changing settings/save.

Thus no product defect was inferred solely from these failed drag calls, and neither a diagonal nor a curved physical drag is marked passed. `InventoryDragTests` separately verifies changing-direction coordinates, finger offset, release-only exact sale, cancellation and stale-session rejection. A human/device gesture test is still required for the live pointer path.

## Screenshots and handoff

- `se-boss-sunday-bank-280.png`: genuine boss Sunday +240, total 280.
- `se-onyx-real-full-clear-180.png`: actual final Onyx/Peek placement and fullscreen Results.
- `se-shredder-top-edge-artifact.png`: original settled visual finding for independent recheck.
- `se-full-buff-shop-after-explicit-sale.png`: exactly two Buffs after explicit sale and purchase,18 coins, sold offer.
- `flow-clue-playtest.md` and its 14 JSON snapshots: independent exact-save and blocking-case evidence.

Simulator ownership was released explicitly to root after the sweep. Final state: SE build 16, ephemeral duplicate-inventory Shop,18 coins, Peek+Lucky Dip, Op-Ed→Stop. Root will hand it to the scoring tester for build 18 and then the final independent reviewer. Original backups and the user's large-phone save remain untouched. No additional Simulator operations were performed after release.
