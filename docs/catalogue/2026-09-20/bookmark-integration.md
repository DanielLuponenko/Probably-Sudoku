# Bookmark integration contract

`Bookmarks.all` contains B01–B50 with approved prices and complete descriptions.
`BookmarkMechanics` owns saved per-instance limits, optional decisions and pure
held-effect evaluation. Preserve owned UUIDs and existing shop-offer prices.

## Actions (root ownership)

1. At Puzzle creation call `puzzleStarted(puzzle:)` **before** the first Boss
   silence selection. This resets only Puzzle state, never run growth/archive.
2. Capture `CataloguePlacement.boardBefore`, `handBefore` and `cardID` before
   removing the card or filling its square. Eligibility means correct,
   non-Clue, non-Boss-zeroed, phase `.playing`. Onyx does not make a Clue eligible.
3. Compute `markerExtraPoints` using the same marker-only event with and without
   its marker, excluding all held/Book/Buff bonuses and global multipliers.
   Clamp only the positive difference; Carbon itself caps at 180.
4. Call `beforePlacement(placement,run:puzzle:)` exactly once after eligibility
   is known but before calculating local event points. Merge returned flat and
   source contributions into the placement result. It records current Turn facts
   before held Mult preview. Do not call it for preview/counterfactual math.
5. Once placement/clear receipts are final, populate `positiveClearUnits` with
   non-Clue, nonzero clear events and call `afterPlacement`. Apply returned coins
   and direct score exactly once, with source receipts. Targeted Personal Column
   draws and Reference Desk Clue restores already mutate Puzzle state internally.
6. Accepted wrong placement: after all waivers and flooring, pass the actual
   reduction in pending Points + banked score to `wrongPlacement`. This must not
   be the nominal penalty. Invalid barred/filled/absent-card attempts do nothing.
7. Accepted Toss: after returning its card/spending allowance, `afterToss` resolves
   Paper Salvage before the empty-Hand policy. It performs its finite draw itself.
8. Paid new Clue reveals/use call `clueSpent`; re-inspecting an already paid reveal
   must not call it. Accepted Buff use calls `actionAccepted` and `buffConsumed`
   once with the removed OwnedBuff (positive `pricePaid` proves purchase).
9. On any actual action call `invalidateActionChoices(run:)` to retire stale
   start offers. Resolving Duplicate Dispatch already does this. Choosing Type
   Case/Personal Column/Advance Payment does not itself spend the first action.
10. End Turn: call `turnEnd` before bank and merge its direct contributions.
    Legacy Morning/Evening hooks are suppressed by Resolver on expanded Turns.
    Call `didBank(ordinaryBank:puzzle:)` after bank/direct additions, before
    `updatePhase`/Turn increment. Pass only the ordinary bank, excluding direct
    awards. This captures actual winning Turn and prior ordinary bank/penalty.
11. After increment call `turnStarted`; after ordinary refill call
    `afterPlayableRefill` only when the next Turn is actually playable. Winning
    or exhausted Turns do not release Cross Reference packets. A later rescue
    may release them after restoring `.playing` without an extra ordinary refill.
12. Cash-out calls `puzzleWon` once, before discarding the Puzzle; skips never do.
    Add `earlyDeadlineCoins` as a dedicated saved payout component. Keep Filling
    must retain the original `winningTurn`. Final Book clears Archive packets.

`legacyTurn` is true only when decoding a historical live Turn without the new
facts. It preserves its old arithmetic; `turnStarted` clears it. No retroactive
eligible actions, Number Index growth or early-win rewards are inferred.

## Passive ownership, Bosses, capacity (root ownership)

- Use `activeOwned`/`owns` for passive Bookmark budgets. Boss silence remains
  hook-only; Collateral's `bookmarkState.suspended` excludes all passive effects.
- `capacity(run:puzzle:)` is 2, or 3 with active Pocket Insert. Use everywhere:
  purchases, skips, rewards, QA grants, inventories and replacement interfaces.
- Before selling/replacing/suspending a Bookmark require `canRemove`. A Pocket
  Insert with three Buffs needs an explicit reversible Buff removal decision.
  Collateral cannot suspend it first and leave the run over capacity.
- Boss candidates use `hasGameplayHooks`, excluding suspended copies. After the
  existing random candidate is chosen, `redirectBossSilence` may redirect to
  Right to Reply without another RNG draw. The interceptor is not a candidate.
- `poolForecast` clones Pool and its stream; display only while owned/active.
  Its read must never change live RNG or Pool counts.

## Decisions (shared presentation)

`enqueueChoices(run:)` publishes generic ItemDecisions at clean Puzzle/Turn
starts and a Shop's opening. `resolveDecision(id:selected:run:)` validates the
current context and owned identity, then commits one copied RunState; nil cancels.
Do not spend items/coins in UI before calling it. Duplicate Dispatch moves saved
card identities using shared helpers. Recycled Insert persists two choices and
keeps receipts until the Buff/replacement choice is complete.

## Shop and scoring (Bookmark agent ownership)

Shop calls `shopOpened` only on a new canonical visit; rerolls preserve its state.
Display and charge `purchasePrice`, record `didPurchase` only on success,
`didReroll` only on success, `salePrice`/`didSell` for confirmed Bookmark sales,
and `shopLeaving` only at committed Continue before clearing `run.shop`.
Legacy visited Shops without state use `restoreShopStateIfNeeded`, which does
not invent a clean visit or entry inventory.

Ordered held Mult uses `heldEffect(item,previous:physicalLeft,run:puzzle:)`.
Disabled slots stay in the adjacency list. Preview is pure. Current Number Index
growth is read by copy identity, while existing locked order/source IDs remain.
