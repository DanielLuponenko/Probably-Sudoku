import Foundation

/// The five things a player can do in a Turn (§5), plus ending the Puzzle (§7).
/// Every one of them takes the whole `RunState` because items, coins and the
/// board all move together.
public enum Actions {

    /// Keeps square multipliers on their own placement while leaving held
    /// multipliers for the Turn bank.
    private static func queued(_ whole: EffectResult, square: EffectResult) -> EffectResult {
        var result = whole
        result.multAdd = square.multAdd
        result.multX = square.multX
        return result
    }

    private static func collectHeldMultiplier(_ whole: EffectResult,
                                              minus square: EffectResult,
                                              into puzzle: inout PuzzleState) {
        guard !whole.zeroed else { return }
        if puzzle.scoringVersion >= 2 {
            puzzle.observeScoringEvent(whole)
            return
        }
        let heldAdd = 1 + whole.multAdd - square.multAdd
        let heldX = square.multX == 0 ? 1 : whole.multX / square.multX
        puzzle.pendingMult = max(puzzle.pendingMult, heldAdd * heldX)
    }

    // MARK: - Place

    /// Put a number from the Hand on a Blank. Correct scores; wrong is penalised.
    @discardableResult
    public static func place(_ run: inout RunState, handIndex: Int, square: Square) throws -> PlacementOutcome {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        guard puzzle.hand.indices.contains(handIndex) else { throw PlacementError.numberNotInHand }
        guard puzzle.board.isBlank(square) else { throw PlacementError.squareNotBlank }
        guard !puzzle.isBarred(square) || BuffRuntime.passageAllows(square, puzzle: puzzle) else { throw PlacementError.squareBarred }

        let digit = puzzle.hand[handIndex]
        // Obstacle III bars one number a Turn. It stays in the Hand and can
        // still be Tossed; it just cannot go on the board.
        guard !puzzle.isBlocked(handIndex: handIndex) || BuffRuntime.releaseAllows(handIndex: handIndex, puzzle: puzzle) else { throw PlacementError.numberBlocked }
        puzzle.ensureHandIdentities(seed: run.seed)
        run.puzzle = puzzle
        if MarkerRuntime.preparePledge(handCardID: puzzle.handCards[handIndex].id, square: square, run: &run) {
            var pending = PlacementOutcome(); pending.pendingDecision = true
            return pending
        }
        BossScoring.pinBookmarkOrder(run: run, puzzle: &puzzle)
        puzzle.bossState.placementStarted = true
        let coinCost = puzzle.boss?.coinsPerPlacement ?? 0
        if coinCost > 0, puzzle.scoringVersion >= 2 {
            puzzle.turnScoringOperations.append(ScoreOperation(id: "t\(puzzle.turnNumber).cost.\(puzzle.turnScoringOperations.count)",
                sourceID: "boss.accountant", sourceInstanceID: "boss.accountant", sourceName: "Natural Born Accountant",
                trigger: .place, scope: .economy, kind: .coins, amount: Double(-coinCost),
                before: ScoreValues(coins: run.coins), after: ScoreValues(coins: run.coins - coinCost)))
        }
        run.coins -= coinCost
        puzzle.ensureHandIdentities(seed: run.seed)
        let handBefore = puzzle.handCards
        let playedCard = puzzle.removeHandCard(at: handIndex)
        BuffRuntime.acceptedAttempt(cardID: playedCard.id, square: square, puzzle: &puzzle)
        var outcome: PlacementOutcome
        if digit == puzzle.board.correctDigit(at: square) {
            let wasRevealed = puzzle.clueReveals.remove(square) != nil
            outcome = resolveCorrect(&run, &puzzle, digit: digit, square: square, isClue: wasRevealed, card: playedCard, handBefore: handBefore)
        } else {
            outcome = resolveWrong(&run, &puzzle, digit: digit, square: square, card: playedCard)
        }

        // Litmus stays armed while the player examines the grid, then is spent
        // by either a correct or wrong placement. Guards above ensure blocked
        // or otherwise invalid attempts leave it available.
        _ = puzzle.consume(.litmus)

        puzzle.assertConservation()
        run.puzzle = puzzle
        // A playable Turn with no cards has no further decision in it. Run the
        // normal end-of-turn path exactly once so effects and refill stay in
        // the same deterministic rules layer as a manual End Turn.
        outcome.automaticTurn = try finishAutomaticTurnIfNeeded(&run)
        endBookIfPuzzleFailed(&run)
        return outcome
    }

    /// §7 — a failed Puzzle ends the Book. There is more than one way to fail,
    /// so this is checked wherever the phase can change rather than only where
    /// the Turns run out.
    private static func endBookIfPuzzleFailed(_ run: inout RunState) {
        if run.puzzle?.phase == .failed {
            run.puzzle?.bossState.scoring.serialCarry = 0
            run.outcome = .failed
        }
        if run.puzzle?.phase == .won || run.puzzle?.phase == .failed { BuffRuntime.didEndPuzzle(&run) }
    }

    /// Tik Tak's clock lives in the app, but expiry still has to take the same
    /// production failure path as every other lost Puzzle.
    public static func failPuzzle(_ run: inout RunState) {
        guard var puzzle = run.puzzle,
              puzzle.phase == .playing || puzzle.phase == .keepFilling else { return }
        puzzle.phase = .failed
        puzzle.bossState.scoring.serialCarry = 0
        run.puzzle = puzzle
        run.outcome = .failed
        BuffRuntime.didEndPuzzle(&run)
    }

    /// §6 — a wrong placement subtracts `50 x the number`, doubled by The
    /// Critic, cancelled by an Ivory Marker on the square or an armed
    /// Insurance. The number goes back to the Pool, or to the Hand under Jade.
    private static func resolveWrong(_ run: inout RunState, _ puzzle: inout PuzzleState,
                                     digit: Digit, square: Square, card: CatalogueHandCard? = nil) -> PlacementOutcome {
        let context = Resolver.context(.wrongPlace, run: run, puzzle: puzzle,
                                       digit: digit, square: square)
        var result = Resolver.square(context, run: run, puzzle: puzzle)
        let protection = MarkerRuntime.beforeWrongPlacement(at: square, run: &run, puzzle: &puzzle)
        result.zeroed = result.zeroed || protection.cancelsScorePenalty
        result.wrongReturnsToHand = result.wrongReturnsToHand || protection.returnsCard
        if puzzle.boss == .returnSlip {
            result.wrongReturnsToHand = true
            if let card { puzzle.bossState.sealedIDs.insert(card.id) }
        }
        // An already-won Puzzle has a frozen score. Cancel the penalty before
        // held protection resolves, so neither Insurance nor the Book's first
        // mistake waiver is wasted. Positional hand-return effects still apply.
        if puzzle.phase == .keepFilling { result.zeroed = true }
        Resolver.holdings(context, run: run, puzzle: puzzle, into: &result)

        var cancelled = result.zeroed
        let usedInsurance = !cancelled && puzzle.consume(.insurance)
        if usedInsurance { cancelled = true; BuffRuntime.markTriggered(Buffs.insurance, puzzle: &puzzle) }
        let waiverSource: String
        if usedInsurance { waiverSource = "bf_insurance" }
        else if let source = protection.source { waiverSource = source.markerID }
        else if puzzle.phase == .keepFilling { waiverSource = "keep-filling" }
        else if run.markers(covering: square).contains(where: { $0.defID == Markers.ivory }) { waiverSource = Markers.ivory }
        else { waiverSource = "book-benefit" }

        let doubled = puzzle.boss?.doublesWrongPenalty == true
        let requestedPenalty = cancelled ? 0 : 50 * digit.rawValue * (doubled ? 2 : 1)
        let penalty = MarkerRuntime.reduceWrongPenalty(requestedPenalty, alreadyCancelled: cancelled,
                                                       puzzle: &puzzle).penalty
        let penaltyBefore = ScoreValues(points: Double(puzzle.pendingBase), mult: puzzle.pendingMultiplier, score: puzzle.score)
        let fromQueue = min(puzzle.pendingBase, penalty)
        puzzle.pendingBase -= fromQueue
        BuffRuntime.debitQueuedPoints(fromQueue, puzzle: &puzzle)
        BossEncounterRules.addScore(-(penalty - fromQueue), puzzle: &puzzle)
        if puzzle.scoringVersion >= 2 {
            puzzle.turnScoringOperations.append(ScoreOperation(id: "t\(puzzle.turnNumber).penalty.\(puzzle.turnScoringOperations.count)",
                sourceID: cancelled ? waiverSource : "wrong-placement",
                sourceInstanceID: usedInsurance ? (puzzle.scoringBuffSources["bf_insurance"]?.last?.uuidString ?? "legacy.insurance") : (cancelled ? waiverSource : "wrong-placement"),
                sourceName: cancelled ? "\(Catalog.item(waiverSource)?.name ?? "Book protection"): penalty waived" : "Wrong placement: queued Points first",
                trigger: .wrongPlace, scope: .turn, kind: .penalty, amount: Double(penalty), before: penaltyBefore,
                after: ScoreValues(points: Double(puzzle.pendingBase), mult: puzzle.pendingMultiplier, score: puzzle.score)))
        }

        let actuallyPaid = fromQueue + penaltyBefore.score - puzzle.score
        BookmarkMechanics.wrongPlacement(digit: digit, paidPenalty: actuallyPaid, run: run, puzzle: &puzzle)
        MarkerRuntime.interrupt(.wrongPlacement, puzzle: &puzzle)
        if let card { BuffRuntime.invalidateCards([card.id], puzzle: &puzzle) }
        if result.wrongReturnsToHand {
            if let card { puzzle.appendHandCard(card) } else { puzzle.appendHandDigits([digit]) }
        } else {
            puzzle.pool.put(digit)
        }

        run.absorb(result)
        puzzle.absorb(result)

        var outcome = PlacementOutcome()
        outcome.correct = false
        outcome.penalty = penalty
        outcome.points = -penalty
        outcome.coinsEarned = result.coins
        outcome.returnedToHand = result.wrongReturnsToHand
        return outcome
    }

    /// §6, order of resolution — the placement scores, then each row, column
    /// and box it completes scores one at a time, then the Full Clear.
    private static func resolveCorrect(_ run: inout RunState, _ puzzle: inout PuzzleState,
                                       digit: Digit, square: Square, isClue: Bool, card: CatalogueHandCard? = nil,
                                       handBefore: [CatalogueHandCard] = []) -> PlacementOutcome {
        var outcome = PlacementOutcome()
        outcome.correct = true

        puzzle.lockScoringOrder(run: run)
        BossScoring.beforeCorrectFill(square: square, run: run, puzzle: &puzzle)
        let boardBefore = puzzle.board
        let countBefore = puzzle.board.count(of: digit)
        puzzle.board.fill(square, with: digit, by: isClue ? .clue : .player)
        let completedUnits = puzzle.board.unitsCompleted(at: square)
        // --- The placement itself -------------------------------------------
        let placeContext = Resolver.context(.place, run: run, puzzle: puzzle,
                                            digit: digit, square: square, isClue: isClue,
                                            boardCountBefore: countBefore,
                                            completesLine: !completedUnits.isEmpty,
                                            completedUnitCount: completedUnits.count)
        var placeSquare = Resolver.square(placeContext, run: run, puzzle: puzzle)
        var bossBaseline = EffectResult()
        puzzle.boss?.apply(to: &bossBaseline, context: placeContext, censoredDigit: puzzle.censoredDigit)
        var observation = CataloguePlacement(digit: digit, square: square, cardID: card?.id,
            boardBefore: boardBefore, handBefore: handBefore, completedUnits: completedUnits,
            isClue: isClue, isEligible: !isClue && !bossBaseline.zeroed && puzzle.phase == .playing,
            turnNumber: puzzle.turnNumber)
        let naturalEligibility = observation.isEligible
        MarkerRuntime.beforePlacement(observation, run: &run, puzzle: &puzzle, result: &placeSquare)
        let naturalBase = BossScoring.naturalBase(digit: digit, puzzle: puzzle)
        let markerOnly = Resolver.scoredEvent(base: BossScoring.placementBase(digit: digit, override: placeSquare.baseOverride, puzzle: puzzle),
            originalBase: naturalBase, result: placeSquare, square: placeSquare, puzzle: puzzle,
            event: .place, digit: digit, isClueZero: isClue, doubler: nil, sequence: 0, coinsBefore: run.coins)
        let baselinePoints = Resolver.points(base: naturalBase, result: bossBaseline,
                                             globalAdditive: 0, oneShotDoubler: false)
        observation.markerExtraPoints = max(0, markerOnly.points - baselinePoints)
        observation.isEligible = naturalEligibility && !placeSquare.zeroed
        let bookmarkEffect = BookmarkMechanics.beforePlacement(observation, run: &run, puzzle: &puzzle)

        placeSquare.flat = ScoreMath.add(placeSquare.flat, ScoreMath.integer(puzzle.itemState[Buffs.paperCraneKey(digit)] ?? 0))
        var placeResult = placeSquare
        placeResult.merge(bookmarkEffect)
        Resolver.holdings(placeContext, run: run, puzzle: puzzle, into: &placeResult)

        // A Clue scores nothing unless an Onyx Marker on that square restores it.
        let clueEarnsPoints = !isClue || placeResult.clueScoresPlacement
        let doubleDown = !isClue && (puzzle.scoringVersion < 2 || !placeResult.zeroed)
            && puzzle.consume(.doubleDown)
        let base = BossScoring.placementBase(digit: digit, override: placeResult.baseOverride, puzzle: puzzle)
        if doubleDown { BuffRuntime.markTriggered(Buffs.doubleDown, puzzle: &puzzle) }

        let rawPlaceReceipt = receipt(base: base, originalBase: naturalBase,
            result: placeResult, square: placeSquare, puzzle: puzzle,
            event: .place, digit: digit, coinsBefore: run.coins, clueZero: !clueEarnsPoints, doubler: doubleDown ? "bf_double_down" : nil)
        let placeReceipt = BossScoring.adjustedPlacementReceipt(rawPlaceReceipt, digit: digit,
            square: square, isClue: isClue, puzzle: puzzle)
        observation.placementPoints = placeReceipt.points
        observation.isEligible = observation.isEligible && placeReceipt.points > 0
        var originalResult = placeResult
        originalResult.flat -= ScoreMath.integer(puzzle.itemState[Buffs.paperCraneKey(digit)] ?? 0)
        let buffContributions = originalResult.contributions.filter { $0.sourceID.hasPrefix("bf_") }
        originalResult.flat -= buffContributions.reduce(0) { $0 + $1.flat }
        originalResult.contributions.removeAll { $0.sourceID.hasPrefix("bf_") }
        let originalReceipt = receipt(base: base, originalBase: naturalBase, result: originalResult,
            square: placeSquare, puzzle: puzzle, event: .place, digit: digit, coinsBefore: run.coins,
            clueZero: !clueEarnsPoints, doubler: nil)
        observation.originalPlacementPoints = min(placeReceipt.points,
            BossScoring.adjustedPlacementReceipt(originalReceipt, digit: digit, square: square,
                                                  isClue: isClue, puzzle: puzzle).points)
        observation.markerExtraPoints = min(observation.markerExtraPoints, max(0, placeReceipt.points - baselinePoints))
        BossScoring.commitReceipt(placeReceipt, isClue: isClue, puzzle: &puzzle)
        let lotID = "t\(puzzle.turnNumber).square\(square.index)"
        if puzzle.phase == .playing {
            BuffRuntime.recordPoints(id: lotID + ".placement", points: observation.originalPlacementPoints,
                eligible: observation.isEligible, originalPlacement: true, puzzle: &puzzle)
            BuffRuntime.recordPoints(id: lotID + ".buff-placement", points: placeReceipt.points - observation.originalPlacementPoints,
                eligible: observation.isEligible, originalPlacement: false, puzzle: &puzzle)
        }
        outcome.points = placeReceipt.points
        outcome.censored = placeResult.zeroed
        if puzzle.phase != .keepFilling {
            append(placeReceipt, to: &puzzle, outcome: &outcome)
            if clueEarnsPoints || puzzle.scoringVersion < 2 {
                collectHeldMultiplier(placeResult, minus: placeSquare, into: &puzzle)
            }
        }
        apply(placeResult, &run, &puzzle, into: &outcome)

        // --- Each completed row, column and box ------------------------------
        for unit in completedUnits {
            let context = Resolver.context(.lineClear, run: run, puzzle: puzzle,
                                           digit: digit, square: square, unit: unit, isClue: isClue,
                                           boardCountBefore: countBefore, completesLine: true)
            var lineSquare = Resolver.square(context, run: run, puzzle: puzzle)
            var markerClear = observation
            markerClear.isEligible = naturalEligibility
            MarkerRuntime.beforeClear(markerClear, unit: unit, puzzle: &puzzle, result: &lineSquare)
            var result = lineSquare
            Resolver.holdings(context, run: run, puzzle: puzzle, into: &result)
            let secondPrint = (puzzle.scoringVersion < 2 || (!isClue && !result.zeroed))
                && puzzle.consume(.secondPrint)

            if secondPrint { BuffRuntime.markTriggered(Buffs.secondPrint, puzzle: &puzzle) }

            // Clue clears never score, including on Onyx.
            let lineReceipt = receipt(base: 45, result: result, square: lineSquare,
                puzzle: puzzle, event: .lineClear, digit: digit, coinsBefore: run.coins, clueZero: isClue,
                doubler: secondPrint ? "bf_second_print" : nil)
            BossScoring.commitReceipt(lineReceipt, isClue: isClue, puzzle: &puzzle)
            if naturalEligibility && lineReceipt.points > 0 { observation.positiveClearUnits.append(unit) }
            if puzzle.phase == .playing {
                BuffRuntime.recordPoints(id: lotID + "." + unit.rawValue, points: lineReceipt.points,
                    eligible: observation.isEligible && !isClue, originalPlacement: false, puzzle: &puzzle)
            }
            outcome.lineClears.append(unit)
            outcome.lineClearPoints.append(lineReceipt.points)
            if puzzle.phase == .keepFilling {
                puzzle.keepFillingCoins += 1
            } else {
                append(lineReceipt, to: &puzzle, outcome: &outcome)
                if !isClue || puzzle.scoringVersion < 2 {
                    collectHeldMultiplier(result, minus: lineSquare, into: &puzzle)
                }
            }
            apply(result, &run, &puzzle, into: &outcome)
        }

        // --- Full Clear -------------------------------------------------------
        if puzzle.board.isFull {
            let context = Resolver.context(.fullClear, run: run, puzzle: puzzle,
                                           digit: digit, square: square, isClue: isClue,
                                           boardCountBefore: countBefore)
            let fullSquare = Resolver.square(context, run: run, puzzle: puzzle)
            var result = fullSquare
            Resolver.holdings(context, run: run, puzzle: puzzle, into: &result)
            let fullReceipt = receipt(base: 500, result: result, square: fullSquare,
                puzzle: puzzle, event: .fullClear, digit: digit, coinsBefore: run.coins, clueZero: isClue, doubler: nil)
            if puzzle.phase == .playing {
                BuffRuntime.recordPoints(id: lotID + ".full", points: fullReceipt.points,
                    eligible: observation.isEligible && !isClue, originalPlacement: false, puzzle: &puzzle)
            }
            outcome.fullClear = true
            outcome.fullClearPoints = fullReceipt.points
            if puzzle.phase == .keepFilling {
                puzzle.keepFillingCoins += 3
            } else {
                append(fullReceipt, to: &puzzle, outcome: &outcome)
                if !isClue || puzzle.scoringVersion < 2 {
                    collectHeldMultiplier(result, minus: fullSquare, into: &puzzle)
                }
            }
            apply(result, &run, &puzzle, into: &outcome)
        }

        let beforeBookmarkHand = puzzle.hand.count
        let afterBookmark = BookmarkMechanics.afterPlacement(observation, run: &run, puzzle: &puzzle)
        outcome.numbersDrawn += max(0, puzzle.hand.count - beforeBookmarkHand)
        if puzzle.scoringVersion >= 2 {
            var coins = run.coins
            for contribution in afterBookmark.contributions where contribution.coins != 0 {
                let operation = ScoreOperation(id: "t\(puzzle.turnNumber).after.coins.\(puzzle.turnScoringOperations.count)",
                    sourceID: contribution.sourceID,
                    sourceInstanceID: contribution.instanceID ?? contribution.sourceID,
                    sourceName: contribution.name,
                    trigger: contribution.sourceID == Bookmarks.issueTracker ? .lineClear : .place,
                    scope: .economy, kind: .coins, amount: Double(contribution.coins),
                    before: ScoreValues(coins: coins), after: ScoreValues(coins: coins + contribution.coins))
                coins += contribution.coins
                puzzle.turnScoringOperations.append(operation)
                outcome.scoreReceipts.append(ScoreEventReceipt(event: operation.trigger, base: 0, points: 0,
                    contributions: [contribution], operations: [operation]))
            }
        }
        apply(afterBookmark, &run, &puzzle, into: &outcome)
        let beforeMarkerHand = puzzle.hand.count
        let beforeMarkerCoins = run.coins
        var markerObservation = observation
        markerObservation.isEligible = naturalEligibility
        MarkerRuntime.afterPlacement(markerObservation, run: &run, puzzle: &puzzle)
        run.puzzle = puzzle
        let beforeBuffOperations = puzzle.turnScoringOperations.count
        let buffAwards = BuffRuntime.didPlace(observation, run: &run)
        puzzle = run.puzzle ?? puzzle
        // didPlace has already queued the awards. Forward the exact applied
        // operations for animation without dispatching or adding points again.
        let appliedBuffOperations = puzzle.turnScoringOperations.dropFirst(beforeBuffOperations)
        for award in buffAwards {
            let operations = appliedBuffOperations.filter {
                $0.sourceID == award.definition && $0.sourceInstanceID == award.source.uuidString
            }
            let applied = operations.reduce(0) { $0 + Int($1.amount) }
            outcome.scoreReceipts.append(ScoreEventReceipt(event: .place, base: 0, points: applied,
                contributions: [ScoreContribution(sourceID: award.definition,
                    instanceID: award.source.uuidString, name: Catalog.item(award.definition)?.name ?? "Buff",
                    flat: applied)], operations: operations))
        }
        outcome.numbersDrawn += max(0, puzzle.hand.count - beforeMarkerHand)
        outcome.coinsEarned += run.coins - beforeMarkerCoins
        if !puzzle.bookmarkState.legacyTurn {
            puzzle.turnScoringState?.observedItemState = puzzle.itemState
        }
        BossScoring.afterCorrectFill(square: square, isClue: isClue, run: run, puzzle: &puzzle)
        BossRuntime.acceptedCorrect(digit: digit, completedUnits: completedUnits, puzzle: &puzzle)
        if let carryReceipt = BossScoring.releaseCarryOnFullClear(puzzle: &puzzle) {
            // This is already earned, already applied carried score. It is a
            // presentation receipt only, never a second queue contribution.
            outcome.scoreReceipts.append(carryReceipt)
        }

        // A zero-point final card still owes the normal Turn-end effects.
        // Let automatic/manual banking decide win/loss after direct payouts.
        if puzzle.phase == .keepFilling { updatePhase(&puzzle) }
        return outcome
    }

    private static func receipt(base: Int, originalBase: Int? = nil, result: EffectResult,
                                square: EffectResult, puzzle: PuzzleState, event: GameEvent, digit: Digit?, coinsBefore: Int,
                                clueZero: Bool, doubler: String?) -> ScoreEventReceipt {
        if puzzle.scoringVersion >= 2 {
            return Resolver.scoredEvent(base: base, originalBase: originalBase, result: result,
                square: square, puzzle: puzzle, event: event, digit: digit, isClueZero: clueZero,
                doubler: doubler, sequence: puzzle.turnScoringOperations.count, coinsBefore: coinsBefore)
        }
        let points = clueZero ? 0 : Resolver.points(base: base, result: queued(result, square: square),
                                                   globalAdditive: 0, oneShotDoubler: doubler != nil)
        return ScoreEventReceipt(event: event, base: base, points: points, contributions: result.contributions)
    }

    private static func append(_ receipt: ScoreEventReceipt, to puzzle: inout PuzzleState,
                               outcome: inout PlacementOutcome) {
        let before = puzzle.pendingBase
        puzzle.pendingBase = ScoreMath.add(before, receipt.points)
        var receipt = receipt
        if puzzle.scoringVersion >= 2 {
            receipt.operations.append(ScoreOperation(id: "t\(puzzle.turnNumber).q.\(puzzle.turnScoringOperations.count)",
                sourceID: "queue", sourceInstanceID: "queue", sourceName: "Added to queue",
                trigger: receipt.event, scope: .turn, kind: .queue, amount: Double(receipt.points),
                before: ScoreValues(points: Double(before)), after: ScoreValues(points: Double(puzzle.pendingBase))))
            puzzle.turnScoringOperations += receipt.operations
        }
        if receipt.points != 0 || puzzle.scoringVersion >= 2 { outcome.scoreReceipts.append(receipt) }
    }

    /// Applies everything in a result that is not points: coins, draws, state
    /// writes, extra Turns and Clues.
    private static func apply(_ result: EffectResult,
                              _ run: inout RunState,
                              _ puzzle: inout PuzzleState,
                              into outcome: inout PlacementOutcome) {
        run.absorb(result)
        puzzle.absorb(result)
        outcome.coinsEarned += result.coins
        if puzzle.phase == .playing, result.directScore > 0 {
            for c in result.contributions where c.directScore > 0 {
                let before = puzzle.score
                BossEncounterRules.addScore(c.directScore, puzzle: &puzzle)
                puzzle.turnScoringOperations.append(ScoreOperation(id: "direct.\(puzzle.turnNumber).\(puzzle.turnScoringOperations.count)",
                    sourceID: c.sourceID, sourceInstanceID: c.instanceID ?? c.sourceID, sourceName: c.name,
                    trigger: .place, scope: .turn, kind: .directScore, amount: Double(puzzle.score - before),
                    before: ScoreValues(score: before), after: ScoreValues(score: puzzle.score)))
            }
        }


        if result.redrawHand { redrawHand(&run, &puzzle) }
        if result.draws > 0 {
            let before = puzzle.hand.count
            if puzzle.boss == .lateCourier {
                var remaining = result.draws
                for source in result.contributions where (source.draws ?? 0) > 0 && remaining > 0 {
                    let count = min(remaining, source.draws ?? 0)
                    let isMarker = Catalog.item(source.sourceID)?.kind == .marker
                    if BossRuntime.deferAutomaticDraw(count: count, sourceID: source.sourceID,
                        sourceInstanceID: isMarker ? nil : source.instanceID.flatMap(UUID.init(uuidString:)),
                        sourceClaimID: isMarker ? source.instanceID : nil, puzzle: &puzzle) {
                        remaining -= count
                    }
                }
                if remaining > 0 {
                    _ = BossRuntime.deferAutomaticDraw(count: remaining, sourceID: "item.draw", puzzle: &puzzle)
                }
            } else {
                let drawn = puzzle.pool.draw(&run.streams.pool, count: result.draws)
                puzzle.appendHandDigits(drawn)
                if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle) }
            }
            outcome.numbersDrawn += puzzle.hand.count - before
        }
    }

    private static func redrawHand(_ run: inout RunState, _ puzzle: inout PuzzleState) {
        let returned = puzzle.removeAllHandCards()
        BuffRuntime.invalidateCards(Set(returned.map(\.id)), puzzle: &puzzle)
        MarkerRuntime.interrupt(.exchange, puzzle: &puzzle)
        for card in returned { puzzle.pool.put(card.digit) }
        let drawn = puzzle.pool.draw(&run.streams.pool, count: puzzle.drawableHandSize)
        puzzle.appendHandDigits(drawn)
        if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle) }
    }

    // MARK: - Toss

    /// §5.1, revised — one number at a time, and the allowance is for the whole
    /// Puzzle rather than for each Turn. Multi-select plus a per-Turn budget let
    /// a player reshape the Hand every Turn, which is most of the Pool's
    /// pressure gone; a small per-Puzzle budget makes each Toss a decision.
    ///
    /// The Hand still only refills at the end of a Turn, so a Toss is paid for
    /// in tempo as well as out of the allowance.
    @discardableResult
    public static func toss(_ run: inout RunState, handIndex: Int) throws -> Digit {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        guard puzzle.hand.indices.contains(handIndex) else { throw PlacementError.numberNotInHand }
        guard !puzzle.isTossBlocked(handIndex: handIndex) || BuffRuntime.releaseAllows(handIndex: handIndex, puzzle: puzzle) else { throw PlacementError.numberBlocked }
        guard puzzle.tossesRemaining > 0 else { throw PlacementError.tossAllowanceSpent }

        puzzle.ensureHandIdentities(seed: run.seed)
        BossScoring.pinBookmarkOrder(run: run, puzzle: &puzzle)
        let card = puzzle.removeHandCard(at: handIndex)
        let digit = card.digit
        puzzle.pool.put(digit)
        puzzle.spendTossCharge()
        BuffRuntime.acceptedAttempt(cardID: card.id, square: nil, puzzle: &puzzle)
        BuffRuntime.invalidateCards([card.id], puzzle: &puzzle)
        MarkerRuntime.interrupt(.toss, puzzle: &puzzle)
        BookmarkMechanics.afterToss(run: &run, puzzle: &puzzle)

        puzzle.assertConservation()
        run.puzzle = puzzle
        _ = try finishAutomaticTurnIfNeeded(&run)
        return digit
    }

    // MARK: - Clue

    /// Spend a Clue on a playable card, showing one place it belongs without
    /// playing it. Re-inspecting the same paid destination never charges twice.
    @discardableResult
    public static func revealClue(_ run: inout RunState, handIndex: Int) throws -> Square {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle,
              puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        guard puzzle.boss?.disablesClues != true else { throw PlacementError.cluesDisabled }
        guard puzzle.hand.indices.contains(handIndex) else { throw PlacementError.numberNotInHand }
        guard !puzzle.isBlocked(handIndex: handIndex) || BuffRuntime.releaseAllows(handIndex: handIndex, puzzle: puzzle) else { throw PlacementError.numberBlocked }
        let digit = puzzle.hand[handIndex]
        let destinations = puzzle.board.blanks.filter {
            puzzle.board.correctDigit(at: $0) == digit && !puzzle.isBarred($0)
        }
        if let revealed = destinations.first(where: { puzzle.clueReveals.contains($0) }) {
            return revealed
        }
        guard puzzle.cluesRemaining > 0 else { throw PlacementError.noCluesLeft }
        guard let destination = destinations.first else { throw PlacementError.noClueDestination }
        BossScoring.pinBookmarkOrder(run: run, puzzle: &puzzle)
        puzzle.cluesRemaining -= 1
        BookmarkMechanics.clueSpent(puzzle: &puzzle)
        MarkerRuntime.interrupt(.clue, puzzle: &puzzle)
        puzzle.clueReveals.insert(destination)
        run.puzzle = puzzle
        return destination
    }

    /// §5 — fills a chosen Blank with its correct number, taken from the Pool,
    /// or from the Hand if the Pool has none left. Scores 0.
    @discardableResult
    public static func useClue(_ run: inout RunState, square: Square) throws -> PlacementOutcome {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        guard puzzle.boss?.disablesClues != true else { throw PlacementError.cluesDisabled }
        guard puzzle.cluesRemaining > 0 else { throw PlacementError.noCluesLeft }
        guard puzzle.board.isBlank(square) else { throw PlacementError.squareNotBlank }
        guard !puzzle.isBarred(square) else { throw PlacementError.squareBarred }

        puzzle.ensureHandIdentities(seed: run.seed)
        let handBefore = puzzle.handCards
        var usedCard: CatalogueHandCard?
        let digit = puzzle.board.correctDigit(at: square)
        if puzzle.pool[digit] > 0 {
            _ = puzzle.pool.take(digit)
        } else if let index = puzzle.hand.indices.first(where: {
            puzzle.hand[$0] == digit && (!puzzle.isBlocked(handIndex: $0)
                || BuffRuntime.releaseAllows(handIndex: $0, puzzle: puzzle))
        }) {
            usedCard = puzzle.removeHandCard(at: index)
        } else {
            if puzzle.hand.contains(digit) { throw PlacementError.numberBlocked }
            // The conservation rule makes an absent digit unreachable.
            throw PlacementError.numberNotInHand
        }
        BossScoring.pinBookmarkOrder(run: run, puzzle: &puzzle)
        puzzle.bossState.placementStarted = true
        BuffRuntime.acceptedAttempt(cardID: usedCard?.id, square: square, puzzle: &puzzle)
        if let usedCard { BuffRuntime.invalidateCards([usedCard.id], puzzle: &puzzle) }
        puzzle.cluesRemaining -= 1
        BookmarkMechanics.clueSpent(puzzle: &puzzle)
        MarkerRuntime.interrupt(.clue, puzzle: &puzzle)
        puzzle.clueReveals.remove(square)
        var outcome = resolveCorrect(&run, &puzzle, digit: digit, square: square, isClue: true, card: usedCard, handBefore: handBefore)

        puzzle.assertConservation()
        run.puzzle = puzzle
        outcome.automaticTurn = try finishAutomaticTurnIfNeeded(&run)
        endBookIfPuzzleFailed(&run)
        return outcome
    }

    // MARK: - Buff

    /// §5 — use a held Buff. It is consumed. `digit` is only read by Paper
    /// Crane, which asks the player to choose a number.
    @discardableResult
    public static func useBuff(_ run: inout RunState, index: Int, digit: Digit? = nil) throws -> Bool {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        if let puzzle = run.puzzle, puzzle.phase != .playing && puzzle.phase != .keepFilling {
            throw PlacementError.puzzleNotPlayable
        }
        guard run.buffs.indices.contains(index) else { return false }
        if run.puzzle?.boss?.disablesBuffs == true { throw PlacementError.buffsDisabled }
        let source = run.buffs[index]
        if [Buffs.peek, Buffs.litmus].contains(source.defID), run.puzzle?.boss?.disablesClues == true {
            throw PlacementError.cluesDisabled
        }
        let usesDigit = [Buffs.paperCrane, Buffs.litmus, Buffs.indexRequest].contains(source.defID)
        let choice: BuffChoice = usesDigit ? (digit.map(BuffChoice.digit) ?? .none) : .none
        guard BuffRuntime.options(for: source.defID, run: run).contains(where: { $0.choice == choice }) else { return false }
        let result = try BuffRuntime.use(BuffUseRequest(buffID: source.id, context: BuffRuntime.context(run), choice: choice), run: &run)
        if result.consumedID != nil || run.puzzle?.bossState.pendingAutoEnd == true {
            _ = try finishAutomaticTurnIfNeeded(&run)
        }
        return result.consumedID != nil
    }

    // MARK: - End Turn

    /// All automatic reasons share this one boundary. A pending item choice
    /// keeps the intent saved until its final accepted resolution; no callback
    /// can bank the same four fills or empty Hand for a second time.
    @discardableResult
    public static func finishAutomaticTurnIfNeeded(_ run: inout RunState) throws -> TurnResult? {
        guard run.pendingItemDecisions.isEmpty, let puzzle = run.puzzle,
              puzzle.phase == .playing || puzzle.phase == .keepFilling,
              puzzle.bossState.pendingAutoEnd || puzzle.hand.isEmpty || puzzle.board.isFull else { return nil }
        return try endTurn(&run)
    }

    public struct TurnResult: Sendable, Equatable {
        public var contributions: [ScoreContribution] = []
        public var scoringLedger: ScoreLedger?
        public var queuedBase = 0
        public var multiplier = 1.0
        public var pointsGained = 0
        public var coinsGained = 0
        public var numbersDrawn = 0
        public var turnsExhausted = false
        /// The Turn did not meet the target. Inspect the Puzzle phase to
        /// distinguish a pending rescue (`outOfTurns`) from terminal failure.
        public var puzzleFailed = false
        /// Obstacle III only: the number barred for the coming Turn.
        public var blockedDigit: Digit?
        /// Obstacle III and Handy Dandy together can bar up to three digits.
        public var blockedDigits: Set<Digit> = []
        public var barredSquares: Set<Square> = []
    }

    /// §4 — ending a Turn refills the Hand from the Pool up to hand size;
    /// unplaced numbers carry over. Refills happen only here, which is what
    /// makes a Toss cost tempo.
    @discardableResult
    public static func endTurn(_ run: inout RunState) throws -> TurnResult {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }

        var turn = TurnResult()
        BossScoring.pinBookmarkOrder(run: run, puzzle: &puzzle)
        BookmarkMechanics.actionAccepted(puzzle: &puzzle)
        puzzle.lockScoringOrder(run: run)

        let wasTenthTurn = puzzle.turnNumber == Baseline.turns
        let context = Resolver.context(.turnEnd, run: run, puzzle: puzzle)
        var result = Resolver.dispatch(context, run: run, puzzle: puzzle)
        result.merge(BookmarkMechanics.turnEnd(run: run, puzzle: &puzzle))
        // Evening Edition is deliberately a Turn 10 payout, not an abstract
        // cash-out bonus. Dispatch its catalogue hook before score banking so
        // the final-turn points can meet the Puzzle target.
        if wasTenthTurn {
            let endContext = Resolver.context(.puzzleEnd, run: run, puzzle: puzzle)
            let endResult = Resolver.dispatch(endContext, run: run, puzzle: puzzle)
            result.directScore += endResult.directScore
            result.contributions += endResult.contributions
            run.absorb(endResult)
            puzzle.absorb(endResult)
        }
        if puzzle.phase != .keepFilling {
            BossScoring.prepareBank(puzzle: &puzzle)
            turn.queuedBase = puzzle.pendingBase
            let preview = puzzle.pendingScoringLedger
            turn.multiplier = preview.multiplier
            turn.contributions = result.contributions
            var ledger = preview
            ledger.operations = puzzle.turnScoringOperations + preview.operations
            let scoreBefore = puzzle.score
            // bankPending uses pendingScore, the same bankable delta exposed
            // by this preview, and clears the completed Turn's queue.
            puzzle.bankPending()
            BossScoring.didBank(preview: preview, puzzle: &puzzle)
            var bankValues = ScoreValues(points: Double(preview.points), mult: preview.multiplier, score: scoreBefore)
            let before = bankValues
            bankValues.score = puzzle.score
            ledger.operations.append(ScoreOperation(id: "t\(ledger.turnNumber).bank", sourceID: "bank",
                sourceInstanceID: "bank", sourceName: "BANKED", trigger: .turnEnd, scope: .turn,
                kind: .bank, amount: Double(puzzle.score - scoreBefore), before: before, after: bankValues))
            // Printed direct payouts are never multiplied. Record exactly the
            // arithmetic applied, including saturation and the final total.
            for c in result.contributions {
                if c.directScore != 0 {
                    let before = bankValues
                    BossEncounterRules.addScore(c.directScore, puzzle: &puzzle)
                    bankValues.score = puzzle.score
                    let actualAward = bankValues.score - before.score
                    if c.directScore > actualAward { ledger.scoreLimitApplied = true }
                    ledger.operations.append(ScoreOperation(id: "t\(ledger.turnNumber).direct.\(ledger.operations.count)",
                        sourceID: c.sourceID, sourceInstanceID: c.instanceID ?? c.sourceID,
                        sourceName: c.name, trigger: .turnEnd, scope: .turn, kind: .directScore,
                        amount: Double(actualAward), before: before, after: bankValues))
                }
            }
            turn.pointsGained = puzzle.score - scoreBefore
            ledger.total = turn.pointsGained
            turn.scoringLedger = ledger
            puzzle.lastScoringLedger = ledger
            BossEncounterRules.didBank(puzzle: &puzzle)
            BookmarkMechanics.didBank(ordinaryBank: preview.total, puzzle: &puzzle)
        } else {
            // Keep Filling freezes score, but its coin/draw build still has a
            // Turn boundary. A sold or reordered item must not remain locked.
            puzzle.turnScoringState = nil
            puzzle.turnScoringOperations = []
            puzzle.scoringVersion = 2
        }
        run.absorb(result)
        puzzle.absorb(result)
        turn.coinsGained = result.coins
        updatePhase(&puzzle)

        let exhaustedBankLimit = BossEncounterRules.bankLimit(boss: puzzle.boss).map {
            puzzle.bossState.encounter.banksUsed >= $0
        } ?? false
        let wasLastTurn = exhaustedBankLimit || puzzle.turnNumber >= puzzle.turnsMax
        BuffRuntime.didBank(puzzle: &puzzle)
        MarkerRuntime.endTurn(puzzle: &puzzle)
        BookmarkMechanics.turnStarted(puzzle: &puzzle)
        BossRuntime.boundaryStarted(puzzle: &puzzle)
        puzzle.turnNumber += 1

        turn.numbersDrawn += BossRuntime.beforeRefill(run: &run, puzzle: &puzzle)

        let needed = max(0, puzzle.handSize - puzzle.hand.count)
        if needed > 0 {
            let drawn = puzzle.pool.draw(&run.streams.pool, count: needed)
            puzzle.appendHandDigits(drawn)
            if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle) }
            turn.numbersDrawn += drawn.count
        }

        let beforeDeferredRefill = puzzle.hand.count
        BookmarkMechanics.afterPlayableRefill(run: &run, puzzle: &puzzle)
        turn.numbersDrawn += puzzle.hand.count - beforeDeferredRefill

        // Obstacle III onward bars numbers after the refill, so every block
        // is drawn from the Hand the player will actually hold.
        puzzle.startObstacleTurn(&run)
        turn.blockedDigit = puzzle.blockedDigit
        puzzle.startBossTurn(&run)
        turn.blockedDigits = puzzle.blockedDigits
        turn.barredSquares = puzzle.barredSquares

        if wasLastTurn {
            turn.turnsExhausted = true
            switch puzzle.phase {
            case .playing where !BossEncounterRules.targetSatisfied(puzzle: puzzle):
                turn.puzzleFailed = true
                // The usual banking, refill, and next-Turn restrictions above
                // have already run once. Pause that exact state for the offer;
                // claiming a reward must not redraw or reroll it a second time.
                puzzle.phase = exhaustedBankLimit || puzzle.rewardedRescueUsed ? .failed : .outOfTurns
            case .keepFilling:
                // Keep Filling runs on the Turns you had left, so when they are
                // gone the Puzzle is over and the banked coins are paid out.
                puzzle.phase = .won
            default:
                break
            }
        }

        puzzle.assertConservation()
        run.puzzle = puzzle
        BookmarkMechanics.enqueueChoices(run: &run)
        endBookIfPuzzleFailed(&run)
        return turn
    }

    // MARK: - One-time rewarded rescue

    public static func canClaimRewardedRescue(_ run: RunState) -> Bool {
        pendingRewardedRescue(in: run) != nil
    }

    /// Resume the already-prepared next Turn without replaying its effects or
    /// touching any random stream. The app owns ad verification and identity;
    /// this rule only accepts the currently pending, unused Puzzle rescue.
    @discardableResult
    public static func claimRewardedRescue(_ run: inout RunState) -> Bool {
        guard var puzzle = pendingRewardedRescue(in: run) else { return false }
        puzzle.turnsMax += 3
        puzzle.rewardedRescueUsed = true
        puzzle.phase = .playing
        BookmarkMechanics.afterPlayableRefill(run: &run, puzzle: &puzzle)
        run.puzzle = puzzle
        BookmarkMechanics.enqueueChoices(run: &run)
        return true
    }

    @discardableResult
    public static func declineRewardedRescue(_ run: inout RunState) -> Bool {
        guard var puzzle = pendingRewardedRescue(in: run) else { return false }
        puzzle.phase = .failed
        puzzle.bossState.scoring.serialCarry = 0
        run.puzzle = puzzle
        run.outcome = .failed
        return true
    }

    private static func pendingRewardedRescue(in run: RunState) -> PuzzleState? {
        guard run.outcome == nil, let puzzle = run.puzzle,
              puzzle.boss != .lastEdition, puzzle.phase == .outOfTurns, !puzzle.rewardedRescueUsed,
              puzzle.turnNumber > puzzle.turnsMax,
              !BossEncounterRules.targetSatisfied(puzzle: puzzle),
              !puzzle.board.isFull else { return nil }
        return puzzle
    }

    // MARK: - Ending a Puzzle (§7)

    static func updatePhase(_ puzzle: inout PuzzleState) {
        // A correct placement is not a banked score until its Turn ends.
        // Leaving the phase playable lets an empty Hand use that same end-Turn
        // path instead of stranding the queued points.
        guard puzzle.pendingBase == 0 else { return }
        if puzzle.phase == .playing && BossEncounterRules.targetSatisfied(puzzle: puzzle) {
            puzzle.phase = .won
        }
        // The board filling below target is an immediate loss — there are
        // exactly as many numbers as Blanks, so nothing can be recovered.
        if puzzle.phase == .playing && puzzle.board.isFull && !BossEncounterRules.targetSatisfied(puzzle: puzzle)
            && puzzle.boss != .lastEdition {
            puzzle.phase = .failed
        }
        // Nothing left to bank once the board is full.
        if puzzle.phase == .keepFilling && puzzle.board.isFull {
            puzzle.phase = .won
        }
    }

    /// Bank the payout and go to the Shop.
    @discardableResult
    public static func cashOut(_ run: inout RunState) throws -> RunState.Payout {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .won || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        guard BossEncounterRules.completionQualified(puzzle: puzzle) else { throw PlacementError.puzzleNotPlayable }
        let payout = run.payout(for: puzzle)
        run.coins += payout.total
        run.bestPuzzleScore = max(run.bestPuzzleScore, puzzle.score)

        // Syndication grows only on a Puzzle you win (§10).
        if BookmarkMechanics.owns(Bookmarks.syndication, run: run, puzzle: puzzle) {
            run.runItemState[Bookmarks.syndication] = (run.runItemState[Bookmarks.syndication] ?? 0) + 1
        }

        BookmarkMechanics.puzzleWon(run: &run, puzzle: &puzzle)
        puzzle.bankedPayout = payout
        puzzle.bossState.scoring.serialCarry = 0
        puzzle.phase = .cashedOut
        run.puzzle = puzzle
        BuffRuntime.didEndPuzzle(&run)
        return payout
    }

    /// §7 — carry on with the remaining Turns. Score no longer increases;
    /// clears bank coins instead. No risk, since the Puzzle is already won.
    public static func keepFilling(_ run: inout RunState) throws {
        guard run.pendingItemDecisions.isEmpty else { throw PlacementError.puzzleNotPlayable }
        guard var puzzle = run.puzzle, puzzle.canKeepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        puzzle.phase = .keepFilling
        run.puzzle = puzzle
    }
}
