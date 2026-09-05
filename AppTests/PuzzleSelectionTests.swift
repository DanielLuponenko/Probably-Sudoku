import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// These taps only change presentation selection. The engine is prepared in
/// memory before constructing a frozen model; no test places, spends or saves.
@MainActor
final class PuzzleSelectionTests: XCTestCase {
    func testOccupiedBoardTapDropsHandAndHighlightsTheBoardDigit() throws {
        let model = try model()
        let board = try XCTUnwrap(model.puzzle?.board)
        let square = try XCTUnwrap(Square.all.first { board[$0] != nil && board[$0] != model.hand[0] })
        let before = try model.game.encoded()
        model.tapHand(0)

        model.tapSquare(square)

        XCTAssertNil(model.selectedHandIndex)
        XCTAssertNil(model.selectedDigit)
        XCTAssertEqual(model.selectedSquare, square)
        XCTAssertEqual(model.highlightedDigit, board[square])
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testHandTapClearsPreviouslyHighlightedBoardSquare() throws {
        let model = try model()
        let board = try XCTUnwrap(model.puzzle?.board)
        let square = try XCTUnwrap(Square.all.first { board[$0] != nil && board[$0] != model.hand[0] })
        let before = try model.game.encoded()
        model.tapSquare(square)

        model.tapHand(0)

        XCTAssertNil(model.selectedSquare)
        XCTAssertEqual(model.selectedHandIndex, 0)
        XCTAssertEqual(model.highlightedDigit, model.hand[0])
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testHandTapClearsASelectedBlankWithoutPlacingAnything() throws {
        let model = try model()
        let blank = try XCTUnwrap(model.puzzle?.board.blanks.first)
        let before = try model.game.encoded()
        model.tapSquare(blank)

        model.tapHand(0)

        XCTAssertNil(model.selectedSquare)
        XCTAssertEqual(model.selectedHandIndex, 0)
        XCTAssertEqual(model.highlightedDigit, model.hand[0])
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testRepeatedHandTapClearsEverySelectionAndDoesNotRestoreOldBoardHighlight() throws {
        let model = try model()
        let board = try XCTUnwrap(model.puzzle?.board)
        let occupied = try XCTUnwrap(Square.all.first { board[$0] != nil })
        let before = try model.game.encoded()
        model.tapSquare(occupied)
        model.tapHand(0)

        model.tapHand(0)

        XCTAssertNil(model.selectedHandIndex)
        XCTAssertNil(model.selectedSquare)
        XCTAssertNil(model.selectedDigit)
        XCTAssertNil(model.highlightedDigit)
        XCTAssertNil(model.highlightSource)
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testChangingHandCardsSelectsTheNewIndexInsteadOfTogglingItOff() throws {
        let model = try model()
        XCTAssertGreaterThan(model.hand.count, 1)
        let before = try model.game.encoded()
        model.tapHand(0)

        model.tapHand(1)

        XCTAssertEqual(model.selectedHandIndex, 1)
        XCTAssertNil(model.selectedSquare)
        XCTAssertEqual(model.highlightedDigit, model.hand[1])
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testBarredBlankDoesNotReplaceHandSelectionOrAttemptPlacement() throws {
        var game = try game()
        let blank = try XCTUnwrap(game.puzzle?.board.blanks.first)
        var run = game.run
        var bossTurn = BossTurnState()
        bossTurn.greyed = [blank]
        run.puzzle?.bossTurn = bossTurn
        game = Game(run: run)
        let model = GameModel(frozen: game, page: .puzzle)
        let before = try model.game.encoded()
        model.tapHand(0)

        model.tapSquare(blank)

        XCTAssertEqual(model.selectedHandIndex, 0)
        XCTAssertNil(model.selectedSquare)
        XCTAssertEqual(model.highlightedDigit, model.hand[0])
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testInvalidHandIndexDoesNotClearExistingBoardSelection() throws {
        let model = try model()
        let board = try XCTUnwrap(model.puzzle?.board)
        let occupied = try XCTUnwrap(Square.all.first { board[$0] != nil })
        let before = try model.game.encoded()
        model.tapSquare(occupied)

        for invalidIndex in [-1, model.hand.count, Int.max] {
            model.tapHand(invalidIndex)
            XCTAssertNil(model.selectedHandIndex)
            XCTAssertEqual(model.selectedSquare, occupied)
            XCTAssertEqual(model.highlightedDigit, board[occupied])
        }
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testBarredOccupiedSquareDoesNotDropTheCurrentHandSelection() throws {
        let game = try game()
        let board = try XCTUnwrap(game.puzzle?.board)
        let occupied = try XCTUnwrap(Square.all.first { board[$0] != nil })
        var run = game.run
        var bossTurn = BossTurnState()
        bossTurn.greyed = [occupied]
        run.puzzle?.bossTurn = bossTurn
        let model = GameModel(frozen: Game(run: run), page: .puzzle)
        let before = try model.game.encoded()
        model.tapHand(0)

        model.tapSquare(occupied)

        XCTAssertEqual(model.selectedHandIndex, 0)
        XCTAssertNil(model.selectedSquare)
        XCTAssertEqual(model.highlightedDigit, model.hand[0])
        XCTAssertEqual(try model.game.encoded(), before)
    }

    func testDismissSelectionClearsBothSourcesWithoutChangingThePuzzle() throws {
        let model = try model()
        let before = try model.game.encoded()
        model.tapHand(0)

        model.dismissSelection()

        XCTAssertNil(model.selectedHandIndex)
        XCTAssertNil(model.selectedSquare)
        XCTAssertNil(model.highlightedDigit)
        XCTAssertNil(model.highlightSource)
        XCTAssertEqual(try model.game.encoded(), before)
    }

    private func model() throws -> GameModel {
        GameModel(frozen: try game(), page: .puzzle)
    }

    private func game() throws -> Game {
        var game = Game(seed: "puzzle-selection-regression")
        try game.startPuzzle()
        return game
    }
}
