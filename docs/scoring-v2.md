# Scoring version 2 — ordered Sudoku Turns

Status: implementation contract, 19 September 2026. Version 2 is an intentional Sudoku adaptation, not a claim that poker and Sudoku have identical scoring.

## Evidence and boundary

Balatro's [official FAQ](https://www.playbalatro.com/faq) describes scoring poker hands against a round target, distinct Joker abilities, consumables, and separate money. It does not specify detailed calculation order.

[Steamodded's calculation documentation](https://docs.smods.dev/API%20Documentation/Calculate-Functions) is primary documentation for a Balatro integration, not an official LocalThunk rules document. It distinguishes before-scoring, initial values, scored cards, repetitions, held cards, main Joker evaluation, final scoring and after-scoring contexts. Its [historical calculation reference](https://github.com/Steamodded/smods/wiki/Calculate-Functions/a109d5e540a18f1539fb40ed8de4fa733d824a02) explicitly lists the ordered main scoring contexts. The community [activation guide](https://balatrogame.fandom.com/wiki/Guide%3A_Activation_Sequence) corroborates left-to-right evaluation within stages and distinguishes repetitions from a final product multiplier. The integration's [scoring source](https://github.com/Steamodded/smods/blob/main/src/utils.lua) provides direct implementation evidence: `calculate_main_scoring` walks the card area with ordered `ipairs`, and `score_card` repeats a card's evaluation and dependent effects for each repetition. That is materially different from multiplying a completed numeric award. These sources establish why an unordered sum/product is insufficient; all Sudoku mappings below are our design decisions.

## The batch and order

One Turn is one scoring batch. Correct placements contribute Points (the Chips equivalent). End Turn banks the batch exactly once, including automatic End Turn after the last card. Coins are never multiplied into score.

1. Resolve the placed number, then completed row, column, box in that order, then full board. Base Points are `10 × digit`, `45` per unit and `500` for the board.
2. For each event: collect its positional and event-specific flat Points; apply its local multipliers and score doublers; suppress forbidden scoring; floor the event Points and append to the Turn queue. Other effects (draws, coins, growth) fire once. No current item retriggers an event.
3. Seed Turn Mult with 1, preserved historical Overprint if present, Rose's accumulated +Mult, then Fresh Ink's accumulated +Mult.
4. Apply eligible Bookmarks in the player's visible slot order, each `+Mult` or `×Mult` immediately changing the running Mult. Rolling Presses uses its growth *before the most recent scoring event*; growth from an event becomes available to the next event, preserving its printed next-event behavior. Its factor is not multiplied repeatedly for every placement.
5. Apply The Budget Cut / Sashimi's `×0.5` once to the completed Mult.
6. Bank `floor(queued Points × final Mult)`, then apply printed direct payouts (Morning/Evening Edition). Clear the batch. Score cannot fall below zero.

An existing wrong-placement penalty remains explicitly denominated in **queued Points** first: subtract `50 × digit` (twice under The Critic) from queued Points, then subtract any remainder from banked score. Its eventual multiplied impact is visible in the queued total; it is not misrepresented as a flat final-score deduction. Insurance, Ivory and the first-mistake Book can waive it. Keep Filling freezes score and penalties; clear coins continue.

## Ownership, saving and arithmetic

The first correct placement locks a snapshot of Bookmark UUIDs, order, definitions and sleeping identity for this Turn. Scoring hooks continue using that snapshot through End Turn. Selling or reordering updates the visible inventory for the next Turn; it cannot rewrite earned Points or the locked modifier order. Before the first correct placement, arrangement changes affect the upcoming batch. A no-placement Turn evaluates its current inventory when End Turn is pressed.

Buff use remains immediate. Fresh Ink upgrades the current Turn's Mult seed and future Turns; Rose gains apply to the current queued batch and future Turns. Paper Crane changes later placements only. This intentional distinction is shown in effect copy. Unused hand cards have no intrinsic scoring effect; there is no invented poker hand/held-card stage.

Every new Puzzle starts at scoring version 2. A save without a scoring version continues its current Turn under version 1 exactly, including its queued base, best-held Mult and global additive placement. After its first successful bank, subsequent Turns use version 2. Banked score, coins, inventory, Clipping effects/history, skip history, board and random streams are never recalculated. Version and pending ledger are saved with the same Puzzle state; the most recent bank ledger is saved for explanation, never replayed for rewards. Old app binaries can decode additive fields but are not supported to continue a version-2 active Turn; retain backup saves for rollback.

Points, Mult, and newly awarded score saturate at `9,000,000,000,000,000` (below the exact-integer boundary of Double), preventing nonfinite-to-Int traps. Existing larger historical banked Int scores are preserved. Nonfinite/negative modifier input is bounded; event and bank rounding is downward. Fractional Mult is retained until the event/bank boundaries. All intermediate ledger values use the same bounded arithmetic as the result. Economy remains separate.

The HUD, animation and ledger use the same number formatter, retaining up to eleven fractional digits instead of rounding Mult to hundredths. One prior Syndication win, Stop the Presses and Budget Cut produce `1.25 × 3 × 0.5 = 1.875`; a 140-Point Turn banks `floor(262.5) = 262`. Printing 1.88 would incorrectly imply 263. The additional precision also preserves supported historical duplicate builds; ordinary Shop purchases still exclude already-owned Bookmark definitions.

The preview total is the amount that can actually be added to the existing score, before direct bonuses. For example, with only 10 points left below the score ceiling, a 50-Point ×3 batch previews and banks 10. Direct payout operations also record their actual awarded delta, so a saturated Morning Edition reports +0. Optional `scoreLimitApplied` ledger metadata explains a reduced award in the score panel; old saved ledgers without the field still decode. Raw Points and Mult remain available to explain how the uncapped product was formed.

## Complete catalogue mapping

| Bookmark | Version-2 role |
| --- | --- |
|---|---|
| Morning Edition | Direct +100 score after each Turn product, even a no-placement Turn. |
| Evening Edition | Direct +300 after Turn 10 product only. |
| Local Gossip | +30 event Points for each correct placement; clue scoring gate still applies. |
| Sports Section | +25 event Points per row/column/box clear. |
| Society Pages | +500 event Points on full board. |
| Op-Ed Column | Ordered +1 Turn Mult. |
| Editorial Board | Ordered +2 Turn Mult. |
| Front Page Splash | Ordered +1 Mult per Bookmark in locked Turn inventory, including itself. |
| Letters to the Editor | Ordered +3 Mult only on boss puzzles. |
| Rolling Presses | Ordered ×(1 + 0.5 × prior-clear count); growth after each clear, effective at the next scoring event. Resets each Puzzle. |
| Syndication | Ordered ×(1 + 0.25 × prior won puzzles); increments on cash-out, resets each Book. |
| Stop the Presses | Ordered ×3 Turn Mult. |
| The Sunday Supplement | Ordered ×2 Turn Mult, ×3 on bosses. |
| Extra! Extra! | Event-local ×3 clear Points, not Turn Mult. |
| Finance Pages | +1 coin per clear, never multiplied. |
| Paper Route | +2 payout coins. |
| Market Wrap | Interest cap 15. |
| Auction Notices | First Shop reroll free. |
| Help Wanted | Hand size +1. |
| Weather Forecast | Toss allowance +2. |
| Puzzle Corner | +1 Clue per Puzzle. |
| Late City Final | +1 Turn per Puzzle. |
| Crossword Daily | Draw one card per clear, once; no score retrigger. |


| Marker | Version-2 role |
| --- | --- |
|---|---|
| Crimson | ×4 local placement Points. |
| Golden | +100 local placement Points. |
| Azure | +1 placement coin. |
| Ivory | Waives a wrong placement penalty on its square. |
| Emerald | ×2 local clear Points caused by its square. |
| Onyx | Restores a Clue's placement Points only; clue-triggered clears still score zero. |
| Silver | +20 placement Points per matching digit already on board, including Givens. |
| Sapphire | Draw one card after placement. |
| Rose | Increase persistent Mult seed by 1 when triggered. |
| Copper | +3 coins for each unit completed by its placement. |
| Violet | Placement base uses 9, before flat additions. |
| Jade | Wrong card returns to Hand instead of Pool. |


| Buff | Version-2 role |
| --- | --- |
|---|---|
| Peek | Clue charge/targeting; no score directly. |
| Redraw | Exchange hand; no scoring event. |
| Overtime | +2 Turns; no score directly. |
| Double Down | ×2 next eligible non-Clue, nonzero placement Points; no hook repetition. |
| Insurance | Waive next otherwise-penalized wrong placement. |
| Second Print | ×2 next eligible non-Clue, nonzero clear Points; no hook repetition. |
| Lucky Dip | Draw 2 cards; no score directly. |
| Bird Seed | +1 coin per clear for the Level after activation. |
| Fresh Ink | +2 persistent Mult seed before ordered Bookmarks, including current queued Turn. |
| Litmus | Read legal destinations, consumed on placement; no score directly. |
| Paper Crane | Chosen digit gains +50 Points on subsequent placements this Puzzle. |


| Boss | Version-2 role |
| --- | --- |
|---|---|
| Censor | Zero all score events caused by its digit; side effects retain existing behavior. |
| Editor | Hand -1. |
| Deadline | 8 Turns. |
| Fog | Hides markers, does not disable their effects. |
| Critic | Double wrong-placement penalty. |
| Mirror | Zero unit-clear Points, full-board Points unaffected. |
| Paywall | No Clues. |
| Erratum | No Tosses. |
| Collector | No interest payout. |
| Final Draft / Heavy Lifter | Target ×4. |
| Executive Editor / Unlucky Lucky | One triggered Bookmark sleeps; lock by UUID during the batch. |
| Fine Print / Buffborger | No Buff use. |
| Budget Cut / Sashimi | Final Turn Mult ×0.5 once. |
| Shredder / Over Pusher | Fouled-square restrictions. |
| Natural Born Accountant | -1 coin per placement, including mistakes; score independent. |
| Tik Tak | Active-play time limit. |
| Handy Dandy | Specific hand-card restrictions. |
| Gray the Garry | Row restriction. |
| Garry the Gray | Box restriction. |

Book benefits preserve their placement/unit Points, first-mistake waiver, coins and passive rules. Subscriptions preserve hand/Turn/Toss/Shop/rarity/interest effects. Marker storage is already unlimited; historical Overseas Edition ownership remains intact and its catalogue text now explicitly identifies that superseded legacy benefit. No hidden held-card multipliers are introduced.

## Independent acceptance arithmetic

- 50 Points, Mult 1: Op-Ed then Stop = `(1 + 1) × 3 = 6`, bank **300**. Reverse = `1 × 3 + 1 = 4`, bank **200**.
- 50 Points, two +1 modifiers: Mult **3**, bank **150**.
- 40 placement +30 Gossip: **70** Points; +1 Mult yields **140**.
- 50 Points, Ink +2, Op-Ed +1, Stop ×3, Sashimi ×0.5: **50 × 6 = 300**.
- Digit 5 completes row and box: `50 + 45 + 45 = 140`; Second Print on first clear gives `50 + 90 + 45 = 185`. Finance still pays **2** coins; Crossword still draws **2**, not 3.
- A 45-Point clear at Mult 1.5 banks **67**. Two such clears in the same batch bank **135**, not 134.
- 100 Points at Mult 3 with Morning and Turn-10 Evening banks **700**.
- 80 queued Points at Mult 3, wrong 1: queued Points become **30**, remaining bankable score **90**. Insurance instead preserves **240**.
- A revealed Clue on Onyx placing 5 while completing row/box earns **50** placement Points, **0** clear Points. Second Print remains armed.
- Reorder or sell after 50 Points under Op-Ed→Stop: current batch stays **300** through save/resume; next Turn uses the changed inventory/order.

## Target and economy assessment

Retain `1000 × 2^(chapter−1)` with ordinary/boss factors 1/1.5/2 and existing Book/boss multipliers. Base placement/clear Points, direct payouts, prices, coin generation and interest are unchanged. Best ordered additive-before-multiplicative Bookmark builds match the previous additive-pool product; suboptimal order intentionally scores less. Fresh Ink/Rose now enter before multiplicative Bookmarks, increasing their combo value. There is no justification to import Balatro poker hand values or blind targets. The deterministic [18-scenario ceiling/economy probe](qa/scoring-v2-balance.md) measures chapter 1/5/9 ordinary/boss cases, with no build, two ordered modifiers, and a five-slot scaling build. It verifies Points do not mint coins and demonstrates that late chapters require meaningful growth: unmodified full boards cover only about 1% of chapter-9 targets, while an ideal scaling build can exceed them greatly. The oversized-hand probe deliberately excludes real acquisition probabilities, forced Turn boundaries, restrictions and mistakes; it supports retaining the ladder pending player balance data, not choosing new target numbers. Catalogue/combination fixtures verify payout conservation; this is regression/balance evidence, not a claim of broad human playtest balance.
