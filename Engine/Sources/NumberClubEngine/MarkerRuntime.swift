import Foundation

/// Stateful Marker rules, kept separate from the twelve historical hooks.
/// All observations are of a committed player action; previews never call this.
public enum MarkerRuntime {
    static func puzzleKey(_ run: RunState) -> String { "\(run.level).\(run.slot.rawValue)" }

    /// Migrates old positional ownership lazily, without inventing past growth.
    public static func synchronizeOwnership(run: inout RunState) {
        let owned = run.markers
        run.markerState.claims.removeAll { claim in
            !owned.contains { $0.defID == claim.markerID && $0.covers(claim.square) }
        }
        for marker in owned {
            for square in marker.squares where !run.markerState.claims.contains(where: {
                $0.markerID == marker.defID && $0.square == square
            }) {
                run.markerState.nextClaimSerial += 1
                run.markerState.claims.append(MarkerClaim(
                    id: "\(marker.defID).claim.\(run.markerState.nextClaimSerial)",
                    markerID: marker.defID, square: square))
            }
        }
        if !run.owns(marker: Markers.escapement) { run.markerState.escapementProgress = 0 }
        if !run.owns(marker: Markers.collection) { run.markerState.collectionDigits = [] }
    }

    static func source(at square: Square, run: inout RunState) -> MarkerSource? {
        synchronizeOwnership(run: &run)
        guard let claim = run.markerState.claims.first(where: { $0.square == square }) else { return nil }
        return MarkerSource(markerID: claim.markerID, claimID: claim.id, square: square)
    }

    static func mark(_ source: MarkerSource, run: inout RunState, puzzle: inout PuzzleState) {
        let key = puzzleKey(run)
        if let index = run.markerState.claims.firstIndex(where: { $0.id == source.claimID }) {
            run.markerState.claims[index].lastTriggeredPuzzle = key
        }
        if !puzzle.markerState.turn.eligibleMarkerTypes.contains(source.markerID) {
            puzzle.markerState.turn.eligibleMarkerTypes.append(source.markerID)
        }
    }

    static func add(_ points: Int, from source: MarkerSource, to result: inout EffectResult) {
        guard points != 0 else { return }
        result.flat = ScoreMath.add(result.flat, points)
        result.contributions.append(ScoreContribution(sourceID: source.markerID,
            instanceID: source.claimID, name: Catalog.item(source.markerID)?.name ?? "Marker",
            flat: points, multAdd: 0, multX: 1, directScore: 0, coins: 0))
    }

    static func coins(_ amount: Int, from source: MarkerSource, run: inout RunState,
                      puzzle: inout PuzzleState) {
        guard amount != 0 else { return }
        let before = run.coins
        run.coins += amount
        puzzle.turnScoringOperations.append(ScoreOperation(
            id: "t\(puzzle.turnNumber).marker.\(puzzle.turnScoringOperations.count)",
            sourceID: source.markerID, sourceInstanceID: source.claimID,
            sourceName: Catalog.item(source.markerID)?.name ?? "Marker", trigger: .place,
            scope: .economy, kind: .coins, amount: Double(amount),
            before: ScoreValues(coins: before), after: ScoreValues(coins: run.coins)))
    }

    /// Call after Boss eligibility is known, before the event's final arithmetic.
    /// The current Marker is excluded from the qualification calculation.
    public static func beforePlacement(_ event: CataloguePlacement, run: inout RunState,
                                       puzzle: inout PuzzleState, result: inout EffectResult) {
        puzzle.markerState.pressmarkWasActiveForPlacement = puzzle.markerState.turn.pressmark != nil
        guard event.isEligible, !event.isClue, puzzle.phase == .playing else {
            invalidatePlacementContracts(event, puzzle: &puzzle)
            return
        }
        resolveFollowups(event, puzzle: &puzzle, result: &result)
        guard let source = source(at: event.square, run: &run) else { return }
        let id = source.markerID
        let suppressed = BossScoring.suppressesImmediateMarker(square: event.square, run: run, puzzle: puzzle)
        var bonus = 0
        switch id {
        case Markers.hearth where !suppressed:
            bonus = orthogonal(event.square).filter { event.boardBefore.isBlank($0) }.count * 20
        case Markers.constellation where !suppressed:
            bonus = min(4, puzzle.markerState.turn.eligibleMarkerTypes.filter { $0 != id }.count) * 50
        case Markers.rhythm where !suppressed:
            bonus = min(6, puzzle.markerState.turn.streak) * 25
        case Markers.bridge where !suppressed:
            let row = event.square.row, col = event.square.col
            func player(_ square: Square) -> Bool { event.boardBefore.filledBy[square.index] == .player }
            if col > 0 && col < 8 && player(Square(event.square.index - 1)) && player(Square(event.square.index + 1)) { bonus += 60 }
            if row > 0 && row < 8 && player(Square(event.square.index - 9)) && player(Square(event.square.index + 9)) { bonus += 60 }
        case Markers.crossroads where !suppressed && event.completedUnits.count >= 2 && puzzle.markerState.count(id) == 0:
            bonus = 300; puzzle.markerState.increment(id)
        case Markers.finale where !suppressed && event.boardBefore.count(of: event.digit) == 8
            && puzzle.markerState.finaleDigits.count < 2 && !puzzle.markerState.finaleDigits.contains(event.digit):
            bonus = 800; puzzle.markerState.finaleDigits.append(event.digit)
        case Markers.carbon where !suppressed:
            bonus = puzzle.markerState.turn.previousDigits.suffix(2).reduce(0) { $0 + $1.rawValue * 10 }
        case Markers.patina where !suppressed:
            bonus = min(8, run.markerState.claims.first { $0.id == source.claimID }?.patinaSuccesses ?? 0) * 25
        case Markers.ledger where puzzle.markerState.count(id) < 3:
            result.zeroed = true
            result.zeroSourceID = id
            result.coins += 2
            result.contributions.append(ScoreContribution(sourceID: id, instanceID: source.claimID,
                name: "Ledger Marker: placement traded for coins", flat: 0,
                multAdd: 0, multX: 1, directScore: 0, coins: 2))
            puzzle.markerState.increment(id)
            mark(source, run: &run, puzzle: &puzzle)
        case Markers.pledge where !suppressed && puzzle.markerState.acceptedPledgeSquare == event.square:
            // The decision has reserved this accepted placement, not paid it.
            puzzle.markerState.acceptedPledgeSquare = nil
            if run.coins >= 2, puzzle.markerState.count(id) < 3 {
                coins(-2, from: source, run: &run, puzzle: &puzzle)
                puzzle.markerState.increment(id); bonus = 100
            }
        default: break
        }
        if bonus > 0 { add(bonus, from: source, to: &result); mark(source, run: &run, puzzle: &puzzle) }
    }

    private static func resolveFollowups(_ event: CataloguePlacement, puzzle: inout PuzzleState,
                                         result: inout EffectResult) {
        let box = boxIndex(event.square)
        if let route = puzzle.markerState.turn.route {
            puzzle.markerState.turn.route = nil
            if box != boxIndex(route.source.square), box != route.nextBox {
                if route.nextBox == nil {
                    var next = route; next.nextBox = box; puzzle.markerState.turn.route = next
                } else {
                    add(120, from: route.source, to: &result); puzzle.markerState.increment(Markers.route)
                }
            }
        }
        if var ladder = puzzle.markerState.turn.ladder {
            puzzle.markerState.turn.ladder = nil
            if event.digit.rawValue > ladder.lastDigit.rawValue {
                ladder.steps += 1; ladder.lastDigit = event.digit
                if ladder.steps == 2 {
                    add(90, from: ladder.source, to: &result); puzzle.markerState.increment(Markers.ladder)
                } else { puzzle.markerState.turn.ladder = ladder }
            }
        }
        if let pair = puzzle.markerState.turn.counterweight {
            puzzle.markerState.turn.counterweight = nil
            if pair.digit.rawValue + event.digit.rawValue == 10 {
                add(70, from: pair.source, to: &result); puzzle.markerState.increment(Markers.counterweight)
            }
        }
        if var press = puzzle.markerState.turn.pressmark, press.source.square != event.square {
            add(20, from: press.source, to: &result); press.remaining -= 1
            puzzle.markerState.turn.pressmark = press.remaining > 0 ? press : nil
        }
        if var beacon = puzzle.markerState.beacon, beacon.digit == event.digit,
           beacon.source.square != event.square {
            add(40, from: beacon.source, to: &result); beacon.uses -= 1
            puzzle.markerState.beacon = beacon.uses > 0 ? beacon : nil
        }
        if var challenge = puzzle.markerState.turn.tiebreaker,
           let card = event.cardID, let index = challenge.remainingCardIDs.firstIndex(of: card) {
            challenge.remainingCardIDs.remove(at: index)
            if challenge.remainingCardIDs.isEmpty {
                add(250, from: challenge.source, to: &result)
                puzzle.markerState.increment(Markers.tiebreaker)
                puzzle.markerState.turn.tiebreaker = nil
            } else { puzzle.markerState.turn.tiebreaker = challenge }
        }
        if let bounty = puzzle.markerState.turn.bounty, bounty.square == event.square {
            add(120, from: bounty.source, to: &result)
            puzzle.markerState.increment(Markers.bounty); puzzle.markerState.turn.bounty = nil
        }
    }

    /// Clears resolve independently; a Clue/zeroed promised box expires unpaid.
    public static func beforeClear(_ event: CataloguePlacement, unit: Unit,
                                   puzzle: inout PuzzleState, result: inout EffectResult) {
        guard unit == .box, let promise = puzzle.markerState.keystone,
              boxIndex(promise.square) == boxIndex(event.square) else { return }
        puzzle.markerState.keystone = nil
        guard event.isEligible, !event.isClue, !result.zeroed, puzzle.phase == .playing else { return }
        add(120, from: promise, to: &result)
        puzzle.markerState.increment(Markers.keystone)
    }

    /// Call after current placement resources/clears have resolved, before an
    /// empty Hand can automatically close the Turn. Newly armed contracts do
    /// not observe their own source placement.
    public static func afterPlacement(_ event: CataloguePlacement, run: inout RunState,
                                      puzzle: inout PuzzleState) {
        guard event.isEligible, !event.isClue, puzzle.phase == .playing else { return }
        if let source = source(at: event.square, run: &run) {
            let id = source.markerID
            let uses = puzzle.markerState.count(id)
            var triggered = false
            switch id {
            case Markers.eraser where uses < 2 && tossingAllowed(run: run, puzzle: puzzle)
                && (puzzle.tossChargesSpent ?? puzzle.tossedThisPuzzle) > 0:
                puzzle.restoreTossCharges(1); puzzle.markerState.increment(id); triggered = true
            case Markers.echo where uses < 3 && puzzle.pool.take(event.digit):
                puzzle.appendHandDigits([event.digit]); puzzle.markerState.increment(id); triggered = true
            case Markers.prism where uses < 3:
                let excluded = Set(puzzle.hand)
                if Digit.all.contains(where: { !excluded.contains($0) && puzzle.pool[$0] > 0 }),
                   BossRuntime.deferAutomaticDraw(count: 1, sourceID: id, sourceClaimID: source.claimID,
                                                  policy: .absentFromHand, puzzle: &puzzle) {
                    puzzle.markerState.increment(id); triggered = true
                } else if let digit = drawFiltered(run: &run, puzzle: &puzzle, excluding: excluded) {
                    puzzle.appendHandDigits([digit]); puzzle.markerState.increment(id); triggered = true
                }
            case Markers.forecast where uses < 3 && puzzle.markerState.turn.forecast == nil && !puzzle.pool.isEmpty:
                puzzle.markerState.turn.forecast = source; puzzle.markerState.increment(id); triggered = true
            case Markers.escapement where uses == 0 && puzzle.boss != .lastEdition:
                run.markerState.escapementProgress += 1; triggered = true
                if run.markerState.escapementProgress >= 3 {
                    run.markerState.escapementProgress = 0; puzzle.turnsMax += 1; puzzle.markerState.increment(id)
                }
            case Markers.lamp where uses == 0 && puzzle.cluesRemaining == 0 && puzzle.boss?.disablesClues != true:
                puzzle.cluesRemaining += 1; puzzle.markerState.increment(id); triggered = true
            case Markers.umbrella where uses < 2 && puzzle.markerState.turn.umbrella == nil:
                puzzle.markerState.turn.umbrella = source; triggered = true
            case Markers.voucher where run.markerState.pendingVoucherCoins < 2:
                run.markerState.pendingVoucherCoins += 1; triggered = true
            case Markers.interest where puzzle.markerState.interestCapIncrease < 2:
                puzzle.markerState.interestCapIncrease += 1; triggered = true
            case Markers.collection where uses == 0 && !run.markerState.collectionDigits.contains(event.digit):
                run.markerState.collectionDigits.append(event.digit)
                run.markerState.collectionDigits.sort { $0.rawValue < $1.rawValue }; triggered = true
                if run.markerState.collectionDigits.count == 3 {
                    coins(4, from: source, run: &run, puzzle: &puzzle)
                    run.markerState.collectionDigits = []; puzzle.markerState.increment(id)
                }
            case Markers.debt where uses < 6 && run.coins < 0:
                let cancelled = min(2, min(6 - uses, -run.coins))
                coins(cancelled, from: source, run: &run, puzzle: &puzzle)
                puzzle.markerState.increment(id, by: cancelled); triggered = true
            case Markers.stipend where puzzle.markerState.stipend == .inactive:
                puzzle.markerState.stipend = .active; puzzle.markerState.stipendSource = source; triggered = true
            case Markers.route where uses < 2 && puzzle.markerState.turn.route == nil:
                puzzle.markerState.turn.route = MarkerRoute(source: source); triggered = true
            case Markers.ladder where uses < 2 && puzzle.markerState.turn.ladder == nil && event.digit.rawValue <= 7:
                puzzle.markerState.turn.ladder = MarkerLadder(source: source, digit: event.digit); triggered = true
            case Markers.counterweight where uses < 3 && puzzle.markerState.turn.counterweight == nil:
                puzzle.markerState.turn.counterweight = MarkerDigitPromise(source: source, digit: event.digit, uses: 1); triggered = true
            case Markers.keystone where uses < 2 && puzzle.markerState.keystone == nil && !event.completedUnits.contains(.box):
                puzzle.markerState.keystone = source; triggered = true
            case Markers.pressmark where uses < 2 && puzzle.markerState.turn.pressmark == nil
                && !puzzle.markerState.pressmarkWasActiveForPlacement:
                puzzle.markerState.turn.pressmark = MarkerUses(source: source, remaining: 3)
                puzzle.markerState.increment(id); triggered = true
            case Markers.patina:
                if let index = run.markerState.claims.firstIndex(where: { $0.id == source.claimID }),
                   run.markerState.claims[index].lastGrowthPuzzle != puzzleKey(run) {
                    run.markerState.claims[index].patinaSuccesses = min(8, run.markerState.claims[index].patinaSuccesses + 1)
                    run.markerState.claims[index].lastGrowthPuzzle = puzzleKey(run); triggered = true
                }
            case Markers.beacon where uses < 2 && puzzle.markerState.beacon == nil:
                puzzle.markerState.beacon = MarkerDigitPromise(source: source, digit: event.digit, uses: 2)
                puzzle.markerState.increment(id); triggered = true
            case Markers.census where uses < 2:
                puzzle.markerState.turn.censusDigit = event.digit; puzzle.markerState.increment(id); triggered = true
            case Markers.bounty where uses < 2 && puzzle.markerState.turn.bounty == nil:
                let candidates = Geometry.cells(of: .box, through: event.square).filter {
                    $0 != event.square && puzzle.board.isBlank($0) && run.squareIsFree($0) && !puzzle.isBarred($0)
                }
                if !candidates.isEmpty {
                    let target = candidates[run.itemRandomInt(candidates.count)]
                    puzzle.markerState.turn.bounty = MarkerTarget(source: source, square: target); triggered = true
                }
            default:
                if createDecision(source: source, event: event, run: &run, puzzle: &puzzle) { triggered = true }
                else if let definition = Catalog.item(id), definition.hooks[.place] != nil
                    || (id == Markers.emerald && !event.positiveClearUnits.isEmpty) { triggered = true }
            }
            if triggered { mark(source, run: &run, puzzle: &puzzle) }
        }
        puzzle.markerState.turn.previousDigits.append(event.digit)
        puzzle.markerState.turn.previousDigits = Array(puzzle.markerState.turn.previousDigits.suffix(2))
        puzzle.markerState.turn.streak = min(6, puzzle.markerState.turn.streak + 1)
    }

    public struct WrongProtection: Sendable, Equatable {
        public var cancelsScorePenalty: Bool = false
        public var returnsCard: Bool = false
        public var source: MarkerSource?
        public init() {}
    }

    /// Run before Insurance is consumed. This never waives a Boss coin fee.
    public static func beforeWrongPlacement(at square: Square, run: inout RunState,
                                           puzzle: inout PuzzleState) -> WrongProtection {
        var protection = WrongProtection()
        guard let source = source(at: square, run: &run) else { return protection }
        if source.markerID == Markers.blotter, puzzle.phase == .playing,
           puzzle.markerState.count(Markers.blotter) == 0 {
            puzzle.markerState.increment(Markers.blotter)
            puzzle.markerState.turn.blotterSquare = square
            protection.cancelsScorePenalty = true; protection.returnsCard = true; protection.source = source
        }
        if protection.source != nil || [Markers.ivory, Markers.jade].contains(source.markerID) {
            if let index = run.markerState.claims.firstIndex(where: { $0.id == source.claimID }) {
                run.markerState.claims[index].lastTriggeredPuzzle = puzzleKey(run)
            }
        }
        return protection
    }

    public static func reduceWrongPenalty(_ penalty: Int, alreadyCancelled: Bool,
                                          puzzle: inout PuzzleState) -> (penalty: Int, source: MarkerSource?) {
        guard !alreadyCancelled, penalty > 0, let source = puzzle.markerState.turn.umbrella,
              puzzle.markerState.count(Markers.umbrella) < 2 else { return (penalty, nil) }
        puzzle.markerState.turn.umbrella = nil; puzzle.markerState.increment(Markers.umbrella)
        return (max(0, penalty - 100), source)
    }

    public enum Interruption { case wrongPlacement, clue, toss, exchange, solutionAssistance }

    /// Only accepted actions call this. Invalid taps must never break a route.
    public static func interrupt(_ reason: Interruption, puzzle: inout PuzzleState) {
        switch reason {
        case .wrongPlacement, .clue, .toss:
            puzzle.markerState.turn.streak = 0
            puzzle.markerState.turn.route = nil; puzzle.markerState.turn.ladder = nil
            puzzle.markerState.turn.counterweight = nil; puzzle.markerState.turn.tiebreaker = nil
        case .exchange:
            puzzle.markerState.turn.streak = 0
            puzzle.markerState.turn.tiebreaker = nil
        case .solutionAssistance:
            break
        }
        if reason == .clue || reason == .solutionAssistance,
           puzzle.markerState.stipend == .active { puzzle.markerState.stipend = .broken }
    }

    private static func invalidatePlacementContracts(_ event: CataloguePlacement, puzzle: inout PuzzleState) {
        // A non-qualifying placement cannot fulfil an exact next-placement
        // promise. Clue reveal itself is also reported by interrupt(.clue).
        puzzle.markerState.turn.streak = 0
        puzzle.markerState.turn.route = nil; puzzle.markerState.turn.ladder = nil
        puzzle.markerState.turn.counterweight = nil
        if event.isClue { interrupt(.clue, puzzle: &puzzle) }
        if let target = puzzle.markerState.turn.bounty, target.square == event.square {
            puzzle.markerState.turn.bounty = nil
        }
        if let id = event.cardID, puzzle.markerState.turn.tiebreaker?.remainingCardIDs.contains(id) == true {
            puzzle.markerState.turn.tiebreaker = nil
        }
    }

    public static func endTurn(puzzle: inout PuzzleState) { puzzle.markerState.turn = .init() }
    public static func ordinaryDrawOccurred(puzzle: inout PuzzleState) { puzzle.markerState.turn.forecast = nil }
    public static func forecast(run: RunState, puzzle: PuzzleState) -> Digit? {
        guard puzzle.markerState.turn.forecast != nil else { return nil }
        var pool = puzzle.pool, stream = run.streams.pool
        return pool.draw(&stream)
    }
    public static func census(puzzle: PuzzleState) -> (digit: Digit, count: Int)? {
        puzzle.markerState.turn.censusDigit.map { ($0, puzzle.pool[$0]) }
    }
    public static func visibleCandidates(at square: Square, puzzle: PuzzleState,
                                         visibleValues: [Digit?]) -> [Digit] {
        guard visibleValues.count == 81 else { return [] }
        guard puzzle.board.isBlank(square) else { return [] }
        let peers = [Unit.row, .col, .box].flatMap { Geometry.cells(of: $0, through: square) }
        let occupied = Set(peers.compactMap { visibleValues[$0.index] })
        return Digit.all.filter { !occupied.contains($0) }
    }
    public static func stipendPayout(puzzle: PuzzleState) -> Int { puzzle.markerState.stipend == .active ? 4 : 0 }

    public static func shopOpened(run: inout RunState, visitID: Int) {
        guard run.markerState.voucherShopVisit != visitID else { return }
        run.markerState.voucherShopVisit = visitID
        run.markerState.shopVoucherCoins = run.markerState.pendingVoucherCoins
        run.markerState.pendingVoucherCoins = 0
    }
    public static func discountedRerollCost(_ ordinaryCost: Int, run: RunState) -> Int {
        ordinaryCost > 0 ? max(0, ordinaryCost - run.markerState.shopVoucherCoins) : ordinaryCost
    }
    public static func paidRerollAccepted(ordinaryCost: Int, run: inout RunState) {
        if ordinaryCost > 0 { run.markerState.shopVoucherCoins = 0 }
    }
    public static func shopClosed(run: inout RunState) { run.markerState.shopVoucherCoins = 0 }

    static func tossingAllowed(run: RunState, puzzle: PuzzleState) -> Bool {
        !run.obstacle.removesTosses && puzzle.boss?.forcesTossAllowanceToZero != true
    }
    static func boxIndex(_ square: Square) -> Int { (square.row / 3) * 3 + square.col / 3 }
    static func orthogonal(_ square: Square) -> [Square] {
        var result: [Square] = []
        if square.row > 0 { result.append(Square(square.index - 9)) }
        if square.row < 8 { result.append(Square(square.index + 9)) }
        if square.col > 0 { result.append(Square(square.index - 1)) }
        if square.col < 8 { result.append(Square(square.index + 1)) }
        return result
    }

    /// Weighted by available copies, using only the independent item stream.
    static func drawFiltered(run: inout RunState, puzzle: inout PuzzleState, excluding: Set<Digit>) -> Digit? {
        let candidates = Digit.all.filter { !excluding.contains($0) && puzzle.pool[$0] > 0 }
        let total = candidates.reduce(0) { $0 + puzzle.pool[$1] }
        guard total > 0 else { return nil }
        var index = run.itemRandomInt(total)
        for digit in candidates {
            if index < puzzle.pool[digit] { return puzzle.pool.take(digit) ? digit : nil }
            index -= puzzle.pool[digit]
        }
        return nil
    }
}
