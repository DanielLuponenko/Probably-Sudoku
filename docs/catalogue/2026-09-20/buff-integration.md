# Buff engine integration

All 40 definitions are in `Buffs.all`, with the catalogue's item-specific price,
rarity and complete explanation. This file describes the calls the shared
engine/app must make; it does not replace behavioral tests.

## State and identity

- `RunState.buffState: BuffRunState`, `PuzzleState.buffState: BuffPuzzleState`:
  decode missing state as `.init()`. New state is Codable.
- Hand movement uses `CatalogueHandCard` and the shared Puzzle helpers. Never
  reconcile a Release Note/Clean Finish contract by matching digit values.
- Marker relocation calls the Marker agent's String claim-ID APIs. All claim
  history travels with the claim. Fog prohibits the relocation selectors.
- Collateral writes `puzzle.bookmarkState.suspended`; this is the sole pledge
  authority. `run.effectiveHandSize` excludes the pledged passive, then adds
  `puzzle.buffState.handSizeBonus`. It does not immediately draw.
- Collateral and New Edition evaluate capacity after consuming the exact
  activating Buff in a prospective copy. A full three-slot Pocket Insert can
  therefore be pledged/retired when that cost leaves two held Buffs. Ordinary
  sale/removal guards are unchanged; actual post-action overflow is rejected.
- `Pool.scheduleDraws` owns Collation's reservations. All normal draw and
  targeted take paths use Pool methods, including Clues and Marker draws.
- On resume call `BuffRuntime.prepareLegacyLitmus(&run)`: an old already-paid
  Litmus flag with no digit gets one persisted mandatory digit choice, without
  consuming/granting an item. Repeated migration calls do not duplicate it.

## Use and decisions

`BuffRuntime.begin(buffID:run:)` is the app entry point after confirming a Buff.
It either commits a simple effect or appends a saved `ItemDecision`.
`canUse(buffID:run:)` is safe for availability; the UI does not reveal its internal
Pool/claim choices before entering the decision.

`commit(decisionID:selected:run:)` validates the exact first decision ID, current
context, current owned UUID and typed targets. It may replace the first decision
with a follow-up (Fair Exchange/Rebind/Transposition). Render the whole pending
queue; keep gameplay/navigation blocked while a mandatory decision is pending.
`cancel(decisionID:run:)` handles ordinary unpaid target selection without losing
an item. `consumedOnReveal` decisions cannot be cancelled: Collation, Detour and
Boss Draft must restore their exact sampled alternatives after relaunch.

While any saved decision is pending, the Game facade also blocks stale Shop
buy/reroll/sell, Marker claim, Bookmark reorder and Reservation-cancel calls.
The app ignores their delayed callbacks before changing presentation. Internal
`Shop.sell` remains available to the explicit Pocket Insert capacity-sale
resolver, which commits both chosen sales in its one local transaction.

The engine-only `use(BuffUseRequest,run:)` allows already-selected typed choices.
It uses a local Run copy and publishes only after validation. Repeated taps use
the old Buff UUID or decision ID and therefore cannot claim a second effect.

`BuffUseOutcome.shouldEndTurn` is set only when Careful Cut leaves an empty Hand.
The Game facade must run the normal `Actions.endTurn` once on the same copied
Game before publishing it. `handChanged` tells presentation to reconcile card
arrival/return identities; animation callbacks never commit effects.

The existing delayed Peek targeting is supported by passing the ordinary Peek
use through the new runtime only when its legal reveal commits. A direct engine
Peek still grants a Clue charge. Carbon Receipt's Peek grants the same charge,
with Carbon recorded as the consumed source.

## Placement, Toss, and end-of-Turn hooks

1. Validate raw square/card boss restrictions with the explicit one-attempt
   exceptions `passageAllows(square,puzzle:)` and
   `releaseAllows(handIndex:puzzle:)`. Keep raw restrictions queryable for
   selecting the original blocked target. All other guards/fees still apply.
2. After *all* validation, call `acceptedAttempt(cardID:square:puzzle:)`.
   A Toss passes `square:nil`; placements pass the actual square. Invalid input
   must not consume permissions or Litmus. Correct and wrong attempts both do.
3. Any wrong placement, Toss, exchange, Redraw or return of a tracked card calls
   `invalidateCards(Set<UUID>,puzzle:)`. Buff-specific returns already do this.
4. Successful one-shot flag consumption calls
   `markTriggered(definition,puzzle:)` so Return Receipt cannot resurrect it.
   Calling it for an anonymous historical flag is harmless.
5. Alongside every real scored receipt, call
   `recordPoints(id:points:eligible:originalPlacement:puzzle:)`. IDs are unique
   within the Puzzle. Split eligible original placement arithmetic from
   Buff-derived additions; clears and all Buff awards are non-original.
   Onyx-restored Clue Points are always ineligible. A wrong penalty calls
   `debitQueuedPoints(actualQueuedPenalty,puzzle:)` so erased Points cannot fund
   a later Rain Check. No historical unclassified points become eligible.
6. After the placement and real clear receipts, before phase change and auto
   banking, publish the local Puzzle into the transaction Run and call
   `didPlace(CataloguePlacement,run:)`. Reload the resulting Puzzle. It queues
   Clean Finish, Cross-Cut, Open Bracket and Rain Check exactly once. Returned
   `BuffPointAward` values are presentation evidence, **already applied**.
7. After banking and before Turn increment call `didBank(puzzle:)`. This clears
   Turn overlays/permissions/mult/point lots and expires missed contracts.
8. At win/failure/cash-out call `didEndPuzzle(&run)` to restore the pledged
   Bookmark and discard deferred Puzzle bonuses. A won Puzzle must not retain
   a pledge while offering Keep Filling. Terminal Book state also clears route
   intents/reservations.

## Scoring

F31 and F33 use `additionalEligibleMult(puzzle)`, applied before the same ordered
Bookmark operations **only to `eligibleQueuedPoints(puzzle)`**. The remaining
queue receives the normal Mult. Compute the combined product before final
floor/score-ceiling handling; expose both real arithmetic portions in the ledger
rather than falsely multiplying Onyx-restored Clue Points by the extra bonus.

Rain Check may debit only positive non-Clue placement Points excluding other
Buff bonuses. Normal Marker/Bookmark placement effects remain placement Points;
Line Clears, Buff contracts, Double Down's added amount and Paper Crane's added
amount are not funding. Root receipt extraction must preserve this distinction.

## Shop and route

- `BuffShop.didOpen(&run, initialStock:true)` runs after initial stock has its
  final visit ID. On reroll use `initialStock:false` so a carried reservation
  returns but Supplement does not recur.
- `BuffShop.rerollPrice(run,ordinaryCost:)` applies Free Press to the actual
  regular cost remaining after a Marker voucher. After successful payment,
  `willReroll(&run,ordinaryCost:)` consumes credit only when that residual was
  positive. Ordinary reroll escalation uses its full undiscounted cost/counter.
- `didBuy(slot:run:)` retires a bought reserved offer and invalidates a selected
  outgoing Reservation offer. Actual paid discount is retained as `pricePaid`.
- `leave(&run)` runs in the same transaction as Shop departure. This alone
  consumes a selected Reservation and carries its exact definition/price into
  the next reached Shop. It also expires visit credit/reservations. Merely
  selecting or cancelling a flip cannot spend Reservation.
- Every consumed Buff invokes `BookmarkMechanics.buffConsumed`, including
  Reservation on committed departure. No New Edition buy/sell hooks fire.
- New Edition uses `BookmarkMechanics.retire`, keeps its slot, creates a fresh
  instance with zero paid price and no Shop provenance, and invalidates an
  unsold offer for its now-owned definition. A pledged/capacity-critical item is
  unavailable.
- `BuffRoutes.selectedBoard(run:)` overrides the dealt board **after** normal
  board generation consumes its usual stream, before Pool construction. The
  alternate uses a dedicated deterministic domain. Both choices leave later
  board deals, boss RNG, Shop RNG and skip reward identical.
- `BuffRoutes.didStartPuzzle(&run)` clears the used layout preview. Never start
  while its saved mandatory decision is unresolved. Boss Draft changes the
  persisted announcement before normal boss modifiers are computed.
- New-run skip rewards use `SkipOffer.offer(...,version:run.catalogueVersion)`.
  Historical version 1 is frozen. Version 2 is a separate frozen 40-entry table.

## Information presentation

`poolCounts` is visible only during the paid Turn.
`proofCandidates(puzzle:visibleValues:)` takes exactly the UI-visible values;
never pass hidden/fogged contents. It does not read the solution.
`litmusReading(at:puzzle:)` uses the paid, locked digit, not current selection.
Parity notes are in `puzzle.buffState.parity` (true means even), expire on fill,
and are paid partial information with ordinary eventual placement scoring.
`BuffRoutes.previewLayouts` returns givens-only arrays; no solution preview API.
Use custom compact paper choices and quiet optional inspection, not permanent
board doodles. Shop layout must explicitly accommodate Supplement's sixth offer.

`App/Model/CatalogueReadings.swift` supplies `CatalogueReadings(run:)` with
`isEmpty` and stable ordered entries. It reads only currently paid state and
uses catalogue names. Pool counts, Forecast, Census, Proof, Fold Test,
Crosscheck and Bounty share one snapshot. Marker-derived readings are hidden
under Fog; independently purchased Buff readings are retained. An optional
`visibleValues` argument lets a caller supply a partially concealed board;
candidates never consult its solution. Forecast samples a value copy without
advancing the real stream or taking a token.

`CatalogueReadingsView(run:)` embeds in Run Info without a nested scroll view.
`CatalogueReadingsSlip(run:onClose:)` is the immediate paper result. Both use
scalable reading text and candidate-row reflow; the surrounding PaperSlip keeps
Close reachable. Four App tests exercise the paid gates, canonical names, live
updates, visible-only constraints, Fog, deterministic reads and expiry.

Buff Set fields and square-keyed parity use the shared StableSet/StableMap
Codable wrappers. Their encoding is canonical while preserving compatibility
with old unordered array encodings; the focused state test reverses those
legacy orders and checks identical canonical bytes after repeated round trips.
