# Expanded item catalogue

**50 Bookmarks · 50 Markers · 40 Buffs**

Design proposal. All prices are proposed base coin prices; gameplay balance is untested.

## Shared rules

- This is an expansion proposal, not implemented game content. Existing identifies a retained ability; Reworked identifies a proposed change to an existing ability. All prices shown are proposed base coin prices and need playtesting.
- Bookmarks occupy five held slots and apply in visible scoring order. Markers own board positions for the Book: one Marker per square, given-covered squares are inactive, and each owned type gains one square per completed Level, up to nine. Buffs occupy two inventory slots and are consumed on use.
- For NEW score rewards, an eligible placement is correct, non-Clue, not zeroed by a Boss, and made before the Puzzle is won. A qualifying Clear is a non-Clue, nonzero-scoring row, column, or box completed by that placement. An eligible Turn contains at least one eligible placement. New reward triggers do not farm Keep Filling. Existing Onyx explicitly restores Clue placement points only, never Clue Clear points.
- Placement base points are 10 times the digit; each row, column, or box Clear has base 45. Flat placement bonuses apply before that event's multipliers. Direct score rewards bypass Turn Mult. Puzzle Mult and held Bookmark Mult are separate; item rules specify their scope.
- All draw, return and exchange effects move existing numbers between Hand and Pool. The Sudoku solution, givens and number-conservation rule remain unchanged. A draw cannot exceed available Pool supply. Chance uses the seeded game stream.
- Any choice with no legal target is unavailable and does not consume a Buff or charge an extra cost. Existing Boss restrictions still apply unless an item explicitly names an exception. Item-specific limits override general defaults.
- The current shop rolls prices by category and rarity. This proposal uses item-specific base prices: Bookmarks 4–15, Markers 5–16, Buffs 3–10. Equal prices are intentional. Rarity describes offer frequency, not an automatic power ranking.
- Marker identity uses glyph plus color, not color alone. Keep the board's resting glyph small; hold a square for its rule and retain the existing question-mark reference. Full recessed tiles on these sheets are shop/inspection artwork.

## Bookmarks

### B01 · Morning Edition

**Common · N 4 · Reworked**

At the end of each eligible Turn, add 100 direct points after banking. This bonus is not multiplied.

**Limit:** Once per scheduled Turn; no Keep Filling or empty-Turn payout.

**Asset:** Newspaper with a small rising sun

**Current ability being replaced:** +100 points at the end of each Turn

**Implementation notes:** Existing .turnEnd directScore hook; add an eligible-placement flag for the Turn. The eligibility guard is an explicit change from the current unconditional payout.

### B02 · Evening Edition

**Common · N 4 · Reworked**

When you bank Turn 10 with at least one eligible placement, add 300 direct points after banking. Extra Turns do not repeat the award.

**Limit:** Once per Puzzle; requires a real scoring placement on Turn 10.

**Asset:** Newspaper with a small crescent

**Current ability being replaced:** +300 points at the end of Turn 10

**Implementation notes:** Current Actions.endTurn deliberately dispatches .puzzleEnd on Turn 10; preserve that timing, adding eligibility. This does not move the award to puzzle completion or the final extended Turn.

### B03 · Local Gossip

**Common · N 5 · Existing**

Each correct placement gains 30 flat points before local multipliers and normal score-zeroing rules. Onyx may still restore scoring on its Clue placement.

**Limit:** Once per newly filled square; normal Clue and Boss score-zeroing still applies.

**Asset:** Two overlapping speech bubbles

**Implementation notes:** Existing .place flat hook; preserve current Onyx-restored Clue interactions and final score zeroing. Do not silently introduce a new non-Clue gate.

### B04 · Sports Section

**Common · N 5 · Existing**

Each completed row, column, or box gains 25 flat Line Clear points before local multipliers. Clue-created clears still score zero.

**Limit:** Once per newly completed unit; simultaneous units each qualify; normal score-zeroing applies.

**Asset:** Running figure crossing a finish line

**Implementation notes:** Existing .lineClear flat hook; retain current per-unit events and normal Clue/Boss score zeroing.

### B05 · Society Pages

**Uncommon · N 7 · Existing**

A Full Clear gains 500 flat Full Clear points before local multipliers. A Clue-created Full Clear still scores zero.

**Limit:** Once per Puzzle; normal score-zeroing and frozen Keep Filling score remain.

**Asset:** Crown above a tiny complete grid

**Implementation notes:** Existing .fullClear flat hook; preserve current score resolution without adding a new event guard.

### B06 · Op-Ed Column

**Common · N 5 · Existing**

Add 1 to Turn Mult at this Bookmark's locked slot when the Turn banks.

**Limit:** One held-Mult operation per Turn; no added points if the bank is zero.

**Asset:** Single quotation mark over one text line

**Implementation notes:** Keep .anyScore as a pure held-Mult read, evaluated in the locked visible order.

### B07 · Editorial Board

**Uncommon · N 8 · Reworked**

If this Turn included eligible placements in at least three different 3×3 boxes, add 3 to its Turn Mult at this Bookmark's locked slot.

**Limit:** Once per Turn; unique boxes only.

**Asset:** Three compact quotation marks across a row

**Current ability being replaced:** +2 mult

**Implementation notes:** Replace the unconditional +2. Store a nine-bit eligible-box mask per Turn; the Mult preview reads it without rerunning events.

### B08 · Front Page Splash

**Uncommon · N 9 · Existing**

Add 1 Turn Mult for each Bookmark in the locked loadout, including this one, at this Bookmark's slot.

**Limit:** Count locked loadout once; normal capacity five.

**Asset:** Megaphone over a newspaper front page

**Implementation notes:** Existing bookmarkCount-based .anyScore; use the existing locked snapshot and disabled-item policy.

### B09 · Letters to the Editor

**Uncommon · N 8 · Reworked**

In a Boss Puzzle, a Turn following a Turn where you paid a wrong-placement penalty gains +3 Turn Mult at this Bookmark's slot, provided the current Turn is eligible.

**Limit:** Once per Turn; fully waived penalties do not qualify; no stacking per mistake.

**Asset:** Envelope containing a quotation mark

**Current ability being replaced:** +3 mult, Boss Puzzles only

**Implementation notes:** Replace unconditional Boss +3 with a previous-Turn paid-penalty flag. Record actual penalty after waivers, not wrong-click count; reset at puzzle start.

### B10 · Rolling Presses

**Uncommon · N 10 · Existing**

Start each Puzzle at ×1. Each Line Clear adds ×0.5 to this Bookmark's held multiplier; apply the resulting factor at its locked slot when a Turn banks.

**Limit:** Each unit can grow it once; reset at Puzzle start.

**Asset:** Two printing gears with one curved motion line

**Implementation notes:** Existing .lineClear puzzle counter and pure .anyScore factor. Preserve current growth even on a Clue-created/zeroed clear; Keep Filling still cannot add score. Growth earned this Turn is included before banking.

### B11 · Syndication

**Rare · N 13 · Existing**

Start the Book at ×1. Each Puzzle win adds ×0.25 for later Puzzles; apply the stored factor at this Bookmark's locked slot.

**Limit:** One increase per Puzzle win; skipped Puzzles do not count; reset with Book.

**Asset:** Two linked newspaper copies

**Implementation notes:** Keep the existing win-payout growth path and run state. Do not award growth twice after Keep Filling or replayed payout.

### B12 · Stop the Presses

**Rare · N 12 · Reworked**

Multiply Turn Mult by 3 at this Bookmark's locked slot only when the Turn contains one or two eligible placements. A third eligible placement removes this Turn's bonus.

**Limit:** One held factor per Turn; count placements, not their clears.

**Asset:** Printing gears interrupted by a horizontal stop bar

**Current ability being replaced:** x3 mult, always

**Implementation notes:** Replace always-on ×3 with a Turn eligible-placement counter. Clues and zeroed placements neither qualify nor increment the count; preview must show losing the factor after a third scoring placement.

### B13 · The Sunday Supplement

**Rare · N 13 · Existing**

Multiply Turn Mult by 2 at this Bookmark's locked slot; use ×3 during a Boss Puzzle instead.

**Limit:** Once per Turn in locked slot order.

**Asset:** Open supplement with a small Sunday sun

**Implementation notes:** Existing pure .anyScore difficulty branch. Unlike reworked Stop the Presses, there is no placement-volume restriction.

### B14 · Extra! Extra!

**Rare · N 12 · Existing**

Multiply the local points of each Line Clear and Full Clear by 3 before they join the Turn bank. Normal Clue and Boss score-zeroing still applies.

**Limit:** Each newly completed unit/full board once; does not multiply adjacent placement points.

**Asset:** Megaphone with two short emphasis rays

**Implementation notes:** Preserve eventMultX on clear events; never convert this into global Turn Mult.

### B15 · Finance Pages

**Common · N 5 · Existing**

Gain 1 coin for each row, column, or box clear, including clears made by Clues or during Keep Filling.

**Limit:** Once per newly completed unit; score-zeroing does not cancel its coin reward.

**Asset:** Rising chart ending in a small coin

**Implementation notes:** Preserve current unconditional .lineClear coins hook: Actions applies side effects even when Clue/Boss points are zero or score is frozen. The new-item anti-farming guard must not silently change this legacy ability.

### B16 · Paper Route

**Common · N 5 · Existing**

Gain 2 extra coins in each Puzzle-win payout.

**Limit:** Once per won Puzzle; no skipped-Puzzle or repeated payout.

**Asset:** Bicycle carrying one folded newspaper

**Implementation notes:** Existing Paper Route payout component; preserve payout idempotence.

### B17 · Market Wrap

**Uncommon · N 8 · Existing**

Raise the base cap on each Puzzle-win interest payout from 10 to 15 coins while owned. Other Book, Clipping, or subscription cap modifiers still apply.

**Limit:** Changes the payout cap, not the coin balance that earns interest; stronger base-cap replacements still win.

**Asset:** Rising chart beneath a horizontal cap line

**Implementation notes:** Verified RunState.interestCap: choose Market Wrap base 15 (otherwise 10), Annual Rate replaces that base with 20, then add Book and Clipping deltas. Interest is floor(coins/10), capped by that result; preserve this exact order.

### B18 · Auction Notices

**Uncommon · N 8 · Existing**

The first paid reroll you request in each Shop costs 0 coins.

**Limit:** Once per visit; entering the same visit again does not refresh it.

**Asset:** Auction hammer beside a small circular arrow

**Implementation notes:** Existing Auction Notices price query; retain canonical visit ID and advance reroll count normally.

### B19 · Help Wanted

**Common · N 6 · Existing**

Increase the Hand refill target by 1 while this Bookmark is owned; other boss and item adjustments still apply.

**Limit:** Standing +1; unplaced cards already carry over normally.

**Asset:** Person silhouette with a small plus

**Implementation notes:** Use existing effectiveHandSize. Do not describe baseline Hand carryover as part of this effect.

### B20 · Weather Forecast

**Common · N 4 · Existing**

Add 2 to each Puzzle's Toss allowance while this Bookmark is owned.

**Limit:** One +2 allowance grant per Puzzle; does not refill on save/reopen.

**Asset:** Cloud with two small wind strokes

**Implementation notes:** Existing effectiveTossAllowance query; preserve boss adjustments and normal Toss cost.

### B21 · Puzzle Corner

**Uncommon · N 7 · Existing**

Add 1 Clue at the start of each Puzzle while this Bookmark is owned. Boss rules that disable Clues still apply.

**Limit:** Once per Puzzle; Clue placements retain their zero-score rule.

**Asset:** Puzzle piece containing a small question mark

**Implementation notes:** Existing effectiveClues query. Never restore Clue scoring or bypass a Clue-disabled Boss.

### B22 · Late City Final

**Uncommon · N 9 · Existing**

Add 1 scheduled Turn to each Puzzle while this Bookmark is owned.

**Limit:** One standing Turn extension; does not move Evening Edition from Turn 10.

**Asset:** Moon above a small clock dial

**Implementation notes:** Existing effectiveTurns query; preserve normal loss, refill, and automatic Turn-end rules.

### B23 · Crossword Daily

**Rare · N 11 · Existing**

After each row, column, or box clear, draw 1 number from the Pool into the Hand, including Clue and Keep Filling clears.

**Limit:** Once per newly completed unit; each draw requires an actual Pool card.

**Asset:** Crossword grid with one outward number tile

**Implementation notes:** Preserve the current unconditional .lineClear draws hook and finite Pool conservation. Normal Hand carryover is unchanged; zero-score clears still draw.

### B24 · Margin Notes

**Common · N 4 · New**

Eligible placements on the board's outermost row or column gain 50 flat points before local multipliers.

**Limit:** One bonus per placement, including corners; not once per touching edge.

**Asset:** L-shaped page margin with a single dot

**Implementation notes:** New .place square-coordinate predicate; no new solution information. Append one flat contribution even at a corner.

### B25 · Neighbourhood News

**Common · N 5 · New**

An eligible placement touching at least two previously player-filled squares orthogonally gains 45 flat points before local multipliers. Givens and Clue-filled squares do not count as neighbours.

**Limit:** Once per placement; inspect the board before filling the square.

**Asset:** Three linked square windows

**Implementation notes:** Extend context with prior orthogonal occupancy and fill provenance. Diagonals, Givens, and Clue provenance are excluded.

### B26 · Serial Story

**Uncommon · N 8 · New**

The third eligible placement in a consecutive ascending run such as 2→3→4 gains 120 flat points before local multipliers. A wrong, Clue, zeroed, or nonconsecutive placement breaks the run.

**Limit:** Once per Turn; no 9→1 wrap; reset at Turn end.

**Asset:** Three numbered dots joined by a rising line

**Implementation notes:** Persist the last eligible digit and streak length per Turn. After payout consume the Turn trigger; unrelated clear events must not break the placement sequence.

### B27 · Double Column

**Common · N 6 · New**

If you place the same digit eligibly in two different boxes during a Turn, add 2 Turn Mult at this Bookmark's locked slot when that Turn banks.

**Limit:** Once per Turn regardless of additional matched pairs.

**Asset:** Two thin columns joined by an equals sign

**Implementation notes:** Track digit-to-box masks for eligible placements during the Turn; pure bank predicate reads any mask with at least two boxes.

### B28 · Carryover

**Uncommon · N 8 · New**

After an eligible Turn banks, add direct points equal to 10% of the previous Turn's ordinary bank, rounded down and capped at 300. Direct bonuses are excluded from the copied amount.

**Limit:** Once per Turn; Turn 1 has no prior bank; reset each Puzzle.

**Asset:** Two offset ledger boxes linked by a bent arrow

**Implementation notes:** Store the finalized ordinary bank before directScore contributions. Award this after current bank; snapshot prior bank even if zero; never feed Carryover into itself.

### B29 · Number Index

**Rare · N 12 · New**

The first time you score all nine different digits in a Puzzle, this Bookmark permanently gains +2 held Turn Mult for the rest of the Book, including the current Turn.

**Limit:** At most +2 per Puzzle and +10 per Book; each digit counted once per Puzzle.

**Asset:** A circular index of small numbered tabs

**Implementation notes:** Add a Puzzle digit bitmask and a run growth counter capped at ten. Apply earned +Mult at this locked slot; persist activation once and exclude skipped Puzzles.

### B30 · Early Deadline

**Uncommon · N 7 · New**

Win a Puzzle by the end of Turn 5 to gain 4 extra coins in its payout.

**Limit:** Once per Puzzle; no reward for skipping.

**Asset:** Clock hand pointing to a small finish pennant

**Implementation notes:** Record the actual winning bank's Turn before incrementing turnNumber. Payout must be idempotent and independent of later Keep Filling.

### B31 · Duplicate Dispatch

**Common · N 6 · New**

Once per Puzzle, at a Turn's start with at least three copies of one digit in your Hand, you may return all but one of those copies to the Pool and draw the same number of replacements.

**Limit:** Once per Puzzle; no exchange after that Turn's first action.

**Asset:** Three overlapping equal-number tiles with one curved exit arrow

**Implementation notes:** New optional start-Turn action and used flag. Return cards before drawing with the seeded Pool stream; replacements may repeat, conserve Pool+Hand counts, and cancel consumes nothing.

### B32 · Overflow Column

**Uncommon · N 8 · New**

Before each eligible placement, count how many cards the Hand holds above its normal refill target. Add 25 flat placement points per excess card, capped at 100.

**Limit:** Count before removing the placed card; capped at four excess cards.

**Asset:** A short column of tiles spilling above its top line

**Implementation notes:** Expose pre-placement Hand count and current effectiveHandSize in context. The target already includes Help Wanted and boss adjustments; do not treat ordinary carried cards as overflow unless count exceeds it.

### B33 · Paper Salvage

**Common · N 4 · New**

The first Toss you make in a Puzzle immediately draws 1 replacement number from the Pool. The Toss still spends its normal allowance.

**Limit:** Once per Puzzle; requires a remaining Pool card.

**Asset:** Folded scrap entering a small return loop

**Implementation notes:** New Toss hook after normal card return and allowance spend; draw from seeded Pool without altering automatic final-card Turn-end policy. Resolve replacement before checking whether Hand is empty.

### B34 · Forthcoming Edition

**Common · N 6 · New**

Show the next two numbers that the current Pool would draw. Refresh the preview whenever the Pool or its draw state changes.

**Limit:** Information only; never consumes or changes a draw or reveals a solution.

**Asset:** Folded newspaper with two small numbered peek tabs

**Implementation notes:** New read-only forecast view using a cloned Pool and RNG state. Preview must match actual future draws, update after exchanges, and never advance the live RNG.

### B35 · Carbon Paper

**Uncommon · N 8 · New**

Once per Turn, an eligible marked placement that adds marker-only extra placement points stores that extra amount, capped at 180. Add it as flat points to your next eligible unmarked placement that Turn, then clear it.

**Limit:** One positive-bonus transfer per Turn; unused bonus expires; zero or negative marker bonuses do not arm it.

**Asset:** Two paper layers with a small dot printed through both

**Implementation notes:** New receipt-based marker-only delta excluding all Bookmarks, Buffs, global Mult, coins, draws, and copied effects. Define delta against the same placement without its marker; cap at 180 after marker-local factors; do not copy Clue-restoring Onyx scoring.

### B36 · Pocket Insert

**Rare · N 11 · New**

Increase your Buff inventory capacity from 2 to 3 while this Bookmark is owned.

**Limit:** One added slot; never creates a Buff.

**Asset:** Small paper pocket holding one dark tab

**Implementation notes:** New dynamic Buff-capacity query and inventory layout. Before selling/removing this with three Buffs held, require a reversible inventory choice; never silently delete an item.

### B37 · Bulk Notice

**Common · N 4 · New**

Reduce the first Buff you buy in each Shop by 1 coin, to a minimum price of 1.

**Limit:** Once per visit; inspecting/cancelling does not spend the discount.

**Asset:** Two small receipts beneath a single minus notch

**Implementation notes:** New per-visit Buff-purchase flag and final-price calculation. Display adjusted price before confirmation; free rewards do not consume it.

### B38 · Buyback Column

**Common · N 6 · New**

Once per Shop, sell one other Bookmark you already owned on entry for its actual purchase price instead of the normal resale value.

**Limit:** Once per visit; excludes this item and items bought in that visit; refund cannot exceed actual paid price.

**Asset:** Bookmark tab circling back to a coin

**Implementation notes:** New sale quote and Shop-entry owned-instance snapshot. Price paid includes prior discounts; consume only on confirmed sale; no same-visit buy/sell arbitrage.

### B39 · Window Shopping

**Common · N 5 · New**

Leave a Shop without buying any item or requesting any reroll to gain 3 coins. Selling owned items does not disqualify you.

**Limit:** Once per canonical visit; free rerolls count as rerolls.

**Asset:** Shop window outline with a closed coin purse

**Implementation notes:** Track visit purchases and reroll requests, including free rerolls; pay once on committed exit, never on entering/exiting a detail sheet.

### B40 · Advance Payment

**Uncommon · N 9 · New**

Before the first action of each Puzzle, you may pay 3 coins to activate ×2.5 Turn Mult at this Bookmark's locked slot for that Puzzle.

**Limit:** One payment per Puzzle; no credit or refund; skipped Puzzles have no offer.

**Asset:** Coin partially slid under a multiplier stamp

**Implementation notes:** New optional start action, affordability check, and Puzzle activation flag; the fixed ×2.5 factor is read at bank in both ordinary and Boss Puzzles. Save/reopen cannot repeat payment or reopen a declined choice after play begins. This costs recurring coins to exceed Sunday Supplement in ordinary Puzzles, while Sunday remains stronger in Boss Puzzles.

### B41 · Type Case

**Common · N 6 · New**

At each Turn's start, choose one digit currently in your Hand to hold in reserve. Your first three eligible placements of other digits gain 50 flat points each; placing the chosen digit ends the bonus for that Turn.

**Limit:** Up to three bonuses per Turn; any placement of chosen digit ends it; no choice after first action.

**Asset:** One fixed type block beside three loose type blocks

**Implementation notes:** New one-tap optional digit choice; no physical new reserve slot and no change to Hand carryover. A Clue/zeroed chosen-digit placement ends the arm but cannot earn a bonus; wrong chosen-digit attempt also ends it to prevent repeated probing.

### B42 · Cross Reference

**Uncommon · N 8 · New**

When one eligible placement completes at least two of row, column, and box, schedule 2 extra Pool draws after the next ordinary Turn refill.

**Limit:** At most two triggers per Puzzle; one two-card packet per placement; Pool availability applies.

**Asset:** Crossing row and column with two outward tiles

**Implementation notes:** Use completed unit identities, not repeated .lineClear events. Queue draw packets until after the next actual playable-Turn refill; discard them if the Puzzle ends before another Turn.

### B43 · Issue Tracker

**Common · N 5 · New**

On an eligible box clear, gain 1 coin for each different Turn in which you scored a placement inside that box, capped at 3 coins.

**Limit:** Each box once; maximum three coins per box; rows and columns do not pay.

**Asset:** A small box grid beside three calendar dots

**Implementation notes:** Track eligible Turn IDs per box; Givens and Clue placements add no participation. Check the box-completion event once, then consume its tracker.

### B44 · Correction Ledger

**Common · N 4 · New**

Record half of the first wrong-placement penalty you actually pay each Puzzle, rounded down and capped at 150. After three later eligible placements, refund that amount as direct score.

**Limit:** One recovery per Puzzle; waived/zero penalties never arm; unused recovery expires.

**Asset:** Correction stroke crossing one ledger entry

**Implementation notes:** Snapshot the actual deducted score, not nominal 50×digit, to avoid profit at score zero. Refund after the third eligible event without multiplying; wrong events do not advance the count; no Keep Filling recovery.

### B45 · Reference Desk

**Uncommon · N 8 · New**

The first eligible row clear, first eligible column clear, and first eligible box clear in a Puzzle each restore 1 Clue you have already spent. A category completed before you spend a Clue gives no charge.

**Limit:** Three category opportunities per Puzzle; each restores at most one spent Clue and is consumed even if none is spent.

**Asset:** Three small unit grids feeding one question-mark card

**Implementation notes:** New per-type consumed mask and spent-Clue counter. Do not exceed the normal Clue entitlement by refunding; respect bosses disabling Clues, and never score a Clue-created clear.

### B46 · Recycled Insert

**Common · N 6 · New**

After you consume three purchased Buffs, claim one free Common Buff from a choice of two at the next Shop. Claiming spends three receipts; free reward Buffs do not create receipts.

**Limit:** One claim per Shop; receipts persist this Book; free Buffs excluded; capacity applies.

**Asset:** Three receipt stubs folding into one small dark tab

**Implementation notes:** New Buff purchase provenance, run receipt counter, seeded claim choices keyed by visit, and capacity-safe claim flow. Persist choices so reopening cannot reroll; cancelling or full inventory must not destroy receipts.

### B47 · Readers' Circle

**Rare · N 12 · New**

At an eligible Turn bank, repeat the additive +Mult amount supplied by the Bookmark immediately to this one's left, capped at +3. Do not copy ×Mult, non-Mult effects, or another Readers' Circle.

**Limit:** One pure copied additive operation; leftmost slot contributes zero; no recursive copiers.

**Asset:** Two neighbouring bookmark tabs joined by a loop

**Implementation notes:** New read-only held-contribution introspection from the locked loadout. Copy the neighbour's evaluated additive amount for this Turn without dispatching its stateful hooks; a disabled/non-additive neighbour yields zero.

### B48 · Personal Column

**Uncommon · N 8 · New**

Choose one digit at Puzzle start. After each of your first two eligible placements of that digit, draw another copy of it from the Pool if one remains.

**Limit:** Two trigger opportunities per Puzzle, consumed even if Pool has no copy; no number creation.

**Asset:** One numbered type block inside a thin column frame

**Implementation notes:** New stored choice and targeted finite-Pool draw, with conservation checks. Choice is player-selected 1–9 before play; no reroll of the choice after seeing results.

### B49 · Archive Room

**Uncommon · N 8 · New**

On a Puzzle win, store 50 points per unused Clue, capped at 150. Add those points as flat placement points to your first eligible placement in the next played Puzzle, then empty the archive.

**Limit:** One stored packet; skipping preserves it; no stacking beyond 150; no final-Book payout.

**Asset:** Small archive drawer holding a question-mark index card

**Implementation notes:** New run packet state. Count usable unused entitlement, excluding Boss-disabled Clues, and save once per win; first eligible placement gets flat points before local multipliers, while Clue/zeroed placements do not consume.

### B50 · Right to Reply

**Uncommon · N 7 · New**

The first time in a Puzzle a Boss would silence another Bookmark, silence this one for that same duration instead.

**Limit:** One redirection per Puzzle; no effect on non-silencing Boss rules.

**Asset:** Speech bubble protected by a short bracket

**Implementation notes:** Verified existing trigger: PuzzleState.startBossTurn selects a hooked Bookmark for The Executive Editor (internal unluckyLucky) each Turn. Add a one-shot pre-disable interceptor and consume before redirecting the selected instance to this item's index for the same Turn. The interceptor must not add itself as a normal scoring-hook candidate or create a free second interception; no repeats, target rerolls, or changes to passive upgrades.


## Markers

### M01 · Crimson Marker

**Rare · N 14 · Existing**

Multiply this square’s placement Points by 4. Does not multiply adjacent placements or the Turn bank.

**Limit:** Once per owned square per Puzzle; at most 9 placements.

**Asset:** diamond.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 14, current listed price 9; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M02 · Golden Marker

**Common · N 6 · Existing**

Add 100 flat placement Points here, before local point multipliers and the Turn’s Bookmark multiplier.

**Limit:** Once per owned square per Puzzle; at most +900 flat Points.

**Asset:** sun.max.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 6, current listed price 5; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M03 · Azure Marker

**Common · N 6 · Existing**

Gain 1 coin on each correct fill here. Preserve current resource-event behavior, including Clue and Keep Filling fills.

**Limit:** Once per owned square per Puzzle; at most 9 coins.

**Asset:** drop.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 6, current listed price 5; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. Current source dispatches this on correct fills even if they are Clue/Keep Filling; this finite once-per-square behavior is not a newly proposed repeatable farming reward. 

### M04 · Ivory Marker

**Uncommon · N 9 · Existing**

Wrong placements on this square take no score penalty. The wrong card still follows its normal return-to-Pool behavior.

**Limit:** Repeats while that square remains blank; creates no Points, coins, cards, or charges.

**Asset:** shield.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 9, current listed price 7; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M05 · Emerald Marker

**Uncommon · N 10 · Existing**

Double Points for each row, column, or box completed by a correct placement here. Clue clears and boss-zeroed clears remain zero.

**Limit:** Each completed unit once; at most 27 distinct units in the Puzzle.

**Asset:** leaf.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 10, current listed price 7; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M06 · Onyx Marker

**Uncommon · N 9 · Existing**

A Clue placement here earns its normal placement Points. Its Line Clears still score zero. Boss zeroing still wins.

**Limit:** Once per owned square per Puzzle; at most 9 placements.

**Asset:** moon.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 9, current listed price 7; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. Grandfathered exception: Onyx intentionally restores Clue placement Points; do not apply a blanket non-Clue gate to it. 

### M07 · Silver Marker

**Uncommon · N 9 · Existing**

Add 20 placement Points per copy of this digit already locked anywhere on the board before this fill, including Givens.

**Limit:** At most 8 earlier copies: +160 per square, at most 9 owned squares.

**Asset:** circle.lefthalf.filled

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 9, current listed price 7; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M08 · Sapphire Marker

**Common · N 7 · Existing**

Draw 1 random number from the Pool after a correct fill here, if available. Preserve current Clue and Keep Filling resource behavior.

**Limit:** Once per owned square per Puzzle; at most 9 draws and never more than Pool supply.

**Asset:** triangle.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 7, current listed price 6; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. Current source dispatches this on correct fills even if they are Clue/Keep Filling; this finite once-per-square behavior is not a newly proposed repeatable farming reward. 

### M09 · Rose Marker

**Rare · N 14 · Existing**

Each correct fill here adds +1 Puzzle Mult before Bookmarks for the rest of this Puzzle, including the current Turn. Preserve existing activation lifecycle.

**Limit:** Once per owned square; at most +9 Mult per Puzzle. No score grows during Keep Filling.

**Asset:** heart.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 14, current listed price 8; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. Current source dispatches this on correct fills even if they are Clue/Keep Filling; this finite once-per-square behavior is not a newly proposed repeatable farming reward. 

### M10 · Copper Marker

**Common · N 7 · Existing**

Gain 3 coins for each row, column, or box completed by this fill. Simultaneous units pay separately. Preserve current Clue and Keep Filling resource behavior.

**Limit:** At most 3 units per placement and 27 distinct units per Puzzle.

**Asset:** hexagon.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 7, current listed price 6; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. Current source dispatches this on correct fills even if they are Clue/Keep Filling; this finite once-per-square behavior is not a newly proposed repeatable farming reward. 

### M11 · Violet Marker

**Rare · N 12 · Existing**

Use 90 placement base Points, as though the placed number were 9. Do not change the digit, board solution, or flat bonuses.

**Limit:** Once per owned square per Puzzle; at most 9 placements.

**Asset:** star.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 12, current listed price 8; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M12 · Jade Marker

**Common · N 5 · Existing**

A wrong card played here returns to the Hand instead of the Pool. Normal score and boss coin penalties still apply.

**Limit:** Repeats while blank; no card is cloned, and no resource reward is produced.

**Asset:** arrow.uturn.backward

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. Existing ability and identity preserved. Proposed catalogue price 5, current listed price 5; actual current shops roll rarity-band prices. Existing source lifecycle takes precedence over the NEW-only eligibility gate. No new hook. 

### M13 · Eraser Marker

**Common · N 6 · New**

Restore 1 already-spent Toss after a qualifying placement here. Cannot raise Toss allowance above its starting value or bypass a no-Toss rule. At most 2 restored Tosses this Puzzle.

**Limit:** 2 successful restorations per Puzzle across all Eraser squares; no restoration if none was spent.

**Asset:** eraser

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Read current Boss and Obstacle no-Toss locks before granting. Count restoration, not a no-op trigger.

### M14 · Exchange Marker

**Uncommon · N 8 · New**

After a qualifying placement here, you may return one unblocked Hand card to the Pool and draw one seeded random card of a different digit. Offer only if a different digit exists in the Pool. At most 3 exchanges this Puzzle.

**Limit:** 1 optional exchange per filled square, 3 per Puzzle. No valid alternate: no transaction.

**Asset:** arrow.left.arrow.right

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Atomic optional selection; preserve card count and Pool conservation. This is an item exchange, not a Toss. Never choose a boss-barred card.

### M15 · Echo Marker

**Common · N 7 · New**

After a qualifying placement here, draw one more copy of the digit just placed, if that digit remains in the Pool. At most 3 matching draws this Puzzle.

**Limit:** 3 actual matching draws per Puzzle; no copy in Pool means no draw.

**Asset:** waveform

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Use Pool.take; never manufacture a digit. Can overflow ordinary Hand refill size like existing Sapphire.

### M16 · Prism Marker

**Uncommon · N 9 · New**

After a qualifying placement here, draw one seeded random Pool digit that is absent from the remaining Hand. At most 3 draws this Puzzle. If every available digit is already held, nothing is drawn.

**Limit:** 3 successful draws per Puzzle; selection weighted by available card copies.

**Asset:** A small circle divided into four filled quadrants by a thin ivory cross

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Filter against the post-placement Hand. Existing card/digit bans still apply to the drawn card when played.

### M17 · Fork Marker

**Uncommon · N 10 · New**

After a qualifying placement here, reveal two seeded Pool cards and choose one to add to the Hand; return the other to the Pool. If only one remains, draw it. At most 2 offers this Puzzle.

**Limit:** 2 offers per Puzzle; 1 added card per offer; no offer for an empty Pool.

**Asset:** arrow.triangle.branch

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Reserve both cards atomically in saved state until the mandatory choice resolves. Cancellation cannot reroll the sample; returned card is not duplicated.

### M18 · Forecast Marker

**Common · N 5 · New**

After a qualifying placement here, reveal the digit of the next random Pool draw. The preview lasts until that draw occurs or the Turn ends. It does not draw, reserve, or change the card. At most 3 previews this Puzzle.

**Limit:** 1 live preview; 3 activations per Puzzle; overlapping activations refresh nothing.

**Asset:** eye

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Clone the draw stream for preview without advancing it. Any Pool mutation invalidates and recomputes the preview. Never use this to predict a choice-based/filtered draw; only the next ordinary random draw. Show on existing Hand inspection, not an extra persistent bar.

### M19 · Escapement Marker

**Rare · N 13 · New**

Count qualifying fills of Escapement squares across Puzzles in this Book. Every 3 fills grant 1 extra Turn in the current Puzzle, then reset the count. After that reward, further fills this Puzzle do not add progress. Unfinished progress carries to the next Puzzle.

**Limit:** 1 extra Turn per Puzzle; each Puzzle-and-coordinate pair counts once; 0–2 saved progress carries across Puzzles.

**Asset:** hourglass

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW saved Book counter and Puzzle payout flag. Count unique Puzzle-and-coordinate pairs, not scoring subevents. No progress from Given, Clue, zeroed, or Keep Filling fills. A single owned square can make progress in successive Puzzles; never requires three owned squares. Reset progress after payout and ignore remaining fills until next Puzzle. Losing or selling the Marker discards its saved progress; end of Book resets it.

### M20 · Lamp Marker

**Common · N 7 · New**

After a qualifying placement here, if no Clues remain, gain 1 Clue. At most once this Puzzle. Disabled whenever the Boss disables Clues.

**Limit:** 1 actual Clue grant per Puzzle, only from zero remaining Clues.

**Asset:** lightbulb

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Use the existing Clue economy and destination UI. Does not restore Points on the later Clue placement; Onyx rules still apply.

### M21 · Ledger Marker

**Uncommon · N 9 · New**

A qualifying natural placement here earns 2 coins instead of its placement Points. Clear Points still resolve normally. The conversion is mandatory while available and stops after 3 conversions this Puzzle, when later squares score normally.

**Limit:** 3 conversions per Puzzle; maximum 6 coins. Clue or boss-zeroed placements never convert.

**Asset:** equal

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Evaluate eligibility before this Marker zeroes the placement. Only this placement event is zeroed; clear events and other resource effects are not replayed. The source receipt must explicitly show the trade-off.

### M22 · Umbrella Marker

**Uncommon · N 8 · New**

After a qualifying placement here, protect up to 100 Points from the next wrong-placement penalty anywhere this Turn. One protection may be armed at a time; unused protection expires at Turn end. At most 2 protections can be consumed this Puzzle.

**Limit:** 1 armed protection; 2 actual consumptions per Puzzle; never heals old penalties or pays leftover value.

**Asset:** umbrella.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. If Ivory or Insurance already cancels the whole penalty, do not consume this protection. Subtract at most the remaining penalty. No coins/cards/Points are awarded for wrong attempts.

### M23 · Hearth Marker

**Common · N 5 · New**

A qualifying placement here gains +20 placement Points for each orthogonally adjacent square that was blank immediately before the placement. Board edges contribute nothing.

**Limit:** 4 neighbors maximum: +80 per square, at most 9 owned squares per Puzzle.

**Asset:** flame.fill

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Read pre-placement board occupancy, not the solution. A barred but blank neighbor still counts; do not trigger neighboring Markers.

### M24 · Constellation Marker

**Uncommon · N 9 · New**

A qualifying placement here gains +50 placement Points for each other distinct Marker type that has already triggered from an eligible correct placement this Turn, up to 4 types.

**Limit:** +200 per Constellation square; each prior Marker type counted once; reset each Turn.

**Asset:** sparkles

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Track only real eligible player placements. Wrong protections, Clue triggers, triggered follow-up effects and synthetic receipts never add types. It observes others; it never triggers them.

### M25 · Rhythm Marker

**Common · N 7 · New**

A qualifying placement here gains +25 placement Points for each uninterrupted eligible correct placement immediately before it this Turn, capped at 6. Any wrong placement, Clue use, Toss, or Turn end resets the streak.

**Limit:** Streak contribution capped at 6, so +150 per Rhythm square; no same-event counting.

**Asset:** metronome

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Track player actions, not individual row/column/box receipts. Item-caused draws do not reset the streak; voluntary Hand exchanges do reset it.

### M26 · Bridge Marker

**Common · N 6 · New**

A qualifying placement here gains +60 placement Points for each opposite pair of adjacent squares already filled by the player: left-and-right, or above-and-below. Givens and Clue-filled neighbors do not count.

**Limit:** 2 axes maximum: +120 per square; each owned square once per Puzzle.

**Asset:** link

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Use fill provenance from the pre-placement Board. Neighbors are observations only; never invoke their Marker effects.

### M27 · Crossroads Marker

**Uncommon · N 10 · New**

The first qualifying placement on Crossroads that simultaneously completes at least 2 of its row, column, and box adds +300 placement Points. This bonus can occur once per Puzzle.

**Limit:** 1 payout per Puzzle; +300 regardless of whether 2 or 3 units finish.

**Asset:** plus

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Read completedUnitCount after filling; add to the placement event once. Does not create an extra Line Clear, and cannot defeat The Mirror’s zeroed clear events.

### M28 · Voucher Marker

**Common · N 6 · New**

Each qualifying placement here reduces the price of the first paid Reroll in the next Shop by 1 coin, up to 2 coins. The discount cannot make a price negative and expires when that Shop closes.

**Limit:** 2 total discount coins between Shop visits; only first paid Reroll is discounted.

**Asset:** ticket

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW saved run-level discount field, consumed atomically by the next Shop’s first paid reroll. Existing free rerolls do not consume it. No token occupies a Buff slot and unused credit never pays out as coins.

### M29 · Interest Marker

**Uncommon · N 8 · New**

Each qualifying placement here raises this Puzzle’s cash-out interest cap by 1 coin, up to +2. Normal interest calculation still determines how much you earn. The Collector still prevents all interest.

**Limit:** +2 interest-cap points per Puzzle; no interest guarantee or floor.

**Asset:** percent

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW payout modifier, consumed with the saved payout receipt. Do not award interest during trigger; recomputation after payout must not duplicate coins. Zero under The Collector.

### M30 · Pledge Marker

**Uncommon · N 8 · New**

After a qualifying placement here, you may pay 2 coins to add +100 placement Points to that placement. Pay only if your current balance can cover the full cost. At most 3 payments this Puzzle.

**Limit:** 3 purchases per Puzzle, 2 coins each; no debt allowed; decline means ordinary scoring.

**Asset:** A single coin outline with one small downward arrow tip immediately beneath it; no balance scales

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Show one compact optional choice before event resolution; save pending decision to prevent duplicate purchases. Boss fee resolves first for affordability. Do not offer for a Clue or zeroed placement.

### M31 · Collection Marker

**Common · N 6 · New**

Collect the digits used in qualifying fills of Collection squares across Puzzles in this Book. When 3 different digits have been collected, gain 4 coins and clear the collection. Further Collection fills this Puzzle do not add progress; an unfinished collection carries into the next Puzzle.

**Limit:** 1 four-coin payout per Puzzle; 0–2 collected digit identities can carry across Puzzles; a digit counts once per collection.

**Asset:** tray.full

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW saved Book-level 9-bit digit set and Puzzle payout flag. A single owned square can contribute different digits in successive Puzzles. Clear the set at payout; ignore further progress until next Puzzle. No progress from draw effects, Clues, zeroed events, Givens, or Keep Filling. Selling or losing the Marker discards unfinished progress. Proposed payout is 4 rather than 2 coins so completing three fills is not strictly worse than Azure’s three immediate coins; still capped once per Puzzle.

### M32 · Debt Marker

**Common · N 5 · New**

After a qualifying placement here, if your coin balance is below zero, cancel up to 2 coins of that debt. The balance can rise no higher than zero. At most 6 debt coins can be cancelled this Puzzle.

**Limit:** 6 debt coins cancelled per Puzzle; no payout at zero or positive balance.

**Asset:** minus.circle

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Resolve after the placement’s boss coin charge and other current coin effects. Cap the adjustment by abs(min(balance,0)); do not refund earlier shop purchases or award a positive surplus.

### M33 · Stipend Marker

**Uncommon · N 8 · New**

The first qualifying placement here opens a contract: win this Puzzle without using another Clue to receive 4 extra cash-out coins. Any later Clue use breaks the contract. It cannot be restarted in this Puzzle.

**Limit:** 1 contract and one 4-coin payout per Puzzle; loss or later Clue use pays nothing.

**Asset:** banknote

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Track actual Clue spending, including revealClue and Buff-granted Clues. Litmus-like non-Clue assistance must be explicitly classified; default solution-reveal assistance breaks this contract too. Save award in payout receipt.

### M34 · Route Marker

**Uncommon · N 9 · New**

After a qualifying placement here, make your next 2 eligible correct placements in 2 different boxes, both different from this square’s box, before this Turn ends. Add +120 placement Points to the second follow-up. A placement in a repeated box, wrong placement, Clue, or Toss breaks the route.

**Limit:** 1 live route; 2 successful routes per Puzzle; another Route square cannot replace a live route.

**Asset:** custom: three filled nodes connected by two straight route segments

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW one-deep contract storing source box and next box. Check existing contract before arming a new one; a follow-up may also use its own Marker normally but cannot recursively trigger this source.

### M35 · Ladder Marker

**Common · N 7 · New**

After a qualifying placement here, your next 2 eligible correct placements this Turn must use successively larger digits. Add +90 placement Points to the second follow-up. A non-increasing placement, wrong placement, Clue, or Toss breaks the ladder.

**Limit:** 1 live ladder; 2 completed ladders per Puzzle; naturally impossible to arm usefully from 8 or 9.

**Asset:** ladder

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW one-deep contract stores last digit and steps completed. Do not manufacture legal placements or expose the solution; player chooses the route. A later Ladder placement does not overwrite an active contract.

### M36 · Counterweight Marker

**Common · N 6 · New**

After a qualifying placement here, if your very next eligible correct placement this Turn has a digit that sums to 10 with this digit, add +70 Points to that next placement. Any other placement, wrong attempt, Clue, Toss, or Turn end breaks the pair.

**Limit:** 1 pending pair; 3 successful pairs per Puzzle. Same pair cannot reward twice.

**Asset:** custom: balanced two-pan scales

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Store source digit, not a Hand index. Resolve and consume the old pair before considering a new activation. Wrong attempts never generate consolation rewards.

### M37 · Keystone Marker

**Uncommon · N 10 · New**

After a qualifying placement here that leaves its box unfinished, the next natural scoring clear of that same box gains +120 clear Points. The promise lasts for this Puzzle. Only one box promise may be active at a time.

**Limit:** 1 active box promise; 2 successful payouts per Puzzle; a Clue-completed or zeroed box expires unpaid.

**Asset:** square.dashed

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW unit identity state; only its actual box-clear receipt may consume it. Rows and columns do not qualify. An activation that already completes its box cannot arm a retroactive promise.

### M38 · Finale Marker

**Rare · N 12 · New**

If a qualifying placement here locks the ninth and final copy of its digit onto the board, add +800 placement Points. Givens count toward the nine. This can pay for at most 2 digits per Puzzle.

**Limit:** 2 digit-completion payouts per Puzzle, maximum +800 placement Points.

**Asset:** flag.checkered

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Use boardCountBefore == 8 and a per-digit paid bitset. Never create a Line Clear event for finishing a digit set.

### M39 · Crosscheck Marker

**Common · N 5 · New**

After a qualifying placement here, choose one blank square in this box to inspect its candidates from visible row, column, and box rules. The reading updates as the board changes and closes at Turn end. It does not identify the true solution. At most 2 readings this Puzzle.

**Limit:** 1 live inspected square; 2 readings per Puzzle; no target means no charge used.

**Asset:** checkmark.seal

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW selection/inspection hook. Candidate calculation may read visible locked digits only, never Board.solution. Use the existing hold/inspection presentation; no bonus bar and no persistent marker stamp on the target.

### M40 · Carbon Marker

**Uncommon · N 8 · New**

A qualifying placement here gains extra placement Points equal to the combined ordinary digit base Points of your previous 2 eligible correct placements this Turn. With only one earlier placement, copy that one; with none, add nothing. Never copy bonuses or multipliers.

**Limit:** Up to +180 per square; fewer prior events reduce the bonus; at most 9 owned squares per Puzzle.

**Asset:** square.on.square

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. Remember the previous two natural digits, not final score or Violet override. Zeroed/Clue events are excluded from history. Carbon never invokes the prior Marker, Bookmark, draw, or coin effects.

### M41 · Pressmark Marker

**Uncommon · N 9 · New**

After a qualifying placement here, the next 3 eligible correct placements elsewhere this Turn each gain +20 placement Points. The source placement does not receive this bonus. Only one Pressmark run may be active; at most 2 runs can be armed this Puzzle.

**Limit:** 1 active run; 2 runs per Puzzle, at most +120 Points; expires at Turn end.

**Asset:** printer

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW saved remaining-use counter; consume only on positive natural placements. Another Pressmark square while active does not extend, stack, or queue another run. Aura awards cannot trigger Marker hooks.

### M42 · Tiebreaker Marker

**Rare · N 12 · New**

After a qualifying placement here, if 1–3 unblocked cards remain in Hand, offer a challenge: correctly place all of those exact cards before this Turn ends to add +250 Points to the last one. A wrong play, Clue, Toss, exchange, or manual Turn end fails the challenge; later draws do not add cards to it.

**Limit:** 1 active challenge; 1 successful payout per Puzzle; requires 1–3 eligible remaining cards.

**Asset:** checklist

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW stable identity needed for individual drawn cards, beyond current digit-array indices. Declining leaves normal play. No hidden solution guarantee; no challenge if any captured card is barred. Card identity is significant implementation cost.

### M43 · Blotter Marker

**Uncommon · N 8 · New**

The first wrong placement on a Blotter square each Puzzle returns that card to the Hand and cancels its score penalty, but locks that square against further attempts until the next Turn. Later wrong placements use normal rules.

**Limit:** 1 interception per Puzzle across all Blotter squares; never rewards the wrong attempt.

**Asset:** xmark.square

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW defensive eligibility: first wrong attempt on an owned blank square while .playing only. No reward is created, and Keep Filling cannot consume this defensive interception. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. EXCEPTION: this is a NEW defensive wrongPlace hook, not a score/reward hook. Override the general correct-placement trigger. Boss coin fees still apply; do not consume Insurance when this fully cancels the score penalty. Save temporary square lock and honor it for Clues and placement. No target solution or Given changes.

### M44 · Patina Marker

**Uncommon · N 9 · New**

Each coordinate owned by Patina remembers how many earlier Puzzles you filled it with a qualifying placement. Its placement now gains +25 Points per remembered success, up to +200. After this fill, add one success for future Puzzles; this Puzzle cannot count twice.

**Limit:** 8 remembered successes per owned coordinate; 1 growth step per coordinate per Puzzle.

**Asset:** spiral

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW run-level map keyed by owner type and coordinate. Given-covered Puzzles give no growth. Replacing ownership erases that coordinate’s Patina history; reacquiring cannot restore sold progress. Reset at Book end.

### M45 · Windlass Marker

**Uncommon · N 9 · New**

After a qualifying placement here, you may spend 1 remaining Toss allowance to draw 2 random Pool cards. Do not return any Hand card. At most 2 activations this Puzzle. Cannot be used when a rule disables Tosses.

**Limit:** 2 paid conversions per Puzzle; if Pool has 1 card, draw 1 for the same cost; empty Pool gives no offer.

**Asset:** gearshape

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW allowance-spending action distinct from a tossed card: do not increment any count that claims an actual card was tossed. Maintain a separate allowance-spent count or equivalent accounting. Boss and Obstacle no-Toss locks remain absolute.

### M46 · Beacon Marker

**Uncommon · N 10 · New**

After a qualifying placement here, remember its digit. The next 2 eligible correct placements of that digit elsewhere this Puzzle each gain +40 placement Points. One digit may be watched at a time, and at most 2 Beacon watches can be started per Puzzle.

**Limit:** 1 active watched digit; 2 watches per Puzzle, maximum +160 Points. No stacking or refresh while active.

**Asset:** custom: short radio mast with one curved signal arc each side

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW saved digit and uses. Source placement never spends a watch it just armed; resolve a previous watch first. No card duplication, no solution mutation, and no reactivation from added Points.

### M47 · Sweep Marker

**Common · N 6 · New**

After a qualifying placement here, you may choose a digit and return up to 2 unblocked copies of it from your Hand to the Pool without drawing replacements or spending Toss allowance. At most 2 sweeps this Puzzle. No-Toss rules also forbid Sweep.

**Limit:** 2 sweeps per Puzzle; at most 4 cards returned. Only actual held, unblocked copies qualify.

**Asset:** broom

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW free-Toss batch action; increment actual tossed-card statistics but not paid allowance. Resolve the complete batch before empty-Hand auto-end, once. Explicitly honor no-Toss Boss/Obstacle rules.

### M48 · Census Marker

**Common · N 5 · New**

After a qualifying placement here, inspect the exact current Pool count of that placed digit until this Turn ends. The count updates as cards move. At most 2 count inspections this Puzzle; a later one replaces the earlier digit.

**Limit:** 1 displayed digit count; 2 inspections per Puzzle; cannot reveal individual solution squares.

**Asset:** A hash tally symbol (#) inside a thin circle; never a numeral

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW information privilege: the current game intentionally hides Pool counts. This is an explicit optional design expansion, not existing behavior. Use contextual inspection near Hand; no permanent bonus bar. Never reveal the sequence or solution.

### M49 · Bounty Marker

**Uncommon · N 9 · New**

After a qualifying placement here, a seeded random unmarked blank elsewhere in this box is selected. If you fill that target with an eligible correct placement before this Turn ends, that placement gains +120 Points. No eligible target means no contract.

**Limit:** 1 active target; 2 successful bounties per Puzzle. Target is never a Given, occupied, marked, or currently barred square.

**Asset:** scope

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW temporary target reference; source inspection can highlight it on demand, with no new persistent glyph or bonus bar. Sample only visible geometry/availability, never solution digits or Hand-solvability. Expire on Turn end, Clue fill, or target zero-score fill. No marker triggers propagate to neighbors.

### M50 · Harvest Marker

**Uncommon · N 10 · New**

After a qualifying placement here, you may return every remaining unblocked Hand copy of that same digit, up to 3 cards, and draw the same number of random Pool cards of other digits. Offer only when enough other-digit cards exist. At most once per Puzzle.

**Limit:** 1 batch per Puzzle, maximum 3 cards; card count conserved; no partial transaction.

**Asset:** custom: three simple grain stalks

**Implementation notes:** Marker remains on its owned board coordinates for the Book; each completed Level grants one additional owned square, capped at 9. One Marker owner per square. Given-covered squares are inactive. NEW eligibility gate: natural, non-Clue correct placement whose placement event would earn positive points before this Marker; .playing only, never Keep Filling. No reward from a zeroed boss event. NEW HOOK required; store counters/contracts in saved Puzzle state and credit the source in score receipts. Any random choice uses a dedicated saved seeded stream; previews never advance it. NEW atomic batch exchange. All replacements exclude the triggering digit and are sampled from actual Pool counts using seeded RNG. Do not select barred Hand cards; does not spend Toss allowance or bypass play bans. Save choice/result together to prevent reroll abuse.


## Buffs

### F01 · Peek

**Common · N 3 · Existing**

Gain 1 Clue for the current Puzzle. Spending the Clue reveals a solution-correct destination for a number in your Hand; that revealed placement scores zero unless Onyx restores its placement points, and its Line Clears still score zero.

**Limit:** One Clue per consumed copy; the gain may stack. Existing engine permits use during Keep Filling, but Paywall and Buffborger prohibit the applicable action.

**Asset:** One ivory eye looking through a small square aperture; fine uniform line on a charcoal token with a gold top edge.

**Implementation notes:** Existing Buffs.peek and Actions.useBuff behavior; preserve actual Clue provenance, reveal guards, and Onyx exception. Price proposal remains 3. Do not portray this as a free scoring placement.

### F02 · Redraw

**Common · N 3 · Existing**

Return every number in your Hand to the Pool, then draw up to your normal Hand refill target (effectiveHandSize) from that Pool. This spends no Toss allowance and can redraw numbers you just returned.

**Limit:** One complete return-and-refill per consumed copy; draw stops when the Pool is empty. Existing engine also permits Keep Filling use.

**Asset:** Three small ivory card corners enclosed by one circular arrow; charcoal and gold family.

**Implementation notes:** Existing Actions.redrawHand atomically returns all tokens before seeded Pool.draw. Hand size is a refill target, not an absolute cap. Preserve the potential to redraw the same digits and do not call Toss hooks.

### F03 · Overtime

**Uncommon · N 7 · Existing**

Increase the current Puzzle's maximum Turns by 2. Existing Hand, queued points, current Turn number, and the normal refill process are unchanged.

**Limit:** Two extra Turns per consumed copy; the existing engine permits repeated copies and Keep Filling use, but not use after terminal failure.

**Asset:** An ivory clock with a small two-stroke extension at its rim; charcoal and gold family.

**Implementation notes:** Existing extraTurns hook; proposed price rises from 4 to 7 because two full Turns are a substantial scarce resource. Do not silently apply a new once-per-Puzzle cap or rewrite existing Keep Filling behavior.

### F04 · Double Down

**Uncommon · N 5 · Existing**

Arm a doubler for the next non-Clue correct placement whose points are not zeroed; double that placement's points only. Clues, wrong placements, and zeroed placements do not spend the armed charge.

**Limit:** One armed charge, expiring at Puzzle end; another copy cannot be consumed while it remains armed. Existing engine rejects use in Keep Filling.

**Asset:** Two matching ivory square outlines offset diagonally, linked by a small multiplication cross; charcoal and gold family.

**Implementation notes:** Existing doubleDown arm flag and scoring-ledger doubler; preserve the non-Clue and zeroed-event guards and the no-stacking use guard. Proposed price 5 replaces current 4.

### F05 · Insurance

**Common · N 3 · Existing**

Cancel the next wrong-placement score penalty that would otherwise apply. The number still follows normal wrong-placement routing to the Pool, or to the Hand if Jade supplies that separate effect.

**Limit:** One armed charge until Puzzle end; cannot arm a duplicate copy. Existing engine rejects use in Keep Filling and does not waste the charge on an already-waived penalty.

**Asset:** An ivory shield surrounding a small minus sign; charcoal and gold family.

**Implementation notes:** Preserve Actions.resolveWrong resolution order: square protection, held protection, then Insurance. The accepted placement can still incur a boss coin fee; this Buff cancels the score penalty only.

### F06 · Second Print

**Uncommon · N 5 · Existing**

Double the next non-Clue Line Clear whose points are not zeroed. If one placement completes several units, only the first eligible unit in the engine's existing resolution order consumes this charge.

**Limit:** One charge until Puzzle end; no duplicate arming and no Keep Filling use under the existing engine.

**Asset:** Two short parallel ivory completed-line strips, each containing three square cells; charcoal and gold family.

**Implementation notes:** Existing secondPrint flag; do not multiply all three units on a crossing completion. Preserve the rule that Clue Line Clears remain zero even on Onyx. Proposed price 5 replaces 4.

### F07 · Lucky Dip

**Common · N 3 · Existing**

Immediately draw up to 2 random numbers from the Pool into your Hand. Draw fewer if the Pool has only one number left; do not consume the Buff if the Pool is empty.

**Limit:** At most two conserved tokens per copy; can exceed the normal Hand-size refill target. Existing engine permits Keep Filling use.

**Asset:** Exactly two overlapping ivory mystery-number card outlines with tiny question marks; approved Lucky Dip motif, on charcoal with a gold top edge.

**Implementation notes:** Existing Pool.draw with run.streams.pool; retain empty-Pool guard and stop-at-empty semantics. Never fabricate two extra number tokens or introduce a hard Hand cap that deletes overflow.

### F08 · Bird Seed

**Uncommon · N 6 · Existing**

Gain 1 additional coin for each actual Line Clear for the rest of the current Level. One placement completing several units pays once for each completed unit, according to the existing lineClear hook.

**Limit:** Cannot consume another Bird Seed while its Level-long effect is active. Existing behavior includes Clue and Keep Filling clears; a finite unit cannot be cleared repeatedly.

**Asset:** Three ivory seed dots dropping into three adjacent square cells; charcoal and gold family.

**Implementation notes:** Existing runItemState Level stamp and activeBuffSources provenance. Proposed price 6 replaces 4. Do not incorrectly apply new non-Clue eligibility to this unchanged existing coin hook.

### F09 · Fresh Ink

**Rare · N 9 · Existing**

Add 2 to Puzzle Mult before Bookmark multipliers for the remainder of the current Puzzle, including the current Turn. It changes multiplier calculation and does not create placement or clear points by itself.

**Limit:** Puzzle-scoped; the existing engine allows repeated copies to add another 2 each time and rejects Keep Filling use.

**Asset:** One ivory ink drop over two short rising strokes; charcoal and gold family.

**Implementation notes:** Existing puzzle itemState accumulation and scoring provenance. Proposed price 9 replaces current Rare price 4 because duration is much stronger than a one-event Buff. Retain actual stacking unless separately approved for rework.

### F10 · Litmus

**Rare · N 8 · Reworked**

Choose one digit when using Litmus and reveal all still-blank solution-correct squares for that digit. The chosen digit cannot change, and the reveal ends after the next accepted correct or wrong placement, or at Puzzle end.

**Limit:** One locked digit per consumed copy; cannot arm a second active Litmus. Invalid or barred attempts do not spend the reveal, and the overlay never makes barred squares playable.

**Asset:** An ivory narrow test strip with three outlined test squares, one filled; charcoal and gold family.

**Current ability being replaced:** Select a number to reveal which blank squares it belongs in. Spent when you place a number

**Implementation notes:** New selected-digit persistence is required: the current armed flag allows changing the inspected digit before placement, potentially exposing the whole solution. Proposed rework locks the selection. Retain normal manual-placement scoring rather than silently converting this paid reveal to a Clue; separately expose this policy in the guide. Proposal restricts activation to playing and blocks it under Paywall as solution-backed assistance; both are deliberate changes, not claims about current behavior.

### F11 · Paper Crane

**Uncommon · N 6 · Existing**

Choose one digit and add 50 flat placement points to that digit's scoring placements for the rest of the current Puzzle. Ordinary Clue zeroing still applies; Onyx can restore the placement, including applicable flat bonuses.

**Limit:** Puzzle-scoped digit modifier; repeated existing copies may stack, including on the same digit. Existing engine rejects Keep Filling use.

**Asset:** A simple ivory folded-paper crane profile made from five angular strokes; charcoal and gold family.

**Implementation notes:** Existing paperCraneKey(digit) state and placeSquare flat addition. Proposal reclassifies Common/3 to Uncommon/6 for duration and stacking strength without changing the ability. Preserve clue/Onyx behavior instead of assigning new-item non-Clue rules to an unchanged existing hook.

### F12 · Index Request

**Uncommon · N 5 · New**

Choose a digit with at least one copy remaining in the Pool and take exactly one copy into your Hand. This neither identifies a correct square nor bypasses any boss restriction on using the drawn card.

**Limit:** One real Pool token per copy; do not consume for an empty Pool or unavailable digit. No Keep Filling activation.

**Asset:** An ivory card entering a hand tray beneath a single downward index arrow; charcoal and gold family.

**Implementation notes:** NEW HOOK: validated digit selector plus Pool.take. Display available digits only after entering the consumed-choice flow, without showing solution locations. Commit Buff removal and token transfer atomically; counts remain Pool+Hand=remaining blanks.

### F13 · Careful Cut

**Common · N 3 · New**

Choose one to three tossable cards in your Hand and return them to the Pool without spending Toss allowance. Do not draw replacements; if this empties the Hand, finish the atomic action before running the normal automatic end-of-Turn path once.

**Limit:** At most three cards per copy; requires a legal nonempty selection, respects boss Toss locks, and is unavailable in Keep Filling.

**Asset:** Ivory scissors trimming a three-card fan, with one card remaining beyond the cut; charcoal and gold family.

**Implementation notes:** NEW HOOK: separate returnCards action, not repeated Actions.toss calls. Do not spend Tosses or fire paid-Toss reward hooks; adjust blocked-card identities atomically and check conservation after all returns.

### F14 · Eraser Shavings

**Common · N 4 · New**

Restore up to two Tosses already spent in this Puzzle. Remaining Tosses cannot rise above this Puzzle's originally granted allowance, and no card moves until you later choose to Toss it normally.

**Limit:** Only previously spent charges can be restored; do not consume at the allowance ceiling or in Keep Filling.

**Asset:** An ivory eraser above two tiny curled shavings; charcoal and gold family.

**Implementation notes:** NEW HOOK: explicit grantedTossAllowance and restoredTosses counters. Never decrement lifetime tossedThisPuzzle statistics to implement a refund, since score contracts and analytics may depend on actual Toss history.

### F15 · Collation

**Uncommon · N 5 · New**

Reveal a seeded sample of up to three tokens from the Pool and arrange the order in which those tokens will be drawn next. They remain part of the Pool until actually drawn; a targeted take of a reserved token removes that token from this short draw schedule.

**Limit:** One pending schedule at a time, at most three tokens, expiring at Puzzle end; no empty-Pool or Keep Filling use.

**Asset:** Three ivory staggered cards labeled by one, two, and three dots, with an ordering arrow; charcoal and gold family.

**Implementation notes:** NEW HOOK: deterministic draw schedule over Pool counts, not a hidden extra inventory. Use the pool RNG once when committing the sample; scheduled draws consume no second random sample. Specific Pool.take removes a matching scheduled reservation first. Save this schedule and RNG state together; preserve conservation and rollback behavior.

### F16 · Fair Exchange

**Common · N 4 · New**

Return one chosen tossable Hand card and take one different chosen digit that was already in the Pool before the return. Hand count stays unchanged, and no Toss allowance is spent.

**Limit:** Exactly one card each way; must respect Toss locks and have a different eligible Pool digit. No Keep Filling use.

**Asset:** Two ivory single cards with opposed horizontal arrows between them; charcoal and gold family.

**Implementation notes:** NEW HOOK: atomic prevalidated Pool.take plus Pool.put and Hand replacement, with a distinct exchange event rather than Toss rewards. Preserve card lock identity and invalidate one matching Collation reservation if taken.

### F17 · Inventory Count

**Common · N 3 · New**

Reveal the exact remaining Pool count of each digit for the current Turn, updating after every legal token transfer. Hide the counts again when that Turn ends; no solution positions are revealed.

**Limit:** One active overlay; do not consume a duplicate while active. No Keep Filling use and no free pre-consumption count preview.

**Asset:** An ivory abacus-like row of three short tally columns inside a ledger outline; charcoal and gold family.

**Implementation notes:** NEW HOOK: scoped Pool-count visibility. Pool.swift intentionally keeps these counts hidden today, so this is an explicit new information ability; counts are also theoretically deducible from board and Hand. Do not query Board.solution to implement the overlay.

### F18 · Proof Sheet

**Common · N 3 · New**

Choose one row, column, or box and show the digits allowed by the visible Sudoku constraints in each of its blank squares until the current Turn ends. Candidates update as numbers are placed, but they are possibilities, not promises of the stored solution.

**Limit:** One annotated unit at a time, no duplicate activation or Keep Filling use; does not reveal fogged values or lift barred squares.

**Asset:** An ivory three-by-three mini grid with three small candidate dots inside its center cell; charcoal and gold family.

**Implementation notes:** NEW HOOK: candidate calculation over visible fixed values only. Hidden/fogged contents cannot secretly eliminate candidates. Keep candidate overlays inside an optional inspection view to avoid permanent board clutter and label them as candidates.

### F19 · Fold Test

**Common · N 3 · New**

Choose one blank square and learn whether its solution digit is odd or even. Keep that parity note until the square is filled or the Puzzle ends; it gives partial solution information without naming a digit or automatically placing one.

**Limit:** One note per consumed copy; do not consume on a filled, given, already parity-revealed, or currently barred square. Paywall and Buffborger block use; no Keep Filling use.

**Asset:** An ivory folded square split into a three-dot half and a two-dot half; charcoal and gold family.

**Implementation notes:** NEW HOOK: explicitly solution-backed partial reveal with persisted parity annotation. This paid information is not a Clue placement and does not mark the eventual placement as Clue; that proposed policy must be stated openly. Repeated uses on different cells cost separate consumed copies.

### F20 · Rebind

**Uncommon · N 7 · New**

Move one claimed coordinate of an owned Marker from an untriggered blank square to a different blank, unmarked square; all other coordinates owned by that Marker stay in place. The move persists for later Puzzles in this Book, preserving Marker-type counters and moving the selected claim record, including its history and spent state, without any reset.

**Limit:** One claimed coordinate moved per copy; source and destination must both be blank and unbarred, and that source claim must not have triggered this Puzzle. No Keep Filling use; the Marker’s other claimed squares are unchanged.

**Asset:** An ivory marked square connected by a curved binding arrow to an empty square; charcoal and gold family.

**Implementation notes:** NEW HOOK: claim-record relocation with per-coordinate, per-Puzzle activation provenance. Replace exactly one coordinate in the owning Marker’s squares, preserving its type-level counters, entitlement, and purchase provenance. Move all claim-specific history, including Patina history and spent flags, with that claim record; never reset it because the coordinate changed. Given or filled source squares are ineligible. Commit the move atomically.

### F21 · Transposition

**Uncommon · N 5 · New**

Swap exactly one claimed coordinate from each of two different owned Marker types, with both selected claims on blank squares and neither having triggered this Puzzle; each type’s other claims stay in place. Preserve both types’ counters and move each selected claim record, including its history and spent state, to its exchanged coordinate without resetting it.

**Limit:** One two-claim swap per copy; selected squares must be distinct, blank, and unbarred, and neither source claim may have triggered this Puzzle. No Keep Filling use or counter reset; all unselected claims remain unchanged.

**Asset:** Two ivory marked cells with crossing curved arrows above and below them; charcoal and gold family.

**Implementation notes:** NEW HOOK: atomic pair-claim swap with per-coordinate, per-Puzzle activation guards. Exchange exactly one coordinate in each owning Marker’s squares; keep type-level counters with their types, and carry each selected claim’s full history, including Patina and spent flags, to its new coordinate. Do not remove and repurchase a Marker, reset entitlement, trigger sale/purchase rewards, or alter other claims. Reject selecting the same Marker type twice because that would make no effective exchange.

### F22 · Passage

**Uncommon · N 6 · New**

Choose one blank square currently barred by a boss and permit one accepted placement there during this Turn. The exception ends after a correct or wrong accepted placement, or at Turn end, and all number restrictions, coin fees, penalties, and scoring rules still apply.

**Limit:** One square and one accepted attempt; requires a current boss square bar. Buffborger still prevents activation; no Keep Filling use.

**Asset:** An ivory square gate with one short opening and an arrow passing through; charcoal and gold family.

**Implementation notes:** NEW HOOK: per-square one-attempt override in placement validation. Does not alter the boss's original barredSquares set, the next Turn's random selection, or Hand-card blocks. Invalid hand indices and other rejected actions do not consume the permission.

### F23 · Release Note

**Uncommon · N 5 · New**

Choose one currently blocked card in your Hand and permit one placement or Toss of that exact card during this Turn. The exception bypasses its Hand/digit block only; a barred square, Toss cost, placement fee, and ordinary correctness rules still apply.

**Limit:** One exact token until used or Turn end, with no spillover to other copies of its digit. No Keep Filling use; Buffborger blocks activation.

**Asset:** An ivory card with a tiny open padlock hanging from one corner; charcoal and gold family.

**Implementation notes:** NEW HOOK: stable Hand-token identity or equivalent safe index remapping. Existing Hand is a Digit array, so the permission must never jump to another card when indices shift. Resolve boss square bars independently.

### F24 · Single Issue

**Common · N 3 · New**

In an open Shop, replace one chosen unsold offer with a different seeded item of the same category and rarity, at that rarity's normal proposed price. Keep the other stock and the Shop's regular Reroll counter unchanged.

**Limit:** One replacement per copy; exclude the old definition, owned Bookmarks, and same-stock duplicate Bookmarks/Markers. Do not consume if no alternative exists.

**Asset:** One ivory price-tag outline encircled by a small refresh arrow; charcoal and gold family.

**Implementation notes:** NEW SHOP-USE HOOK: Actions.useBuff currently accepts only playing/Keep Filling, so this requires a separate validated Shop Buff action. Use the Shop RNG and current visit provenance; selecting does not buy the new item.

### F25 · Reservation

**Uncommon · N 5 · New**

As you leave an open Shop, reserve one unsold offer at its current price for the next Shop you reach. It replaces one normal slot of the same category there and remains through that visit's Rerolls until purchased or until you leave that next Shop.

**Limit:** One pending reservation for the Book; expires after the next reached Shop visit or Book end. No reserved inventory item or coins are granted.

**Asset:** An ivory price tag tucked behind a small calendar corner; charcoal and gold family.

**Implementation notes:** NEW SHOP/ROUTE HOOK: persisted reserved offer with defID, price, category, source visit, and destination visit. Cannot consume a duplicate reservation. Apply ownership exclusions before the next stock is displayed and keep a single physical stock slot rather than duplicating the offer. If no later Shop is reachable, reject use.

### F26 · Counteroffer

**Common · N 3 · New**

Reduce one chosen unsold Marker's price in the current Shop by 4 coins, to a minimum price of 1. The reduction belongs to that offer until it is bought or rerolled; it does not grant coins or apply to Buff purchases.

**Limit:** At most one Counteroffer per Shop visit and no stacking on an offer; do not consume if the price cannot fall. Expires with that stock or Shop.

**Asset:** An ivory outlined price tag crossed by a small downward negotiation arrow; charcoal and gold family.

**Implementation notes:** NEW SHOP-USE HOOK: store the actual discounted purchase price as pricePaid so resale never uses the undiscounted price. Cap to one use per visit to avoid repeat discount loops. Buying this at 3 can save at most 4, a bounded one-coin net benefit.

### F27 · Supplement

**Common · N 4 · New**

Choose Bookmarks, Markers, or Buffs; add one extra offer of that category to the initial stock of the next Shop you reach. It must still be purchased at its normal price and disappears on that visit's first Reroll or when you leave.

**Limit:** One pending Supplement; one extra offer only, with no guarantee of rarity or availability if its catalog is exhausted. No Keep Filling activation.

**Asset:** An ivory extra page sliding beside a three-page stack; charcoal and gold family.

**Implementation notes:** NEW ROUTE/SHOP HOOK: category-tagged pending extra stock slot, seeded from Shop RNG, saved once. Keep the normal 2/2/1 composition intact and apply all owned/stock exclusions; this temporary sixth offer requires explicit Shop layout support. Never recursively generate another Buff reward.

### F28 · Free Press

**Common · N 3 · New**

Apply up to 6 coins of credit to the next paid regular Reroll in the current Shop. Charge any cost above 6 normally, then advance the Reroll counter exactly as if its full price had been paid.

**Limit:** One armed credit per visit; expires when leaving. Free Rerolls do not spend it; unused credit never becomes coins, and it cannot stack with another copy.

**Asset:** An ivory full-circle refresh arrow around a small ticket notch, unlike Single Issue's single price tag; charcoal and gold family.

**Implementation notes:** NEW SHOP-USE HOOK: apply a noncash discount to Shop.reroll payment only. Store regular underlying cost and increment rerollsUsed normally; do not reset escalation or refund unused credit. This cannot create money or perpetually fund itself.

### F29 · Detour

**Rare · N 8 · New**

Before starting a non-boss Puzzle, inspect its normal given layout and one seeded alternative with the same slot, difficulty, target, and resource rules, then choose which layout to play. Your Marker coordinates stay fixed, and only givens—not solutions—are previewed.

**Limit:** Once per Puzzle slot, with exactly one alternative; consume when the two-layout choice is revealed, including if you keep the original. No boss reroll, skip reward, or extra Shop is created.

**Asset:** Two ivory small grid outlines on a forked path, one arrow selecting the alternate; charcoal and gold family.

**Implementation notes:** NEW BRIEFING/GENERATOR HOOK: deterministic alternate-board domain seed and persisted choice, with equivalent generator constraints and uniqueness checks. Never reroll the Level's boss, payout, shop stock, or skip reward as a side effect. Current Actions.useBuff cannot run here.

### F30 · Boss Draft

**Rare · N 10 · New**

Before entering the current Level's boss Puzzle, reveal one different seeded eligible boss and choose between it and the already announced boss. The board generation, target, and rewards remain those of the same boss slot; the chosen boss's own normal resource modifiers still apply.

**Limit:** One two-boss choice per Level; consumed on reveal even if you keep the original. It cannot change an active boss or skip the encounter.

**Asset:** An ivory boss-page silhouette with two alternative tabs and one small selection check; charcoal and gold family.

**Implementation notes:** NEW ROUTE HOOK: alternate draw excludes the announced boss and uses a dedicated deterministic domain. Persist chosen pendingBoss, preserve boss-board seed and slot identity, and recompute legitimate selected-boss modifiers only on puzzle creation. No use during Buffborger; briefing use happens before an encounter exists.

### F31 · Tight Deadline

**Uncommon · N 6 · New**

Permanently remove one future Turn from the current Puzzle's allowance to add 3 Mult before Bookmarks to the eligible non-Clue portion of this Turn's bank. Clue-derived points and zeroed events receive no bonus; the modifier expires after this bank even if it cannot apply.

**Limit:** Once per Puzzle; requires at least one future Turn beyond the current Turn to sacrifice. No Keep Filling or out-of-Turns use.

**Asset:** An ivory clock edge clipped by a small scissor blade beside three short rising strokes; charcoal and gold family.

**Implementation notes:** NEW HOOK: explicit turnsMax reduction plus current-turn eligible-point partition and additive Mult provenance. Do not decrement turnNumber, trigger boss selection, or refill Hand. A simple global pendingMult addition is insufficient when the queue mixes eligible events with Onyx-restored Clue points: only the non-Clue portion receives this extra +3 stage.

### F32 · Collateral

**Rare · N 8 · New**

Before any scoring event in a Turn, suspend one currently active owned Bookmark for the rest of this Puzzle to increase the normal Hand-size refill target by 2. The Bookmark stays owned in its slot and returns at Puzzle end; already queued rewards and its stored growth are not erased.

**Limit:** Once per Puzzle; requires an owned active Bookmark and cannot target a boss-disabled one. No immediate draw, Keep Filling use, sale, or replacement of the pledged instance while suspended.

**Asset:** An ivory bookmark held by a small clasp beside two extra card corners; charcoal and gold family.

**Implementation notes:** NEW HOOK: source-specific temporary suspension, persistent suspended UUID, and +2 refill-target modifier. Activate before turn scoring order locks; suppress both passive and event hooks of that source without resetting its counters. Restore ownership functionality on win/failure or save recovery.

### F33 · Exchange Rate

**Common · N 3 · New**

Pay one to three coins when using this Buff to gain the same amount of additional Mult before Bookmarks on the eligible non-Clue portion of the current Turn's bank. Clue-derived points and zeroed events receive no bonus, and this modifier creates no points on its own.

**Limit:** Once per Puzzle, maximum 3 coins and +3 Mult; no debt, refund, Keep Filling use, or zero-payment consumption.

**Asset:** One ivory coin outline transforming through a short arrow into multiplier spokes; charcoal and gold family.

**Implementation notes:** NEW HOOK: atomic coin payment plus current-turn eligible-point partition. The Buff's shop price is separate from the chosen payment. Do not fire coin-gain hooks, refund coins when the queue is zeroed, or let a global multiplier amplify Onyx-restored Clue points; only eligible non-Clue points receive the extra additive Mult stage.

### F34 · Return Receipt

**Uncommon · N 5 · New**

Cancel one still-unspent Insurance, Double Down, or Second Print charge that came from a Buff you consumed in this Puzzle, and return that exact original Buff instance to your inventory. This does not rewind any action or recover an effect that has already triggered.

**Limit:** One original instance per use; consuming Return Receipt frees its own inventory slot for the recovered item. No Keep Filling use, anonymous flags, partial recoveries, or copies of this Buff.

**Asset:** An ivory receipt with one return arrow pointing back to a small token outline; charcoal and gold family.

**Implementation notes:** NEW HOOK: archive spent OwnedBuff instances rather than only UUID strings, with exactly-once recovery status. Preserve original UUID, pricePaid, and shop provenance; clear flag and provenance atomically. Cannot duplicate a source or undo prior payouts.

### F35 · Clean Finish

**Uncommon · N 5 · New**

Commit your current Hand of at least three cards: if every one of those exact cards is correctly placed for positive non-Clue placement points before this Turn ends, add 150 flat points when the last tracked card resolves. Any wrong placement, Toss, exchange, return, or Clue placement of a tracked card fails the challenge.

**Limit:** One active challenge and one reward per Puzzle; at least three tracked cards, no Keep Filling use. Newly drawn cards are not tracked and do not increase the reward.

**Asset:** Three ivory card outlines funneling into a single clean checkmark; charcoal and gold family.

**Implementation notes:** NEW HOOK: stable card identities, challenge membership, and action invalidation. Award before the normal empty-Hand auto-end path so the existing bank includes it. Boss-zeroed or Clue-scored tracked cards fail rather than secretly satisfying the challenge.

### F36 · Cross-Cut

**Uncommon · N 6 · New**

Arm a reward for one non-Clue placement that completes at least two eligible scoring units at once; add 120 flat points for two units, or 180 for three. All counted row, column, or box clears must have positive nonzeroed points, and the placement itself must also be eligible.

**Limit:** One reward until Puzzle end; ordinary single clears leave it armed. No duplicate arming or Keep Filling use.

**Asset:** One ivory row and column crossing at a small filled square, with a box outline behind; charcoal and gold family.

**Implementation notes:** NEW HOOK: post-resolution completed-unit receipts, counted once per placement. The flat reward is queued once after confirming actual scoring eligibility, before auto-end; it does not fire fake Line Clear hooks or pay per repeated callback.

### F37 · Open Bracket

**Uncommon · N 5 · New**

Choose two distinct unbarred blank squares in different boxes; if both receive eligible positive-point non-Clue placements before this Puzzle ends, add 200 flat points to the second completion. The contract fails if either chosen square is filled by a Clue or a zeroed placement.

**Limit:** One active contract and one reward per Puzzle; no Keep Filling use. Wrong attempts do not complete targets and retain their ordinary penalties.

**Asset:** Two ivory opposite brackets enclosing two small separated cell dots; charcoal and gold family.

**Implementation notes:** NEW HOOK: persisted target-square pair with completion/failure bits. Do not reveal either target's solution or add permanent Marker objects; use a quiet temporary inspection cue compatible with hold-to-inspect. Pay once on the second eligible receipt.

### F38 · New Edition

**Uncommon · N 6 · New**

In an open Shop, replace one chosen owned Bookmark with a seeded different unowned Bookmark of the same rarity. The new Bookmark occupies the same inventory position with fresh counters; no coin refund, sale reward, purchase reward, or higher-rarity guarantee is granted.

**Limit:** One replacement per copy; requires an eligible alternative and an unpledged Bookmark. Does not operate during a Puzzle or recover the old item's growth.

**Asset:** An ivory bookmark silhouette changing to a second differently-notched bookmark through a short arrow; charcoal and gold family.

**Implementation notes:** NEW SHOP-USE/INVENTORY HOOK: seeded definition transformation, new stable instance identity, pricePaid=0, no purchase provenance, and reset definition-specific counters. Retire the old instance fully, invalidate same-definition unsold offers according to the normal owned-Bookmark rule, and do not fire buy/sell hooks.

### F39 · Carbon Receipt

**Uncommon · N 6 · New**

Repeat the immediate effect of the most recently used eligible Buff in this Puzzle: Peek, Redraw, Double Down, Insurance, Second Print, or Lucky Dip. Show which effect will repeat before confirming; the repeated effect must pass its normal guards and uses fresh seeded draws where applicable.

**Limit:** Once per Puzzle; cannot copy itself, another new Buff, Fresh Ink, Paper Crane, Bird Seed, Overtime, or Litmus. Cannot consume when the copied effect would be blocked, redundant, or empty; no Keep Filling use.

**Asset:** Two ivory receipt outlines aligned over a dark carbon layer, one small echo arc; charcoal and gold family.

**Implementation notes:** NEW HOOK: explicit eligible-use history separate from generated effects. Carbon Receipt never becomes a new copy target and never recreates an OwnedBuff; whitelist excludes currency, permanent growth, route actions, and recursive copies. Repeated arming records Carbon Receipt as the source, making it ineligible for Return Receipt recovery of a nonexistent original basic Buff.

### F40 · Rain Check

**Uncommon · N 5 · New**

Choose 20 to 100 of this Turn's queued eligible placement points and remove them from the current bank; on your first eligible positive-point non-Clue placement next Turn, add twice that amount as flat queued points. If no such placement happens during that next Turn, or the Puzzle ends first, the deferred bonus is lost.

**Limit:** Once per Puzzle, maximum 100 deferred and 200 returned; requires a future playable Turn and enough eligible original placement points. No Keep Filling, Line Clear points, other Buff bonus points, or Clue-derived points may fund it.

**Asset:** An ivory ticket with a clock-shaped perforation and an arrow into a second page; charcoal and gold family.

**Implementation notes:** NEW HOOK: provenance-aware queued-point debit and deferred credit. Debited points cannot be spent twice, copied, or counted as having banked this Turn; the return is a Buff bonus and cannot fund another Rain Check. Preserve the loss on early win/skip/failure and never create a synthetic placement or clear event.

