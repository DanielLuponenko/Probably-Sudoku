# Marker integration contract

The 50 definitions retain their catalogue IDs; the original twelve hook implementations remain in `Markers.swift`. `MarkerRuntime` adds stateful rules for the other 38 without changing historical rewards. Missing Marker state decodes as an empty state. Claim records migrate lazily from owned coordinates and do not invent past Patina growth.

## Accepted placement

1. Reject invalid actions and unresolved decisions before mutation. Ensure stable Hand card IDs.
2. Before removing a correct natural card or charging a Boss fee, call `MarkerRuntime.preparePledge(handCardID:square:run:)`. If true, return `PlacementOutcome.pendingDecision = true`. The saved decision owns the original attempt; neither card nor money has changed.
3. Build one `CataloguePlacement` with the pre-placement Board/Hand, exact card ID, completed units, Turn, and natural eligibility **before the current Marker changes points**. A Clue, Keep Filling, or Boss-zeroed placement is not eligible. Ledger may subsequently zero its own placement without disqualifying its coin exchange or independent clears.
4. Apply ordinary historical hooks, then `MarkerRuntime.beforePlacement(_:run:puzzle:result:)` before final placement arithmetic. This resolves prior contracts before arming new ones. `EffectResult.zeroSourceID` attributes Ledger's zero to Ledger.
5. For each completed unit, call `MarkerRuntime.beforeClear(_:unit:puzzle:result:)` before final clear arithmetic. A Keystone promise expires on a Clue/zeroed clear without payment.
6. After placement/clear resources have resolved, call `MarkerRuntime.afterPlacement(_:run:puzzle:)` **before automatic empty-Hand banking**. A Marker decision or Fork reservation defers automatic banking.

`event.isEligible` must remain the original Boss-qualified value throughout these hooks. Old Marker hooks keep their previous Clue and Keep Filling behavior; only the new stateful effects use this gate.

## Wrong placement, assistance, Turn

- Before spending Insurance, use `beforeWrongPlacement(at:run:puzzle:)`. Blotter returns the exact card and cancels score loss, bars its square for this Turn, and never cancels a Boss coin fee.
- After full penalty waivers, use `reduceWrongPenalty(_:alreadyCancelled:puzzle:)`. An already-waived penalty leaves Umbrella armed; a positive remaining penalty spends one use and removes at most 100 points.
- Accepted wrong placement, paid Clue/solution assistance, Toss and exchanges call `interrupt(_:puzzle:)`. Invalid taps do not. Assistance breaks Stipend permanently for this Puzzle; wrong play alone does not.
- At actual Turn close call `endTurn(puzzle:)`; this clears Turn-only promises/readings/Blotter locks. It preserves Puzzle-scoped Beacon, Keystone, counters and Stipend.
- Every ordinary Pool draw calls `ordinaryDrawOccurred(puzzle:)`. Forecast's getter clones the actual Pool and Pool stream; it never advances either and recomputes after item mutations. Dedicated Marker draws use the item stream.
- `PuzzleState.create` already calls `BookmarkMechanics.puzzleStarted`, synchronizes Marker claims, then performs the first Boss selection. Boss silence uses the Bookmark candidate/redirect helpers. Do not reset Bookmark state again after that selection.

## Decisions and resources

`resolveDecision(run:id:selected:) throws -> Bool` accepts only the front saved `marker.*` decision in the same Puzzle/Turn context. `selected: nil` cancels optional choices. Fork cannot cancel after revealing cards. Each operation mutates a private Run candidate and commits once. Repeated IDs/invalid options/stale contexts return false without mutation. Pledge decline/cancel resolves the original placement normally; acceptance adds its explicit trade, then the bypass flag is cleared. A resolved batch with an empty Hand banks once after all pending decisions finish.

Actual Fork cards live in `puzzle.markerState.reservedForkCards`; `PuzzleState.assertConservation` includes these. Other conservation callers must include the reservation as held cards. Windlass spends a Toss charge without incrementing actual cards tossed. Sweep increments actual cards tossed without spending charges. Eraser refunds paid charges only.

## Shop and payout

- Shop creation: `shopOpened(run:visitID:)` transfers saved Voucher credit once per visit.
- Determine the ordinary/free-reroll price first; `discountedRerollCost(_:run:)` discounts only a positive ordinary price. After successful purchase call `paidRerollAccepted(ordinaryCost:run:)`; a free reroll preserves credit even when a paid reroll would be discounted to zero.
- Leaving Shop: `shopClosed(run:)` expires unused visit credit.
- Cash-out interest cap adds `puzzle.markerState.interestCapIncrease` (maximum two), retaining any historical cap improvements and Collector's zero-interest behavior.
- Actual winning cash-out includes `stipendPayout(puzzle:)` in the saved receipt; never award it merely for arming or previewing a payout.
- After Marker ownership acquisition, removal, or ordinary Shop reassignment, call `synchronizeOwnership(run:)`. Ownership loss drops associated claim growth and Escapement/Collection Book progress. Ordinary reassignment creates a fresh coordinate record; Buff relocation moves the existing record.

## Claim movement and presentation

Buffs use `relocatableClaims(run:)`, `canRelocateClaim(id:to:run:)`, `relocateClaim(id:to:run:)`, `canSwapClaims(first:second:run:)`, and `swapClaims(first:second:run:)`. Claim IDs are stable **Strings**. Source/destination must be blank and unbarred, and sources must not have triggered in this Puzzle. Swap requires different Marker types. These APIs carry Patina/trigger history intact and preserve ownership entitlement and purchase provenance.

Read-only presentation APIs: `forecast(run:puzzle:)`, `census(puzzle:)`, and `visibleCandidates(at:puzzle:visibleValues:)`. Pass the 81 currently visible values after concealment; the last API never reads the solution or hidden locked digits. App presentation must also apply Fog concealment before exposing any Marker source/reading. New source operations use claim ID provenance; a following contract's source square may differ from the square that receives points.

Finale currently implements +800 for each of at most two distinct completed digits (+1,600 maximum), following the effect statement; the source catalogue's contradictory '+800 maximum' limit is recorded for product clarification.
