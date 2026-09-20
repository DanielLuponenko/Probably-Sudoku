import XCTest
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ExpandedBossModelTests: XCTestCase {
    /// A real conserved puzzle with public deterministic givens. All earned
    /// queues below come from accepted engine placements, never fake receipts.
    private func fixture(_ boss: BossModifier, hand: [Digit]) throws -> Game {
        var run = RunState(seed: "boss-model-regressions", book: .noPressure)
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = boss
        var game = Game(run: run)
        try game.startPuzzle()
        run = game.run
        var p = try XCTUnwrap(game.puzzle)
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        _ = p.removeAllHandCards()
        p.board = Board(GeneratedPuzzle(solution: solution, isGiven: Array(repeating: false, count: 81)))
        p.pool = Pool(blanksOf: p.board)
        for digit in hand { XCTAssertTrue(p.pool.take(digit)) }
        p.appendHandDigits(hand)
        p.handSize = max(1, hand.count)
        p.turnsMax = 10; p.target = 1_000_000; p.cluesRemaining = 8
        p.boss = boss; p.bossTurn = nil; p.blockedDigit = nil; p.obstacleBlockedDigits = []
        BossRuntime.puzzleStarted(run: run, puzzle: &p)
        BossRuntime.turnStarted(puzzle: &p)
        run.puzzle = p
        return Game(run: run)
    }

    private func assertConservation(_ game: Game, file: StaticString = #filePath, line: UInt = #line) {
        guard let p = game.puzzle else { return XCTFail("Missing puzzle", file: file, line: line) }
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool,
                                       hand: p.hand + p.markerState.reservedForkCards), file: file, line: line)
    }

    func testLiveSettlementShowsTheArithmeticActuallyPaid() {
        let serial = LiveScoreCalculation(points: 240, multiplier: 6, total: 300, scoreLimitApplied: false,
            bossSettlement: BossBankSettlement(bossID: "serialPublisher", gross: 1_440, paid: 300,
                                               carryBefore: 0, carryAfter: 1_140, limit: 300))
        XCTAssertEqual(serial.compactFactors, "1,440 −1,140 held")
        XCTAssertEqual(serial.factors, ["240 × 6"], "The full source arithmetic stays available for inspection")
        let rival = LiveScoreCalculation(points: 100, multiplier: 1, total: 80, scoreLimitApplied: false,
            bossSettlement: BossBankSettlement(bossID: "rivalColumn", gross: 100, paid: 80, benchmark: 200))
        XCTAssertEqual(rival.compactFactors, "100 −20 fee")
        XCTAssertFalse(rival.scoreLimitApplied, "A boss fee is not an overflow limit")
    }

    func testKeepFillingFullClearShowsSavedSerialCarryWithoutInventingATurnBank() throws {
        for useClue in [false, true] {
            var run = try fixture(.serialPublisher, hand: [.one]).run
            var p = try XCTUnwrap(run.puzzle)
            let solution = p.board.solution
            p.board = Board(GeneratedPuzzle(solution: solution, isGiven: (0..<81).map { $0 != 0 }))
            _ = p.removeAllHandCards()
            p.pool = Pool(blanksOf: p.board)
            XCTAssertTrue(p.pool.take(.one))
            p.appendHandDigits([.one])
            p.target = 900; p.score = 900; p.phase = .won
            p.bossState.scoring.serialStartingTarget = 900
            p.bossState.scoring.serialCarry = 725
            run.puzzle = p
            var saved = Game(run: run)
            try saved.keepFilling()
            let model = GameModel(resuming: try Game(decoding: saved.encoded()), savesProgress: false)
            if useClue { model.useClue(at: Square(0)) }
            else { model.place(handIndex: 0, at: Square(0)) }
            XCTAssertEqual(model.puzzle?.score, 1_625)
            XCTAssertEqual(model.puzzle?.turnNumber, 1)
            XCTAssertEqual(model.puzzle?.bossState.scoring.serialCarry, 0)
            let performance = try XCTUnwrap(model.scorePerformance)
            XCTAssertEqual(performance.bankedFrom, 900)
            XCTAssertEqual(performance.bankCalculation?.total, 725)
            XCTAssertEqual(performance.bankCalculation?.bossSettlement?.carryBefore, 725)
            XCTAssertEqual(performance.bankCalculation?.compactFactors, "725 −0 held")
            XCTAssertEqual(performance.feedbackBeats.filter { $0.kind == .bank }.count, 1)
            let encoded = try model.game.encoded()
            for beat in performance.feedbackBeats { model.advanceScore(beat, performanceID: performance.id) }
            XCTAssertEqual(try model.game.encoded(), encoded)
            let resumed = GameModel(resuming: try Game(decoding: encoded), savesProgress: false)
            XCTAssertNil(resumed.scorePerformance)
            assertConservation(model.game)
        }
    }

    private func assertBank(_ model: GameModel, total: Int, file: StaticString = #filePath, line: UInt = #line) throws {
        let performance = try XCTUnwrap(model.scorePerformance, file: file, line: line)
        XCTAssertEqual(performance.bankCalculation?.total, total, file: file, line: line)
        XCTAssertEqual(model.puzzle?.score, total, file: file, line: line)
        XCTAssertEqual(model.puzzle?.lastScoringLedger?.total, total, file: file, line: line)
        XCTAssertEqual(model.puzzle?.turnNumber, 2, file: file, line: line)
        let bank = try XCTUnwrap(performance.feedbackBeats.first { $0.kind == .bank }, file: file, line: line)
        let saved = try model.game.encoded()
        model.advanceScore(bank, performanceID: performance.id)
        XCTAssertEqual(model.liveScoreCalculation, .empty, file: file, line: line)
        XCTAssertEqual(model.presentedScore, total, file: file, line: line)
        XCTAssertEqual(try model.game.encoded(), saved, file: file, line: line)
        assertConservation(model.game, file: file, line: line)
    }

    func testReleaseNoteAllowsClueHighlightAndPreservesTheOtherDuplicate() throws {
        var game = try fixture(.returnSlip, hand: [.one, .one, .two])
        let releasedID = game.puzzle!.handCards[0].id
        let otherID = game.puzzle!.handCards[1].id
        _ = try game.place(handIndex: 0, at: Square(1))
        var run = game.run
        let buff = OwnedBuff(defID: Buffs.releaseNote, pricePaid: 0)
        run.buffs = [buff]
        game = Game(run: run)
        _ = try game.beginBuff(id: buff.id)
        let choice = try XCTUnwrap(game.run.pendingItemDecisions.first)
        let option = try XCTUnwrap(choice.options.first { $0.cardID == releasedID })
        XCTAssertTrue(try game.resolveItemDecision(id: choice.id, selected: [option.id]))
        let model = GameModel(resuming: game, savesProgress: false)
        let beforeBoard = model.puzzle!.board.placed
        let beforeHand = model.handCards.map(\.id)
        let index = try XCTUnwrap(model.canonicalHandIndex(for: releasedID))
        model.chooseClue()
        model.tapHandCard(releasedID)
        let square = try XCTUnwrap(model.puzzle!.clueReveals.first)
        XCTAssertFalse(model.isBlocked(handIndex: index))
        XCTAssertTrue(model.canToss)
        XCTAssertTrue(model.isClueDestination(square))
        XCTAssertNotNil(model.clueHandInstruction)
        XCTAssertEqual(model.puzzle!.board.placed, beforeBoard)
        XCTAssertEqual(model.handCards.map(\.id), beforeHand)
        XCTAssertEqual(model.puzzle?.cluesRemaining, 7)
        XCTAssertEqual(model.puzzle?.buffState.releasedCard, releasedID, "Reading a clue does not consume the permitted play")
        model.tapSquare(square)
        XCTAssertFalse(model.handCards.contains { $0.id == releasedID })
        XCTAssertTrue(model.handCards.contains { $0.id == otherID })
        XCTAssertTrue(model.puzzle!.bossState.sealedIDs.isEmpty)
        XCTAssertNil(model.puzzle!.buffState.releasedCard)
        assertConservation(model.game)
    }

    func testLastTossPresentsActualAutomaticBankReceipt() throws {
        var game = try fixture(.collator, hand: [.one, .two])
        _ = try game.place(handIndex: 0, at: Square(0))
        let model = GameModel(resuming: game, savesProgress: false)
        let tossedID = model.handCards[0].id
        model.tapHandCard(tossedID)
        model.tossSelected()
        XCTAssertTrue(model.numberReturns.contains { $0.kind == .pool && $0.handCardIDs == [tossedID] })
        try assertBank(model, total: 10)
        let saved = try model.game.encoded()
        model.tossSelected()
        XCTAssertEqual(try model.game.encoded(), saved, "A second tap has no selected card and cannot bank again")
    }

    func testRebinderReturnFlightUsesTheExactOutgoingCardsAndNeverReplaysOnResume() throws {
        var game = try fixture(.rebinder, hand: [.nine, .one, .one, .two])
        _ = try game.place(handIndex: 0, at: Square(8))
        let model = GameModel(resuming: game, savesProgress: false)
        let outgoing = model.puzzle!.handCards
        model.endTurn()
        let flight = try XCTUnwrap(model.numberReturns.first { $0.kind == .redraw })
        XCTAssertEqual(flight.handCardIDs, outgoing.map(\.id))
        XCTAssertEqual(flight.digits, outgoing.map(\.digit))
        XCTAssertTrue(Set(outgoing.map(\.id)).isDisjoint(with: model.handCards.map(\.id)))
        XCTAssertEqual(model.handCards.count, 4)
        try assertBank(model, total: 90)
        let saved = try model.game.encoded()
        let resumed = GameModel(resuming: try Game(decoding: saved), savesProgress: false)
        XCTAssertTrue(resumed.numberReturns.isEmpty)
        XCTAssertNil(resumed.scorePerformance)
        XCTAssertEqual(resumed.handCards.map(\.id), model.handCards.map(\.id))
        XCTAssertEqual(try resumed.game.encoded(), saved)
        assertConservation(resumed.game)
    }

    func testWrongLastCardKeepsReturnFeedbackAndPresentsNetBank() throws {
        var game = try fixture(.bookends, hand: [.nine, .one])
        _ = try game.place(handIndex: 0, at: Square(8))
        let model = GameModel(resuming: game, savesProgress: false)
        let wrongID = model.handCards[0].id
        model.place(handIndex: 0, at: Square(1))
        XCTAssertEqual(model.lastOutcome?.penalty, 50)
        XCTAssertEqual(model.lastOutcome?.correct, false)
        XCTAssertTrue(model.numberReturns.contains { $0.kind == .pool && $0.handCardIDs == [wrongID] && $0.penalty == 50 })
        XCTAssertNil(model.puzzle?.board[Square(1)])
        try assertBank(model, total: 40)
    }

    func testPageCutterDirectCluePresentsTheEarnedBank() throws {
        let model = GameModel(resuming: try fixture(.pageCutter, hand: [.one, .two, .three, .four, .five, .six]), savesProgress: false)
        model.place(handIndex: 0, at: Square(0))
        for index in 1...3 { model.useClue(at: Square(index)) }
        XCTAssertEqual(model.puzzle?.bossState.correctFills, 0)
        XCTAssertEqual(model.puzzle?.board.filledBy[Square(3).index], .clue)
        try assertBank(model, total: 10)
    }

    func testPageCutterChoicePublishesOneBankAndStaleDecisionCannotReplayIt() throws {
        var game = try fixture(.pageCutter, hand: [.one, .two, .three, .four, .five, .six])
        var run = game.run
        run.markers = [OwnedMarker(defID: Markers.fork, boughtAtLevel: 9, pricePaid: 4, squares: [Square(3)])]
        MarkerRuntime.synchronizeOwnership(run: &run)
        game = Game(run: run)
        for index in 0..<3 { _ = try game.place(handIndex: 0, at: Square(index)) }
        let model = GameModel(resuming: game, savesProgress: false)
        model.place(handIndex: 0, at: Square(3))
        XCTAssertEqual(model.puzzle?.turnNumber, 1)
        XCTAssertTrue(model.puzzle?.bossState.pendingAutoEnd == true)
        let choice = try XCTUnwrap(model.run.pendingItemDecisions.first)
        let restored = GameModel(resuming: try Game(decoding: model.game.encoded()), savesProgress: false)
        XCTAssertTrue(restored.resolveItemDecision(id: choice.id, selected: [choice.options[0].id]))
        let performanceID = try XCTUnwrap(restored.scorePerformance?.id)
        try assertBank(restored, total: 100)
        let saved = try restored.game.encoded()
        XCTAssertFalse(restored.resolveItemDecision(id: choice.id, selected: [choice.options[0].id]))
        XCTAssertEqual(restored.scorePerformance?.id, performanceID)
        XCTAssertEqual(try restored.game.encoded(), saved)
        let resumed = GameModel(resuming: try Game(decoding: saved), savesProgress: false)
        XCTAssertNil(resumed.scorePerformance, "Loading the settled Turn never replays its bank")
    }
}
