import XCTest
@testable import ProbablySudokuEngine

/// Independent integration checks for hooks that can be correct in isolation
/// but lost by the Game transaction, rescue path, or saved-Turn boundary.
final class CatalogueIntegrationReviewTests: XCTestCase {
    private func started(_ bookmarks: [String] = [], coins: Int = 20) throws -> Game {
        var game = Game(seed: "catalogue-integration-review")
        game.run.coins = coins
        game.run.bookmarks = bookmarks.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5) }
        try game.startPuzzle()
        game.run.puzzle?.target = 9_000_000
        return game
    }

    func testCancelBookmarkDecisionCommitsDismissalWithoutSpendingOrBlockingPlay() throws {
        var game = try started([Bookmarks.personalColumn])
        let decision = try XCTUnwrap(game.run.pendingItemDecisions.first)
        let hand = game.puzzle?.handCards
        let coins = game.run.coins
        let streams = game.run.streams
        XCTAssertTrue(try game.resolveItemDecision(id: decision.id, selected: nil))
        XCTAssertTrue(game.run.pendingItemDecisions.isEmpty)
        XCTAssertEqual(game.puzzle?.handCards, hand)
        XCTAssertEqual(game.run.coins, coins)
        XCTAssertEqual(game.run.streams.pool.state, streams.pool.state)
        XCTAssertEqual(game.run.streams.board.state, streams.board.state)
        game = try Game(decoding: game.encoded())
        let digit = try XCTUnwrap(game.puzzle?.hand.first)
        let square = try XCTUnwrap(game.blank(wanting: digit))
        XCTAssertTrue(try game.place(handIndex: 0, at: square).correct)
    }

    func testRescueReleasesDeferredDrawsAndStartChoicesWithoutOrdinaryRefillOrBossReroll() throws {
        var game = try started([Bookmarks.crossReference, Bookmarks.typeCase])
        if let choice = game.run.pendingItemDecisions.first {
            XCTAssertTrue(try game.resolveItemDecision(id: choice.id, selected: nil))
        }
        XCTAssertTrue(game.run.pendingItemDecisions.isEmpty)
        game.run.puzzle?.phase = .outOfTurns
        game.run.puzzle?.turnNumber = 11
        game.run.puzzle?.turnsMax = 10
        game.run.puzzle?.bookmarkState.pendingRefillDraws = 2
        game.run.puzzle?.bookmarkState.turn = .init()
        let hand = try XCTUnwrap(game.puzzle).handCards
        let bossStream = game.run.streams.boss.state
        XCTAssertTrue(game.claimRewardedRescue())
        XCTAssertEqual(game.puzzle?.hand.count, hand.count + 2)
        XCTAssertEqual(Array(game.puzzle!.handCards.prefix(hand.count)), hand)
        XCTAssertEqual(game.puzzle?.bookmarkState.pendingRefillDraws, 0)
        XCTAssertEqual(game.run.streams.boss.state, bossStream)
        XCTAssertEqual(game.run.pendingItemDecisions.first?.kind, "bookmark.type")
        XCTAssertFalse(game.claimRewardedRescue())
    }

    func testEmptyTurnAndSuccessfulBuffUseClosePrePuzzleChoiceWindow() throws {
        var empty = try started([Bookmarks.advancePayment], coins: 0)
        XCTAssertTrue(empty.run.pendingItemDecisions.isEmpty)
        _ = try empty.endTurn()
        XCTAssertTrue(empty.puzzle!.bookmarkState.puzzleActionTaken)
        empty.run.coins = 20
        BookmarkMechanics.enqueueChoices(run: &empty.run)
        XCTAssertFalse(empty.run.pendingItemDecisions.contains { $0.kind == "bookmark.advance" })

        var buff = try started([Bookmarks.advancePayment], coins: 0)
        buff.give(buff: Buffs.redraw)
        XCTAssertTrue(try buff.useBuff(at: 0))
        XCTAssertTrue(buff.puzzle!.bookmarkState.puzzleActionTaken)
        XCTAssertTrue(buff.puzzle!.bookmarkState.turn.actionTaken)
        buff.run.coins = 20
        BookmarkMechanics.enqueueChoices(run: &buff.run)
        XCTAssertTrue(buff.run.pendingItemDecisions.isEmpty)
    }

    func testFailedBuffUseDoesNotCloseFirstActionWindow() throws {
        var game = try started([Bookmarks.advancePayment], coins: 0)
        XCTAssertFalse(try game.useBuff(at: 0))
        XCTAssertFalse(game.puzzle!.bookmarkState.puzzleActionTaken)
        game.run.coins = 3
        BookmarkMechanics.enqueueChoices(run: &game.run)
        XCTAssertEqual(game.run.pendingItemDecisions.first?.kind, "bookmark.advance")
    }

    func testDeferredCrossReferenceRefillReportsActualDrawsExactlyOnce() throws {
        var game = try started([Bookmarks.crossReference])
        game.run.puzzle?.bookmarkState.pendingRefillDraws = 2
        let previous = try XCTUnwrap(game.puzzle).handCards
        let turn = try game.endTurn()
        XCTAssertEqual(turn.numbersDrawn, 2)
        XCTAssertEqual(game.puzzle?.hand.count, previous.count + 2)
        XCTAssertEqual(Array(game.puzzle!.handCards.prefix(previous.count)), previous)
        XCTAssertEqual(game.puzzle?.bookmarkState.pendingRefillDraws, 0)
        game = try Game(decoding: game.encoded())
        XCTAssertEqual(try game.endTurn().numbersDrawn, 0)
        XCTAssertEqual(game.puzzle?.hand.count, previous.count + 2)
    }

    func testCleanFinishPresentsItsAlreadyQueuedAwardWithoutPayingTwice() throws {
        var game = try started()
        var puzzle = try XCTUnwrap(game.puzzle)
        for card in puzzle.removeAllHandCards() { puzzle.pool.put(card.digit) }
        var previewBoard = puzzle.board
        var targets: [Square] = []
        for square in puzzle.board.blanks {
            var candidate = previewBoard
            candidate.fill(square, with: candidate.correctDigit(at: square), by: .player)
            guard candidate.unitsCompleted(at: square).isEmpty else { continue }
            targets.append(square)
            previewBoard = candidate
            if targets.count == 3 { break }
        }
        XCTAssertEqual(targets.count, 3)
        let digits = targets.map { puzzle.board.correctDigit(at: $0) }
        for digit in digits {
            XCTAssertTrue(puzzle.pool.take(digit))
            puzzle.appendHandDigits([digit])
        }
        let capturedCards = puzzle.handCards
        game.run.puzzle = puzzle
        game.give(buff: Buffs.cleanFinish)
        let source = try XCTUnwrap(game.run.buffs.first).id
        XCTAssertTrue(try game.useBuff(at: 0))
        XCTAssertEqual(game.puzzle?.buffState.cleanFinish?.cards, Set(capturedCards.map(\.id)))
        var outcomes: [PlacementOutcome] = []
        for (target, card) in zip(targets, capturedCards) {
            let index = try XCTUnwrap(game.puzzle?.handCards.firstIndex { $0.id == card.id })
            let placed = try game.place(handIndex: index, at: target)
            XCTAssertTrue(placed.lineClears.isEmpty)
            outcomes.append(placed)
        }
        let outcome = try XCTUnwrap(outcomes.last)
        XCTAssertTrue(outcomes.dropLast().allSatisfy { $0.automaticTurn == nil })
        XCTAssertFalse(outcomes.dropLast().flatMap(\.scoreReceipts).contains {
            $0.contributions.contains { $0.sourceID == Buffs.cleanFinish }
        })
        let receipts = outcome.scoreReceipts.filter { $0.contributions.contains { $0.sourceID == Buffs.cleanFinish } }
        XCTAssertEqual(receipts.count, 1)
        XCTAssertEqual(receipts.first?.points, 150)
        XCTAssertEqual(receipts.first?.contributions.first?.instanceID, source.uuidString)
        XCTAssertEqual(receipts.first?.operations.first?.amount, 150)
        let ledger = try XCTUnwrap(outcome.automaticTurn?.scoringLedger)
        XCTAssertEqual(ledger.operations.filter { $0.sourceID == Buffs.cleanFinish && $0.kind == .addPoints }.count, 1)
        let expectedScore = digits.reduce(150) { $0 + $1.rawValue * 10 }
        XCTAssertEqual(ledger.total, expectedScore)
        XCTAssertEqual(game.puzzle?.pendingBase, 0)
        game = try Game(decoding: game.encoded())
        XCTAssertEqual(try game.endTurn().pointsGained, 0)
        XCTAssertEqual(game.puzzle?.score, expectedScore)
    }

    func testCorrectionLedgerRefundsHalfActuallyDeductedThroughRealActions() throws {
        var game = try started([Bookmarks.correctionLedger])
        game.run.puzzle?.score = 19
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let correct = game.puzzle!.board.correctDigit(at: square)
        let wrong: Digit = correct == .nine ? .eight : .nine
        let index = try XCTUnwrap(game.stackHand(with: wrong))
        XCTAssertFalse(try game.place(handIndex: index, at: square).correct)
        XCTAssertEqual(game.puzzle?.score, 0)
        XCTAssertEqual(game.puzzle?.bookmarkState.copies[game.run.bookmarks[0].id]?.correctionAmount, 9)
        for _ in 0..<3 {
            let target = try XCTUnwrap(game.puzzle?.board.blanks.first)
            let digit = game.puzzle!.board.correctDigit(at: target)
            _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: target)
            game = try Game(decoding: game.encoded())
        }
        XCTAssertEqual(game.puzzle?.score, 9)
        let operations = game.puzzle!.turnScoringOperations.filter { $0.sourceID == Bookmarks.correctionLedger && $0.kind == .directScore }
        XCTAssertEqual(operations.count, 1)
        XCTAssertEqual(operations.first?.amount, 9)
    }

    func testHistoricalLockedTurnKeepsItsMultiplierThenSwitchesToNewEligibility() throws {
        var game = try started([Bookmarks.editorialBoard])
        game.run.puzzle?.pendingBase = 50
        var locked = try XCTUnwrap(game.puzzle)
        locked.lockScoringOrder(run: game.run)
        game.run.puzzle = locked
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(object["puzzle"] as? [String: Any])
        puzzle.removeValue(forKey: "bookmarkState")
        object["puzzle"] = puzzle
        game = try Game(decoding: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(game.puzzle!.bookmarkState.legacyTurn)
        XCTAssertEqual(game.puzzle?.pendingScore, 150)
        XCTAssertEqual(try game.endTurn().pointsGained, 150)
        XCTAssertFalse(game.puzzle!.bookmarkState.legacyTurn)
        let digit = try XCTUnwrap(game.puzzle?.hand.first)
        _ = try game.place(handIndex: 0, at: XCTUnwrap(game.blank(wanting: digit)))
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 1)
    }
}
