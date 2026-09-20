import Foundation

extension MarkerRuntime {
    public static func preparePledge(handCardID: UUID, square: Square, run: inout RunState) -> Bool {
        guard let puzzle = run.puzzle, puzzle.phase == .playing,
              let index = puzzle.handCards.firstIndex(where: { $0.id == handCardID }),
              !cardIsBlocked(index, puzzle: puzzle), puzzle.board.isBlank(square),
              puzzle.markerState.turn.blotterSquare != square,
              (!puzzle.isBarred(square) || BuffRuntime.passageAllows(square, puzzle: puzzle)),
              !puzzle.clueReveals.contains(square), puzzle.hand[index] == puzzle.board.correctDigit(at: square) else { return false }
        let digit = puzzle.hand[index]
        let context = Resolver.context(.place, run: run, puzzle: puzzle, digit: digit, square: square)
        var baseline = EffectResult()
        puzzle.boss?.apply(to: &baseline, context: context, censoredDigit: puzzle.censoredDigit)
        guard !baseline.zeroed else { return false }
        return preparePledge(CataloguePlacement(digit: digit, square: square, cardID: handCardID,
            boardBefore: puzzle.board, handBefore: puzzle.handCards, isEligible: true,
            originalPlacementPoints: digit.rawValue * 10, turnNumber: puzzle.turnNumber), run: &run)
    }

    /// Called only after the attempted placement has passed ordinary validity
    /// and correctness checks, but before charging the Boss/filling the square.
    /// The original attempt is saved; declining still resolves that attempt.
    public static func preparePledge(_ event: CataloguePlacement, run: inout RunState) -> Bool {
        guard let puzzle = run.puzzle, event.isEligible, !event.isClue, puzzle.phase == .playing,
              !BossScoring.suppressesImmediateMarker(square: event.square, run: run, puzzle: puzzle),
              puzzle.markerState.acceptedPledgeSquare != event.square,
              puzzle.markerState.declinedPledgeSquare != event.square,
              puzzle.markerState.count(Markers.pledge) < 3,
              run.coins - (puzzle.boss?.coinsPerPlacement ?? 0) >= 2,
              let cardID = event.cardID,
              puzzle.handCards.contains(where: { $0.id == cardID && $0.digit == event.digit }),
              let source = source(at: event.square, run: &run), source.markerID == Markers.pledge else { return false }
        let decision = makeDecision(source: source, run: &run, puzzle: puzzle,
            kind: "pledge", options: [ItemChoiceOption(id: "pay", title: "Pay 2 coins", detail: "+100 placement Points"),
                                     ItemChoiceOption(id: "decline", title: "Place normally")],
            payload: ["card": cardID.uuidString])
        // No board, card, coin or allowance mutation until the saved decision.
        run.pendingItemDecisions.append(decision)
        run.puzzle = puzzle
        return true
    }

    static func createDecision(source: MarkerSource, event: CataloguePlacement,
                               run: inout RunState, puzzle: inout PuzzleState) -> Bool {
        let id = source.markerID, uses = puzzle.markerState.count(source.markerID)
        var options: [ItemChoiceOption] = []
        var payload: [String: String] = [:]
        var kind = ""
        var allowsCancel = true
        switch id {
        case Markers.exchange where uses < 3:
            kind = "exchange"
            options = puzzle.handCards.enumerated().compactMap { index, card in
                guard !exchangeIsBlocked(index, puzzle: puzzle),
                      puzzle.pool.total - puzzle.pool[card.digit] > 0 else { return nil }
                return ItemChoiceOption(id: card.id.uuidString, title: "Exchange \(card.digit.rawValue)",
                                        detail: "Draw a different digit", digit: card.digit, cardID: card.id)
            }
        case Markers.fork where uses < 2 && !puzzle.pool.isEmpty:
            kind = "fork"; allowsCancel = false
            let number = min(2, puzzle.pool.total)
            var cards: [Digit] = []
            for _ in 0..<number {
                if let digit = drawFiltered(run: &run, puzzle: &puzzle, excluding: []) { cards.append(digit) }
            }
            guard !cards.isEmpty else { return false }
            puzzle.markerState.increment(id)
            if cards.count == 1 { puzzle.appendHandDigits(cards); return true }
            puzzle.markerState.reservedForkCards = cards
            options = cards.enumerated().map { index, digit in
                ItemChoiceOption(id: "fork-\(index)", title: "Take \(digit.rawValue)",
                                 detail: "The other card returns to the Pool", digit: digit)
            }
        case Markers.crosscheck where uses < 2 && puzzle.markerState.turn.crosscheck == nil:
            kind = "crosscheck"
            options = Geometry.cells(of: .box, through: event.square).filter { puzzle.board.isBlank($0) }.map {
                ItemChoiceOption(id: "square-\($0.index)", title: "Row \($0.row + 1), column \($0.col + 1)",
                                 detail: "Inspect visible-rule candidates", square: $0)
            }
        case Markers.tiebreaker where uses == 0 && puzzle.markerState.turn.tiebreaker == nil:
            let cards = puzzle.handCards.enumerated().filter { !cardIsBlocked($0.offset, puzzle: puzzle) }.map(\.element)
            guard (1...3).contains(cards.count) else { return false }
            kind = "tiebreaker"
            payload["cards"] = cards.map { $0.id.uuidString }.joined(separator: ",")
            options = [ItemChoiceOption(id: "accept", title: "Take the challenge",
                                       detail: "Play these \(cards.count) cards this Turn: +250 Points")]
        case Markers.windlass where uses < 2 && tossingAllowed(run: run, puzzle: puzzle)
            && puzzle.tossesRemaining > 0 && !puzzle.pool.isEmpty:
            kind = "windlass"
            options = [ItemChoiceOption(id: "accept", title: "Spend 1 Toss", detail: "Draw \(min(2, puzzle.pool.total)) cards")]
        case Markers.sweep where uses < 2 && tossingAllowed(run: run, puzzle: puzzle):
            kind = "sweep"
            options = Digit.all.compactMap { digit in
                let count = puzzle.hand.indices.filter { puzzle.hand[$0] == digit && !exchangeIsBlocked($0, puzzle: puzzle) }.count
                guard count > 0 else { return nil }
                return ItemChoiceOption(id: "digit-\(digit.rawValue)", title: "Return \(min(2, count)) × \(digit.rawValue)",
                                        detail: "No Toss charge; no replacement draw", digit: digit)
            }
        case Markers.harvest where uses == 0:
            let cards = puzzle.handCards.enumerated().filter {
                $0.element.digit == event.digit && !exchangeIsBlocked($0.offset, puzzle: puzzle)
            }.prefix(3).map(\.element)
            guard !cards.isEmpty, puzzle.pool.total - puzzle.pool[event.digit] >= cards.count else { return false }
            kind = "harvest"
            payload["cards"] = cards.map { $0.id.uuidString }.joined(separator: ",")
            payload["digit"] = String(event.digit.rawValue)
            options = [ItemChoiceOption(id: "accept", title: "Exchange \(cards.count) × \(event.digit.rawValue)",
                                       detail: "Draw the same number of different digits")]
        default: return false
        }
        guard !options.isEmpty else { return false }
        let decision = makeDecision(source: source, run: &run, puzzle: puzzle,
            kind: kind, options: options, allowsCancel: allowsCancel, payload: payload)
        run.pendingItemDecisions.append(decision)
        return true
    }

    private static func makeDecision(source: MarkerSource, run: inout RunState, puzzle: PuzzleState,
                                     kind: String, options: [ItemChoiceOption], allowsCancel: Bool = true,
                                     payload: [String: String] = [:]) -> ItemDecision {
        var payload = payload
        payload["claim"] = source.claimID; payload["square"] = String(source.square.index)
        payload["turn"] = String(puzzle.turnNumber)
        return ItemDecision(id: run.nextItemIdentity(domain: source.markerID), sourceID: source.markerID,
            contextKey: run.itemContextKey, kind: "marker.\(kind)", title: Catalog.item(source.markerID)?.name ?? "Marker",
            detail: Catalog.item(source.markerID)?.text ?? "", options: options,
            allowsCancel: allowsCancel, consumedOnReveal: kind == "fork", payload: payload)
    }

    /// Applies one exact saved decision against a private candidate. Repeated
    /// taps, invalid options and stale contexts leave the original unchanged.
    @discardableResult
    public static func resolveDecision(run: inout RunState, id: UUID, selected: [String]?) throws -> Bool {
        guard let index = run.pendingItemDecisions.firstIndex(where: { $0.id == id }),
              index == 0, run.pendingItemDecisions[index].kind.hasPrefix("marker.") else { return false }
        var candidate = run
        let decision = candidate.pendingItemDecisions[index]
        guard decision.contextKey == candidate.itemContextKey,
              let puzzle = candidate.puzzle, puzzle.phase == .playing,
              decision.payload["turn"] == String(puzzle.turnNumber) else { return false }
        if let selected { guard decision.accepts(selected) else { return false } }
        else if !decision.allowsCancel { return false }
        candidate.pendingItemDecisions.remove(at: index)

        if decision.kind == "marker.pledge" {
            guard let raw = decision.payload["square"], let index = Int(raw), (0..<81).contains(index),
                  let rawCard = decision.payload["card"], let cardID = UUID(uuidString: rawCard),
                  let handIndex = candidate.puzzle?.handCards.firstIndex(where: { $0.id == cardID }) else { return false }
            let square = Square(index)
            if selected?.first == "pay" { candidate.puzzle?.markerState.acceptedPledgeSquare = square }
            else { candidate.puzzle?.markerState.declinedPledgeSquare = square }
            _ = try Actions.place(&candidate, handIndex: handIndex, square: square)
            // A resolved attempt cannot leave a bypass authorization behind.
            candidate.puzzle?.markerState.acceptedPledgeSquare = nil
            candidate.puzzle?.markerState.declinedPledgeSquare = nil
        } else if let selected {
            guard applyDecision(decision, selected: selected, run: &candidate) else { return false }
        }
        _ = try Actions.finishAutomaticTurnIfNeeded(&candidate)
        run = candidate
        return true
    }

    private static func applyDecision(_ decision: ItemDecision, selected: [String], run: inout RunState) -> Bool {
        guard var puzzle = run.puzzle, let chosen = decision.options.first(where: { $0.id == selected.first }),
              let claimID = decision.payload["claim"], let raw = decision.payload["square"],
              let squareIndex = Int(raw), (0..<81).contains(squareIndex) else { return false }
        let source = MarkerSource(markerID: decision.sourceID, claimID: claimID, square: Square(squareIndex))
        let uses = puzzle.markerState.count(source.markerID)
        switch decision.kind {
        case "marker.exchange":
            guard uses < 3, let cardID = chosen.cardID,
                  let index = puzzle.handCards.firstIndex(where: { $0.id == cardID }),
                  !exchangeIsBlocked(index, puzzle: puzzle),
                  puzzle.pool.total - puzzle.pool[puzzle.hand[index]] > 0 else { return false }
            let card = puzzle.removeHandCard(at: index); puzzle.pool.put(card.digit)
            BuffRuntime.invalidateCards([card.id], puzzle: &puzzle)
            guard let replacement = drawFiltered(run: &run, puzzle: &puzzle, excluding: [card.digit]) else { return false }
            puzzle.appendHandDigits([replacement]); puzzle.markerState.increment(source.markerID)
            interrupt(.exchange, puzzle: &puzzle)
        case "marker.fork":
            guard let suffix = selected.first?.split(separator: "-").last, let index = Int(suffix),
                  puzzle.markerState.reservedForkCards.indices.contains(index) else { return false }
            let cards = puzzle.markerState.reservedForkCards
            puzzle.markerState.reservedForkCards = []
            for (other, digit) in cards.enumerated() {
                if other == index { puzzle.appendHandDigits([digit]) } else { puzzle.pool.put(digit) }
            }
        case "marker.crosscheck":
            guard uses < 2, let square = chosen.square, puzzle.board.isBlank(square),
                  boxIndex(square) == boxIndex(source.square) else { return false }
            puzzle.markerState.turn.crosscheck = MarkerTarget(source: source, square: square)
            puzzle.markerState.increment(source.markerID)
        case "marker.tiebreaker":
            let ids = savedCardIDs(decision)
            guard uses == 0, (1...3).contains(ids.count), puzzle.markerState.turn.tiebreaker == nil,
                  exactUnblockedCards(ids, puzzle: puzzle).count == ids.count else { return false }
            puzzle.markerState.turn.tiebreaker = MarkerCardChallenge(source: source, cardIDs: ids)
        case "marker.windlass":
            guard uses < 2, tossingAllowed(run: run, puzzle: puzzle), puzzle.tossesRemaining > 0,
                  !puzzle.pool.isEmpty else { return false }
            puzzle.spendTossCharge(countsAsTossedCard: false)
            let count = min(2, puzzle.pool.total)
            for _ in 0..<count {
                if let digit = drawFiltered(run: &run, puzzle: &puzzle, excluding: []) { puzzle.appendHandDigits([digit]) }
            }
            puzzle.markerState.increment(source.markerID)
        case "marker.sweep":
            guard uses < 2, tossingAllowed(run: run, puzzle: puzzle), let digit = chosen.digit else { return false }
            let indices = Array(puzzle.hand.indices.filter { puzzle.hand[$0] == digit && !exchangeIsBlocked($0, puzzle: puzzle) }.prefix(2))
            guard !indices.isEmpty else { return false }
            // Snapshot the paid budget before actual-card statistics diverge.
            if puzzle.tossChargesSpent == nil { puzzle.tossChargesSpent = puzzle.tossedThisPuzzle }
            BuffRuntime.invalidateCards(Set(indices.map { puzzle.handCards[$0].id }), puzzle: &puzzle)
            for index in indices.reversed() { puzzle.pool.put(puzzle.removeHandCard(at: index).digit) }
            puzzle.tossedThisPuzzle += indices.count; puzzle.markerState.increment(source.markerID)
            interrupt(.toss, puzzle: &puzzle)
        case "marker.harvest":
            let ids = savedCardIDs(decision)
            guard uses == 0, (1...3).contains(ids.count), let rawDigit = decision.payload["digit"],
                  let value = Int(rawDigit), let digit = Digit(rawValue: value),
                  puzzle.pool.total - puzzle.pool[digit] >= ids.count else { return false }
            let indices = exactUnblockedCards(ids, puzzle: puzzle, forExchange: true)
            guard indices.count == ids.count, indices.allSatisfy({ puzzle.hand[$0] == digit }) else { return false }
            BuffRuntime.invalidateCards(Set(ids), puzzle: &puzzle)
            for index in indices.sorted(by: >) { puzzle.pool.put(puzzle.removeHandCard(at: index).digit) }
            for _ in indices {
                guard let replacement = drawFiltered(run: &run, puzzle: &puzzle, excluding: [digit]) else { return false }
                puzzle.appendHandDigits([replacement])
            }
            puzzle.markerState.increment(source.markerID); interrupt(.exchange, puzzle: &puzzle)
        default: return false
        }
        mark(source, run: &run, puzzle: &puzzle)
        run.puzzle = puzzle
        return true
    }

    private static func savedCardIDs(_ decision: ItemDecision) -> [UUID] {
        (decision.payload["cards"] ?? "").split(separator: ",").compactMap { UUID(uuidString: String($0)) }
    }
    private static func exactUnblockedCards(_ ids: [UUID], puzzle: PuzzleState, forExchange: Bool = false) -> [Int] {
        let cards = puzzle.handCards
        return ids.compactMap { id in
            guard let index = cards.firstIndex(where: { $0.id == id }),
                  !(forExchange ? exchangeIsBlocked(index, puzzle: puzzle) : cardIsBlocked(index, puzzle: puzzle)) else { return nil }
            return index
        }
    }

    private static func cardIsBlocked(_ index: Int, puzzle: PuzzleState) -> Bool {
        puzzle.isBlocked(handIndex: index) && !BuffRuntime.releaseAllows(handIndex: index, puzzle: puzzle)
    }

    private static func exchangeIsBlocked(_ index: Int, puzzle: PuzzleState) -> Bool {
        puzzle.isIndependentlyBlocked(handIndex: index) && !BuffRuntime.releaseAllows(handIndex: index, puzzle: puzzle)
    }

    public static func relocatableClaims(run: RunState) -> [MarkerClaim] {
        var copy = run; synchronizeOwnership(run: &copy)
        guard let puzzle = copy.puzzle, puzzle.phase == .playing else { return [] }
        return copy.markerState.claims.filter {
            puzzle.board.isBlank($0.square) && !puzzle.isBarred($0.square)
                && $0.lastTriggeredPuzzle != puzzleKey(copy)
        }
    }
    public static func canRelocateClaim(id: String, to square: Square, run: RunState) -> Bool {
        guard let puzzle = run.puzzle, puzzle.board.isBlank(square), !puzzle.isBarred(square),
              run.squareIsFree(square), let source = relocatableClaims(run: run).first(where: { $0.id == id }) else { return false }
        return source.square != square
    }
    @discardableResult
    public static func relocateClaim(id: String, to square: Square, run: inout RunState) -> Bool {
        guard canRelocateClaim(id: id, to: square, run: run) else { return false }
        synchronizeOwnership(run: &run)
        guard let index = run.markerState.claims.firstIndex(where: { $0.id == id }),
              let owner = run.markers.firstIndex(where: { $0.defID == run.markerState.claims[index].markerID }),
              let coordinate = run.markers[owner].squares.firstIndex(of: run.markerState.claims[index].square) else { return false }
        run.markers[owner].squares[coordinate] = square
        run.markerState.claims[index].square = square
        return true
    }
    public static func canSwapClaims(first: String, second: String, run: RunState) -> Bool {
        let claims = relocatableClaims(run: run)
        guard first != second, let a = claims.first(where: { $0.id == first }),
              let b = claims.first(where: { $0.id == second }) else { return false }
        return a.markerID != b.markerID && a.square != b.square
    }
    @discardableResult
    public static func swapClaims(first: String, second: String, run: inout RunState) -> Bool {
        guard canSwapClaims(first: first, second: second, run: run) else { return false }
        synchronizeOwnership(run: &run)
        guard let a = run.markerState.claims.firstIndex(where: { $0.id == first }),
              let b = run.markerState.claims.firstIndex(where: { $0.id == second }),
              let ownerA = run.markers.firstIndex(where: { $0.defID == run.markerState.claims[a].markerID }),
              let ownerB = run.markers.firstIndex(where: { $0.defID == run.markerState.claims[b].markerID }),
              let indexA = run.markers[ownerA].squares.firstIndex(of: run.markerState.claims[a].square),
              let indexB = run.markers[ownerB].squares.firstIndex(of: run.markerState.claims[b].square) else { return false }
        let squareA = run.markerState.claims[a].square, squareB = run.markerState.claims[b].square
        run.markers[ownerA].squares[indexA] = squareB; run.markers[ownerB].squares[indexB] = squareA
        run.markerState.claims[a].square = squareB; run.markerState.claims[b].square = squareA
        return true
    }
}
