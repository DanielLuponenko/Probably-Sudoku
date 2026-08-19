import Foundation

/// The five things a player can do in a Turn (§5), plus ending the Puzzle (§7).
/// Every one of them takes the whole `RunState` because items, coins and the
/// board all move together.
public enum Actions {

    // MARK: - Place

    /// Put a number from the Hand on a Blank. Correct scores; wrong is penalised.
    @discardableResult
    public static func place(_ run: inout RunState, handIndex: Int, square: Square) throws -> PlacementOutcome {
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        guard puzzle.hand.indices.contains(handIndex) else { throw PlacementError.numberNotInHand }
        guard puzzle.board.isBlank(square) else { throw PlacementError.squareNotBlank }

        let digit = puzzle.hand[handIndex]
        let outcome: PlacementOutcome
        if digit == puzzle.board.correctDigit(at: square) {
            puzzle.hand.remove(at: handIndex)
            outcome = resolveCorrect(&run, &puzzle, digit: digit, square: square, isClue: false)
        } else {
            puzzle.hand.remove(at: handIndex)
            outcome = resolveWrong(&run, &puzzle, digit: digit, square: square)
        }

        puzzle.assertConservation()
        run.puzzle = puzzle
        return outcome
    }

    /// §6 — a wrong placement subtracts `50 x the number`, doubled by The
    /// Critic, cancelled by an Ivory Marker on the square or an armed
    /// Insurance. The number goes back to the Pool, or to the Hand under Jade.
    private static func resolveWrong(_ run: inout RunState, _ puzzle: inout PuzzleState,
                                     digit: Digit, square: Square) -> PlacementOutcome {
        let context = Resolver.context(.wrongPlace, run: run, puzzle: puzzle,
                                       digit: digit, square: square)
        let result = Resolver.dispatch(context, run: run, puzzle: puzzle)

        var cancelled = result.zeroed
        if !cancelled, puzzle.consume(.insurance) { cancelled = true }

        let doubled = puzzle.boss?.doublesWrongPenalty == true
        let penalty = cancelled ? 0 : 50 * digit.rawValue * (doubled ? 2 : 1)
        puzzle.score = max(0, puzzle.score - penalty)

        if result.wrongReturnsToHand {
            puzzle.hand.append(digit)
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
                                       digit: Digit, square: Square, isClue: Bool) -> PlacementOutcome {
        var outcome = PlacementOutcome()
        outcome.correct = true

        let countBefore = puzzle.board.count(of: digit)
        puzzle.board.fill(square, with: digit, by: isClue ? .clue : .player)
        let completedUnits = puzzle.board.unitsCompleted(at: square)
        let globalAdditive = Resolver.globalAdditive(puzzle)

        // --- The placement itself -------------------------------------------
        let placeContext = Resolver.context(.place, run: run, puzzle: puzzle,
                                            digit: digit, square: square, isClue: isClue,
                                            boardCountBefore: countBefore,
                                            completesLine: !completedUnits.isEmpty)
        var placeResult = Resolver.dispatch(placeContext, run: run, puzzle: puzzle)
        placeResult.flat += Int(puzzle.itemState[Buffs.paperCraneKey(digit)] ?? 0)

        // A Clue scores nothing unless an Onyx Marker on that square restores it.
        let clueEarnsPoints = !isClue || placeResult.clueScoresPlacement
        let doubleDown = !isClue && puzzle.consume(.doubleDown)
        let base = 10 * (placeResult.baseOverride ?? digit).rawValue

        outcome.points = clueEarnsPoints
            ? Resolver.points(base: base, result: placeResult,
                              globalAdditive: globalAdditive, oneShotDoubler: doubleDown)
            : 0
        outcome.censored = placeResult.zeroed
        if puzzle.phase != .keepFilling { puzzle.score += outcome.points }
        apply(placeResult, &run, &puzzle, into: &outcome)

        // --- Each completed row, column and box ------------------------------
        for unit in completedUnits {
            let context = Resolver.context(.lineClear, run: run, puzzle: puzzle,
                                           digit: digit, square: square, unit: unit, isClue: isClue,
                                           boardCountBefore: countBefore, completesLine: true)
            let result = Resolver.dispatch(context, run: run, puzzle: puzzle)
            let secondPrint = puzzle.consume(.secondPrint)

            // A Line Clear caused by a Clue always scores 0, even under Onyx.
            let lineScore = isClue ? 0 : Resolver.points(
                base: 45, result: result,
                globalAdditive: Resolver.globalAdditive(puzzle), oneShotDoubler: secondPrint)

            outcome.lineClears.append(unit)
            outcome.lineClearPoints.append(lineScore)
            if puzzle.phase == .keepFilling {
                puzzle.keepFillingCoins += 1     // §7 — the greed mechanic
            } else {
                puzzle.score += lineScore
            }
            apply(result, &run, &puzzle, into: &outcome)
        }

        // --- Full Clear -------------------------------------------------------
        if puzzle.board.isFull {
            let context = Resolver.context(.fullClear, run: run, puzzle: puzzle,
                                           digit: digit, square: square, isClue: isClue,
                                           boardCountBefore: countBefore)
            let result = Resolver.dispatch(context, run: run, puzzle: puzzle)
            let fullScore = isClue ? 0 : Resolver.points(
                base: 500, result: result,
                globalAdditive: Resolver.globalAdditive(puzzle), oneShotDoubler: false)

            outcome.fullClear = true
            outcome.fullClearPoints = fullScore
            if puzzle.phase == .keepFilling {
                puzzle.keepFillingCoins += 3
            } else {
                puzzle.score += fullScore
            }
            apply(result, &run, &puzzle, into: &outcome)
        }

        updatePhase(&puzzle)
        return outcome
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

        if result.redrawHand { redrawHand(&run, &puzzle) }
        if result.draws > 0 {
            let before = puzzle.hand.count
            puzzle.hand.append(contentsOf: puzzle.pool.draw(&run.streams.pool, count: result.draws))
            outcome.numbersDrawn += puzzle.hand.count - before
        }
    }

    private static func redrawHand(_ run: inout RunState, _ puzzle: inout PuzzleState) {
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = puzzle.pool.draw(&run.streams.pool, count: puzzle.handSize)
    }

    // MARK: - Toss

    /// §5.1 — a multi-select. What is limited is how many numbers may go back
    /// to the Pool per Turn, not how many times the button is pressed. The Hand
    /// only refills at the end of a Turn, so tossing is paid for in tempo.
    @discardableResult
    public static func toss(_ run: inout RunState, handIndices: [Int]) throws -> Int {
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        let unique = Set(handIndices).filter { puzzle.hand.indices.contains($0) }
        guard !unique.isEmpty else { return 0 }
        guard unique.count <= puzzle.tossesRemaining else { throw PlacementError.tossAllowanceSpent }

        for index in unique.sorted(by: >) {
            puzzle.pool.put(puzzle.hand.remove(at: index))
        }
        puzzle.tossedThisTurn += unique.count

        puzzle.assertConservation()
        run.puzzle = puzzle
        return unique.count
    }

    // MARK: - Clue

    /// §5 — fills a chosen Blank with its correct number, taken from the Pool,
    /// or from the Hand if the Pool has none left. Scores 0.
    @discardableResult
    public static func useClue(_ run: inout RunState, square: Square) throws -> PlacementOutcome {
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.boss?.disablesClues != true else { throw PlacementError.cluesDisabled }
        guard puzzle.cluesRemaining > 0 else { throw PlacementError.noCluesLeft }
        guard puzzle.board.isBlank(square) else { throw PlacementError.squareNotBlank }

        let digit = puzzle.board.correctDigit(at: square)
        if puzzle.pool[digit] > 0 {
            _ = puzzle.pool.take(digit)
        } else if let index = puzzle.hand.firstIndex(of: digit) {
            puzzle.hand.remove(at: index)
        } else {
            // The conservation rule makes this unreachable.
            throw PlacementError.numberNotInHand
        }

        puzzle.cluesRemaining -= 1
        let outcome = resolveCorrect(&run, &puzzle, digit: digit, square: square, isClue: true)

        puzzle.assertConservation()
        run.puzzle = puzzle
        return outcome
    }

    // MARK: - Buff

    /// §5 — use a held Buff. It is consumed. `digit` is only read by Paper
    /// Crane, which asks the player to choose a number.
    @discardableResult
    public static func useBuff(_ run: inout RunState, index: Int, digit: Digit? = nil) throws -> Bool {
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard run.buffs.indices.contains(index) else { return false }

        let def = run.buffs[index].def
        guard let onUse = def.onUse else { return false }

        // `digit` rides along in the context so Paper Crane can read the
        // number the player chose.
        let context = Resolver.context(.shopEnter, run: run, puzzle: puzzle, digit: digit)
        var result = EffectResult()
        onUse(context, &result)

        // Peek's free Clue is still blocked by The Paywall (§13).
        if puzzle.boss?.disablesClues == true { result.extraClues = 0 }

        run.buffs.remove(at: index)
        run.absorb(result)
        puzzle.absorb(result)
        if result.redrawHand { redrawHand(&run, &puzzle) }
        if result.draws > 0 {
            puzzle.hand.append(contentsOf: puzzle.pool.draw(&run.streams.pool, count: result.draws))
        }

        puzzle.assertConservation()
        run.puzzle = puzzle
        return true
    }

    // MARK: - End Turn

    public struct TurnResult: Sendable, Equatable {
        public var pointsGained = 0
        public var coinsGained = 0
        public var numbersDrawn = 0
        public var turnsExhausted = false
        public var puzzleFailed = false
    }

    /// §4 — ending a Turn refills the Hand from the Pool up to hand size;
    /// unplaced numbers carry over. Refills happen only here, which is what
    /// makes a Toss cost tempo.
    @discardableResult
    public static func endTurn(_ run: inout RunState) throws -> TurnResult {
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }

        var turn = TurnResult()

        let context = Resolver.context(.turnEnd, run: run, puzzle: puzzle)
        let result = Resolver.dispatch(context, run: run, puzzle: puzzle)
        if puzzle.phase != .keepFilling {
            puzzle.score += result.directScore
            turn.pointsGained = result.directScore
        }
        run.absorb(result)
        puzzle.absorb(result)
        turn.coinsGained = result.coins
        updatePhase(&puzzle)

        let wasLastTurn = puzzle.turnNumber >= puzzle.turnsMax
        puzzle.turnNumber += 1
        puzzle.tossedThisTurn = 0

        let needed = max(0, puzzle.handSize - puzzle.hand.count)
        if needed > 0 {
            let drawn = puzzle.pool.draw(&run.streams.pool, count: needed)
            puzzle.hand.append(contentsOf: drawn)
            turn.numbersDrawn = drawn.count
        }

        if wasLastTurn {
            turn.turnsExhausted = true
            switch puzzle.phase {
            case .playing where puzzle.score < puzzle.target:
                puzzle.phase = .failed
                turn.puzzleFailed = true
                run.outcome = .failed          // §7 — a failed Puzzle ends the Book
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
        return turn
    }

    // MARK: - Ending a Puzzle (§7)

    private static func updatePhase(_ puzzle: inout PuzzleState) {
        if puzzle.phase == .playing && puzzle.score >= puzzle.target {
            puzzle.phase = .won
        }
        // The board filling below target is an immediate loss — there are
        // exactly as many numbers as Blanks, so nothing can be recovered.
        if puzzle.phase == .playing && puzzle.board.isFull && puzzle.score < puzzle.target {
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
        guard var puzzle = run.puzzle else { throw PlacementError.puzzleNotPlayable }
        guard puzzle.phase == .won || puzzle.phase == .keepFilling else {
            throw PlacementError.puzzleNotPlayable
        }
        let payout = run.payout(for: puzzle)
        run.coins += payout.total

        // Syndication grows only on a Puzzle you win (§10).
        if run.owns(ad: Ads.syndication) {
            run.runItemState[Ads.syndication] = (run.runItemState[Ads.syndication] ?? 0) + 1
        }

        puzzle.phase = .cashedOut
        run.puzzle = puzzle
        return payout
    }

    /// §7 — carry on with the remaining Turns. Score no longer increases;
    /// clears bank coins instead. No risk, since the Puzzle is already won.
    public static func keepFilling(_ run: inout RunState) throws {
        guard var puzzle = run.puzzle, puzzle.phase == .won else {
            throw PlacementError.puzzleNotPlayable
        }
        puzzle.phase = .keepFilling
        run.puzzle = puzzle
    }
}
