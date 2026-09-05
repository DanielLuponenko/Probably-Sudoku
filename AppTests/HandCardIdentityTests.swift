import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class HandCardIdentityTests: XCTestCase {
    func testCorrectPlacementRemovesTheSelectedDuplicateNotTheLaterCopy() throws {
        let model = try makeModel()
        let before = model.handCards.map(\.id)
        let digit = model.hand[0]
        model.place(handIndex: 0, at: try blank(in: model, matching: digit))
        XCTAssertEqual(model.handCards.map(\.id), Array(before.dropFirst()))
        XCTAssertFalse(model.handCards.contains { $0.id == before[0] })
        assertPresentationMatchesHand(model)
    }

    func testTossRemovesTheSelectedDuplicateNotTheLaterCopy() throws {
        let model = try makeModel()
        let before = model.handCards.map(\.id)
        model.tapHand(0)
        model.tossSelected()
        XCTAssertEqual(model.handCards.map(\.id), Array(before.dropFirst()))
        assertPresentationMatchesHand(model)
    }

    func testWrongPlacementReturningToPoolRemovesTheExactCard() throws {
        let model = try makeModel()
        let before = model.handCards.map(\.id)
        model.place(handIndex: 0, at: try blank(in: model, differentFrom: model.hand[0]))
        XCTAssertEqual(model.lastOutcome?.correct, false)
        XCTAssertEqual(model.lastOutcome?.returnedToHand, false)
        XCTAssertEqual(model.handCards.map(\.id), Array(before.dropFirst()))
        assertPresentationMatchesHand(model)
    }

    func testJadeReturnsTheSameCardAtTheEndWithoutStealingAnotherIdentity() throws {
        let model = try makeModel()
        let square = try blank(in: model, differentFrom: model.hand[0])
        var game = model.game
        game.qaSetMarker(Markers.jade, at: square)
        let marked = GameModel(resuming: game, savesProgress: false)
        let before = marked.handCards.map(\.id)
        marked.place(handIndex: 0, at: square)
        XCTAssertEqual(marked.lastOutcome?.returnedToHand, true)
        XCTAssertEqual(marked.handCards.map(\.id), Array(before.dropFirst()) + [before[0]])
        assertPresentationMatchesHand(marked)
    }

    func testFinalCardAutoRefillGivesSameDigitANewIdentity() throws {
        var game = try fixture()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        let digit = try XCTUnwrap(Digit.all.first { puzzle.pool[$0] >= 3 })
        for square in puzzle.board.blanks where puzzle.board.correctDigit(at: square) != digit {
            let value = puzzle.board.correctDigit(at: square)
            XCTAssertTrue(puzzle.pool.take(value))
            puzzle.board.fill(square, with: value, by: .player)
        }
        XCTAssertTrue(puzzle.pool.take(digit))
        puzzle.hand = [digit]
        puzzle.target = 100_000
        run.puzzle = puzzle
        game = Game(run: run)
        let model = GameModel(resuming: game, savesProgress: false)
        let spentID = try XCTUnwrap(model.handCards.first?.id)
        let turn = try XCTUnwrap(model.puzzle?.turnNumber)
        model.place(handIndex: 0, at: try blank(in: model, matching: digit))
        XCTAssertEqual(model.puzzle?.turnNumber, turn + 1)
        XCTAssertFalse(model.hand.isEmpty)
        XCTAssertTrue(model.hand.allSatisfy { $0 == digit })
        XCTAssertFalse(model.handCards.contains { $0.id == spentID })
        assertPresentationMatchesHand(model)
    }

    func testMarkerDrawAppendsNewIdentityAfterTheCorrectSurvivors() throws {
        let model = try makeModel()
        let square = try blank(in: model, matching: model.hand[0])
        var game = model.game
        game.qaSetMarker("mk_sapphire", at: square)
        let marked = GameModel(resuming: game, savesProgress: false)
        let before = marked.handCards.map(\.id)
        marked.place(handIndex: 0, at: square)
        XCTAssertEqual(marked.lastOutcome?.numbersDrawn, 1)
        XCTAssertEqual(Array(marked.handCards.map(\.id).prefix(3)), Array(before.dropFirst()))
        XCTAssertFalse(before.contains(try XCTUnwrap(marked.handCards.last?.id)))
        assertPresentationMatchesHand(marked)
    }

    func testExplicitEndTurnPreservesAllCarriedCardIDs() throws {
        let model = try makeModel()
        let before = model.handCards.map(\.id)
        model.endTurn()
        XCTAssertEqual(Array(model.handCards.map(\.id).prefix(before.count)), before)
        XCTAssertTrue(model.handCards.dropFirst(before.count).allSatisfy { !before.contains($0.id) })
        assertPresentationMatchesHand(model)
    }

    func testLuckyDipAppendsCardsWithoutRearrangingHeldDuplicates() throws {
        let model = try makeModel()
        model.qaSetBuff("bf_lucky_dip")
        let before = model.handCards.map(\.id)
        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertEqual(Array(model.handCards.map(\.id).prefix(before.count)), before)
        XCTAssertEqual(model.handCards.count, before.count + 2)
        XCTAssertTrue(model.handCards.dropFirst(before.count).allSatisfy { !before.contains($0.id) })
        assertPresentationMatchesHand(model)
    }

    func testFullRedrawStillReplacesEveryIdentity() throws {
        let model = try makeModel()
        model.qaSetBuff(Buffs.redraw)
        let before = Set(model.handCards.map(\.id))
        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertTrue(before.isDisjoint(with: model.handCards.map(\.id)))
        assertPresentationMatchesHand(model)
    }

    func testLegacyClueRemovesFirstMatchingCardOnlyWhenPoolHasNone() throws {
        let source = try fixture()
        var run = source.run
        var puzzle = try XCTUnwrap(run.puzzle)
        let digit = puzzle.hand[0]
        while puzzle.pool.take(digit) { puzzle.hand.append(digit) }
        puzzle.cluesRemaining = 1
        run.puzzle = puzzle
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        let before = model.handCards.map(\.id)
        let square = try blank(in: model, matching: digit)
        XCTAssertEqual(model.puzzle?.poolCount(of: digit), 0)
        XCTAssertNil(model.puzzle?.board[square])
        model.useClue(at: square)
        XCTAssertNil(model.message)
        XCTAssertEqual(model.puzzle?.cluesRemaining, 0)
        XCTAssertEqual(model.puzzle?.board[square], digit)
        XCTAssertEqual(model.puzzle?.board.filledBy[square.index], .clue)
        XCTAssertEqual(model.handCards.map(\.id), Array(before.dropFirst()))
        assertPresentationMatchesHand(model)
    }

    func testLegacyClueFromPoolLeavesAllHeldIdentitiesAlone() throws {
        var run = try fixture().run
        run.puzzle?.cluesRemaining = 1
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        let before = model.handCards.map(\.id)
        let digit = try XCTUnwrap(Digit.all.first { (model.puzzle?.poolCount(of: $0) ?? 0) > 0 })
        let poolCount = try XCTUnwrap(model.puzzle?.poolCount(of: digit))
        let square = try blank(in: model, matching: digit)
        XCTAssertGreaterThan(poolCount, 0)
        XCTAssertNil(model.puzzle?.board[square])
        model.useClue(at: square)
        XCTAssertNil(model.message)
        XCTAssertEqual(model.puzzle?.cluesRemaining, 0)
        XCTAssertEqual(model.puzzle?.board[square], digit)
        XCTAssertEqual(model.puzzle?.board.filledBy[square.index], .clue)
        XCTAssertEqual(model.puzzle?.poolCount(of: digit), poolCount - 1)
        XCTAssertEqual(model.handCards.map(\.id), before)
        assertPresentationMatchesHand(model)
    }

    func testRejectedPlacementAndTossDoNotChangeAnyIdentity() throws {
        var run = try fixture().run
        let allowance = try XCTUnwrap(run.puzzle?.tossAllowance)
        run.puzzle?.tossedThisPuzzle = allowance
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        let before = model.handCards.map(\.id)
        let given = try XCTUnwrap(Square.all.first { model.puzzle?.board[$0] != nil })
        model.place(handIndex: 0, at: given)
        XCTAssertEqual(model.handCards.map(\.id), before)
        model.tapHand(0)
        model.tossSelected()
        XCTAssertEqual(model.handCards.map(\.id), before)
        assertPresentationMatchesHand(model)
    }

    private func makeModel() throws -> GameModel {
        GameModel(resuming: try fixture(), savesProgress: false)
    }

    /// A, B, C, D are four different cards; A and C print the same digit.
    /// Rebuilding the Hand through the Pool preserves all engine invariants.
    private func fixture() throws -> Game {
        var game = Game(seed: "hand-card-identity")
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        let duplicate = try XCTUnwrap(Digit.all.first { puzzle.pool[$0] >= 2 })
        let others = Digit.all.filter { $0 != duplicate && puzzle.pool[$0] > 0 }
        XCTAssertGreaterThanOrEqual(others.count, 2)
        for digit in [duplicate, others[0], duplicate, others[1]] {
            XCTAssertTrue(puzzle.pool.take(digit))
            puzzle.hand.append(digit)
        }
        run.puzzle = puzzle
        return Game(run: run)
    }

    private func blank(in model: GameModel, matching digit: Digit) throws -> Square {
        try XCTUnwrap(model.puzzle?.board.blanks.first { model.puzzle?.board.correctDigit(at: $0) == digit })
    }

    private func blank(in model: GameModel, differentFrom digit: Digit) throws -> Square {
        try XCTUnwrap(model.puzzle?.board.blanks.first { model.puzzle?.board.correctDigit(at: $0) != digit })
    }

    private func assertPresentationMatchesHand(_ model: GameModel,
                                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(model.handCards.map(\.digit), model.hand, file: file, line: line)
        XCTAssertEqual(Set(model.handCards.map(\.id)).count, model.handCards.count, file: file, line: line)
    }
}
