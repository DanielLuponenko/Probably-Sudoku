# Full-book normal-UI playtest — 2026-09-05

## Objective and constraints

Finish one complete Book through the ordinary player UI, using Bookmarks,
Markers, and Buffs when strategically useful. Restart with a fresh attempt if
the Book is lost. Record every issue encountered; apply fixes only after a
complete Book has been played. Read-only source localization may inform the ledger.
The user later explicitly authorized parallel implementation during this
attempt; that scope change is recorded separately below.

- Operator: root agent, exclusively controlling the native UI.
- Device: existing iPhone 17 Pro simulator.
- Build: current uncommitted working-tree build; preceding app gate passed 192 tests.
- No QA routes, hidden solution inspection, or run-save inspection.
- The earlier `UI-SMOOTH-SHOP` run was discarded through Settings before this
  attempt; that was setup, not a playtest loss.
- This ledger records operator reports. It does not independently inspect the
  device, recording, or saved game.

## Attempt 1 — paused by user on 2026-09-06

The user explicitly stopped gameplay testing and redirected work to production
AdMob configuration. The Book is NOT complete. Preserve this checkpoint for a
future playtest request; no further player actions were taken after the stop.

- Fresh Volume 1, Obstacle I.
- Recording safely closed: `/tmp/numberclub-full-book-attempt1.mov` — duration
  3,884.69 seconds (about 64m45s), size 835,317,353 bytes, as reported by the operator.
- Part 2 recording stopped with SIGINT: `/tmp/numberclub-full-book-attempt1-part2.mov`.
- Checkpoint screenshot: `/tmp/numberclub-playtest-11-of-27-checkpoint.png`.
- Latest position: Level 5, Puzzle 1, Turn 2; 10,275 / 16,000 after the
  first seven placements, with ×15 including Syndication's ×1.25.
- Progress: 12 of 27 puzzles completed; no losses, wrong placements, or Clipping skips.
- Current reported Bookmark order: Local Gossip, Sunday Supplement, Op-Ed,
  Syndication, Stop the Presses (all five slots full); Golden at R1C1,
  Emerald at R3C3, Copper at R5C5, and Crimson at R9C9. Redraw and Overtime
  are owned but unused. Balance: 122 coins.
- The user approved a UI-test touch driver. An attach-only driver performed
  the ordinary hold-and-drag to sell Paper Route; selling is now verified.
  No hidden progress or solution data was inspected.
- The live app remains the unchanged, previously installed build while
  source fixes and separate Engine tests proceed. This is not a completed
  playthrough or abandonment.

### Progress and decisions

| Milestone | Result / decision | Coins |
| --- | --- | --- |
| Start | Fresh Book | 5 |
| Level 1, Puzzle 1 | Target cleared: 1,075 / 1,000, in 3 Turns; 7 unused Turns | 5 |
| Cash Out | 12-coin payout | 5 → 17 |
| First Shop | Bought Local Gossip for 5 coins | 17 → 12 |
| First Shop | Bought Copper Marker for 5 coins; assigned R5C5 | 12 → 7 |
| First Shop | Bought Paper Crane for 3 coins; reserved for the next puzzle | 7 → 4 |
| Level 1, Puzzle 2 | Used Paper Crane, choosing 2. Buff consumed; its +50 was confirmed by 100-point placements of 2 including Local Gossip. | 4 |
| Level 1, Puzzle 2 | Placed 6 at Copper R5C5 to complete a column; +3 coins observed | 4 → 7 |
| Level 1, Puzzle 2 | Target cleared: 1,520 / 1,500, in 3 Turns; 7 unused Turns | 7 |
| Cash Out | 12-coin payout | 7 → 19 |
| Second Shop | Bought Paper Route for 5 coins | 19 → 14 |
| Second Shop | Rerolled for 2 coins; next reroll displayed 3 | 14 → 12 |
| Second Shop | Bought Golden Marker for 6 coins; assigned R1C1 | 12 → 6 |
| Level 1 Boss briefing | Unlucky Lucky: one Bookmark sleeps each Turn | 6 |
| Level 1, Boss | Target cleared: 2,155 / 2,000, in 4 Turns; 6 unused Turns | 6 |
| Boss Cash Out | Confirmed 13-coin payout: 5 base + 6 unused Turns + 2 Paper Route | 6 → 19 |
| Level 2, Puzzle 1 | Target cleared: 2,450 / 2,000 in 2 Turns; payout 16 coins | Intermediate balance not reported |
| Level 2, Puzzle 2 | Target cleared: 3,160 / 3,000 in 2 Turns; payout 16 coins | Intermediate balance not reported |
| Level 2, Boss | Heavy Lifter cleared: 17,370 / 16,000 in 4 Turns; payout 15 coins | Intermediate balance not reported |
| Shops during Level 2 | Added Sunday Supplement for 7, Auction Notices for 6, Op-Ed for 4, and Crimson Marker for 9; assigned Crimson R9C9. Exact purchase chronology/intermediate balances were not supplied. | Latest reported balance: 38 |
| Auction Notices check | First free reroll worked in the next Shop | Free reroll confirmed |
| After Level 2 | Editorial Board offered, but all five Bookmark slots occupied. Tapping owned Op-Ed showed only its description; Run information showed only the item list. | 38 |
| Level 3, Puzzle 1 | Target cleared: 5,500 / 4,000 in 2 Turns; payout 18 coins | 38 → 56 |
| Level 3, first Shop | Paid rerolls of 2, 3, and 4 coins; full Bookmark slots prevented buying Rolling Presses | 56 → 47 |
| Selling attempt | Documented CUA controls could not perform the required hold gesture. Ordinary drag/right-click opened the popover only. Permission to use a UI-test driver for an ordinary hold gesture was requested asynchronously from the user; response pending. | No sale reported |
| Level 3, Puzzle 2 | Target cleared: 6,900 / 6,000 in 4 Turns; payout 17 coins | 47 → 64 |
| Level 3, second Shop | Bought Paper Crane for 3 coins | 64 → 61 |
| Level 3, Boss | Used Paper Crane on digit 5 against The Critic; Buff consumed. Target cleared: 9,960 / 8,000 in 3 Turns. | 61 |
| Level 3 Boss Cash Out | Payout 20 coins; now at the Shop | 61 → 81 |
| Shop before Level 4 | Bought Emerald Marker for 7 coins, assigned R3C3; bought Redraw for 3 coins | 81 → 71 |
| Level 4, Puzzle 1 | Target cleared: 8,660 / 8,000 in 3 Turns; payout 21 coins | 71 → 92 |
| Shop before Level 4, Puzzle 2 | Bought Overtime for 4 coins; retained unused | 92 → 88 |
| Level 4, Puzzle 2 | Copper R5C5 completed a box; +3 coins observed | 88 → 91 |
| Level 4, Puzzle 2 | Target cleared: 12,280 / 12,000 in 5 Turns; payout 21 coins | 91 → 112 |
| Level 4, second Shop checkpoint | Used the free reroll. Syndication 8 and Puzzle Corner 7 offered, but Bookmark slots remain full; other offers: Emerald 7, Golden 6, Overtime 4. Run preserved at this Shop. | 112 |
| Authorized touch-driver sale | User approved the standalone attach-only UI-test driver. Ordinary Paper Route hold-and-drag sold it for 2 coins; then bought Syndication for 8. | 112 → 114 → 106 |
| Level 4, Boss | The Editor: six-card Hand. Target cleared: 16,920 / 16,000 in 5 Turns. Emerald R3C3 was held until its row completed, and its doubled Line Clear was verified; Golden R1C1 was also used. | 106 |
| Level 4 Boss Cash Out | Payout 20 coins | 106 → 126 |
| Shop before Level 5 | Used Auction Notices' free reroll before selling that Bookmark for 3 coins. Bought Stop the Presses for 7. | 126 → 129 → 122 |
| Level 5, Puzzle 1 — in progress | Turn 2, score 10,275 / 16,000 after the first seven placements. Turn multiplier ×15 includes Syndication's ×1.25. | 122 |

## Issue ledger

These entries record the observed build, which remains installed throughout
the attempt. Parallel source work is not a verified fix in that live build.
“Observed” describes reported UI evidence, not a proven root cause or gameplay failure.

| ID | Status | Observation | Scope / follow-up |
| --- | --- | --- | --- |
| UI-01 | Observed accessibility issue | A non-Boss page's visually blank Boss band exposed accessibility text beginning “The Deadline 8 Turns…”, although the current puzzle had 10 Turns. | Hidden placeholder should not announce an unrelated Boss. Another agent has located the owner; no fix applied as part of this playtest. |
| UI-02 | Observed visual issue | Paper Crane's Shop description truncated its duration to “rest of the Pu…”. | Preserve the full effect description in the Shop's available space. |
| UI-03 | Observed visual issue | Native Item details title appeared white on the cream sheet. | Low contrast; verify and repair the title's foreground/theme behavior after completion. |
| UI-04 | Observed accessibility issue | Sold Shop cards exposed duplicate uppercase and ordinary-case accessibility buttons. | Check sold-item semantics, duplicate controls, and disabled state after completion. |
| UI-05 | Observed accessibility issue, scope refined | On an earlier ordinary-puzzle briefing, the Run Plan preview's visible upcoming Boss name/power were omitted from its combined accessibility label. At the actual Level 1 Boss briefing, the Boss name and power **were** exposed to accessibility. | Restrict investigation to the earlier Run Plan preview; do not claim the actual Boss briefing lacks its encounter information. |
| UI-06 | Uncertain; no gameplay defect established | End Turn initially appeared not to respond. Accessibility score/Turn text lagged while screenshots showed updated values. Subsequent coordinate-based End Turn actions banked correctly throughout normal play so far. | Do not treat cached accessibility status as an engine failure. Separate stale accessibility output, tap targeting, and actual action handling before proposing a fix. |
| UI-07 | Observed visual issue — high priority | Level 1 Boss briefing grew the Book upward into the HUD/Bookmark row. Bookmark icons collided with coins around screen y≈102, versus the normal row y≈153 and Book top y≈172; Boss Book top was around y≈126 and its bottom approached the screen edge. | Evidence: `/tmp/numberclub-playtest-boss-briefing-overlap.png`. Read-only localization: `PuzzleBriefingView.swift` adds Boss-only narration/preview at lines 41–44; `BossEncounterPreview` fixes its board at 315pt height (line 577) plus 15pt padding (line 580), inside the briefing's non-scrolling VStack. This is a candidate layout mechanism, not yet a verified fix. Preserve the gameplay board geometry and investigate after completion. |
| UI-08 | Code-confirmed feedback risk; operator/agent report | `InventoryBookmark` accessibility omits the asleep state. Last-card “FIRED” feedback checks the new sleeping-Bookmark index after automatic End Turn, so it may misdescribe the preceding scoring move. | Source findings reported by `flip_lifecycle_tests`; record separately from engine scoring. A stale sleeping visual was **not** confirmed: the apparent mismatch can be explained by a previous Turn's banked score versus the next Turn's sleeping index. Reproduce feedback/VoiceOver behavior after the complete playthrough; no product changes yet. |
| UI-09 | Observed discoverability issue; selling now verified | With five Bookmark slots full, the operator could not find a Sell/Replace action in Op-Ed's description popover or Run information. Help mentions selling for a partial refund but does not explain its gesture. | Selling exists: hold an owned tab for roughly 0.22s, drag it onto the Sell counter at the right of the Bookmark row, and release; releasing elsewhere restores it (`BookmarkRow.swift:153–182`). After explicit user approval, an attach-only touch driver sold Paper Route with this ordinary gesture and the 2-coin refund was verified. Discoverability remains a separate issue; there is no confirmed failed selling gesture. |

### Non-issues / uncertain automation evidence

- No touch failures are confirmed through the latest Level 5, Puzzle 1 report. A batching helper flagged
  null cells after an automatic win had already changed the page; that does
  not establish an app/UI bug.
- Initial CUA attempts could not produce a genuine hold-and-drag input.
  Full CUA documentation was checked: available click/drag operations have
  no hold/duration control. Normal drag, zero-length drag, and right-click
  opened only the popover. This is a tooling limitation, not a confirmed
  touch/gesture defect in the game. UI-09's discoverability finding remains
  distinct from this limitation. The user subsequently authorized the
  attach-only driver, and the ordinary selling gesture succeeded.

## User-authorized parallel implementation — 2026-09-06

The user explicitly expanded the scope before the Book was completed:

- Reserve exactly five major Bosses for Level 9, Puzzle 3, with no Collector
  in the final pool. Preserve already-active saved encounters.
- Finish the Book without a Shop after the final victory.
- Keep obstacle progress specific to each Book.

Engine final-Boss/completion changes and regression tests are now written;
app completion, per-Book progress, Bookmark/Shop fixes, and briefing UX are
being handled in parallel by their owners. The existing live binary remains
unchanged. Do not count source changes as successful live re-verification,
or count Engine test fixtures as puzzles played in this attempt.

## Completion and follow-up

- Levels 1–4 complete (12/27); Level 5, Puzzle 1 is in progress. No Book
  completed yet; no losses, wrong placements, or skips.
- No fixes were started at the original 11/27 checkpoint. Subsequent source
  work follows the explicit scope change above and is not installed in the live run.
- Continue collecting puzzle/shop milestones, failures/restarts, and UI issues.
- After a complete Book: stop the recording, review evidence, confirm issue
  causes, make focused fixes, and run the relevant regression gates.
