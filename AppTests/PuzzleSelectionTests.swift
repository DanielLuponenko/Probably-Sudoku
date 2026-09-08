import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// In-memory fixtures exercise selection and the app's input boundary.
/// Frozen models never modify a player's saved Book.
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

    func testLateSquareTapAndDragAreNoOpsAfterPuzzleTerminalPhase() throws {
        for phase in [PuzzlePhase.won, .failed, .cashedOut] {
            let model = try terminalModel(phase: phase)
            let blank = try XCTUnwrap(model.puzzle?.board.blanks.first)
            let before = try model.game.encoded()
            let selectedHand = model.selectedHandIndex
            let selectedSquare = model.selectedSquare
            let message = model.message

            model.tapSquare(blank)
            model.place(handIndex: 0, at: blank)

            XCTAssertEqual(try model.game.encoded(), before, "phase=\(phase)")
            XCTAssertEqual(model.selectedHandIndex, selectedHand, "phase=\(phase)")
            XCTAssertEqual(model.selectedSquare, selectedSquare, "phase=\(phase)")
            XCTAssertEqual(model.message, message, "phase=\(phase)")
        }
    }

    func testPlayingAndKeepFillingStillAcceptDirectPlacement() throws {
        let playing = try model()
        let playingDigit = playing.hand[0]
        let playingSquare = try XCTUnwrap(playing.puzzle?.board.blanks.first {
            playing.puzzle?.board.correctDigit(at: $0) == playingDigit
        })
        playing.place(handIndex: 0, at: playingSquare)
        XCTAssertEqual(playing.puzzle?.board[playingSquare], playingDigit)
        XCTAssertEqual(playing.puzzle?.phase, .playing)
        XCTAssertNil(playing.message)

        var game = try game()
        game.qaMeetTarget()
        let keepFilling = GameModel(frozen: game, page: .results)
        keepFilling.keepFilling()
        let keepDigit = keepFilling.hand[0]
        let keepSquare = try XCTUnwrap(keepFilling.puzzle?.board.blanks.first {
            keepFilling.puzzle?.board.correctDigit(at: $0) == keepDigit
        })
        keepFilling.place(handIndex: 0, at: keepSquare)
        XCTAssertEqual(keepFilling.puzzle?.board[keepSquare], keepDigit)
        XCTAssertEqual(keepFilling.puzzle?.phase, .keepFilling)
        XCTAssertNil(keepFilling.message)
    }

    func testOutgoingHandTossAndEndTurnCannotChangeATerminalPuzzleOrShowAnError() throws {
        for phase in [PuzzlePhase.won, .failed, .cashedOut] {
            let model = try terminalModel(phase: phase)
            // Preserve a selection made before the final scoring beat.
            model.selectedHandIndex = 0
            let before = try model.game.encoded()
            let message = model.message

            XCTAssertFalse(model.acceptsPuzzleInput, "phase=\(phase)")
            XCTAssertFalse(model.canToss, "phase=\(phase)")
            model.tapHand(0)
            model.tossSelected()
            model.endTurn()

            XCTAssertEqual(try model.game.encoded(), before, "phase=\(phase)")
            XCTAssertEqual(model.selectedHandIndex, 0, "phase=\(phase)")
            XCTAssertEqual(model.message, message, "phase=\(phase)")
        }
    }

    func testLateClueActivationCannotChangeATerminalPuzzleOrShowAnError() throws {
        for phase in [PuzzlePhase.won, .failed, .cashedOut] {
            let model = try terminalModel(phase: phase)
            let blank = try XCTUnwrap(model.puzzle?.board.blanks.first)
            model.selectedHandIndex = 0
            model.selectedSquare = blank
            let message = model.message
            let before = try model.game.encoded()
            let clues = model.puzzle?.cluesRemaining

            model.chooseClue()

            XCTAssertEqual(try model.game.encoded(), before, "phase=\(phase)")
            XCTAssertEqual(model.selectedHandIndex, 0, "phase=\(phase)")
            XCTAssertEqual(model.selectedSquare, blank, "phase=\(phase)")
            XCTAssertFalse(model.isChoosingClue, "phase=\(phase)")
            XCTAssertEqual(model.message, message, "phase=\(phase)")
            XCTAssertEqual(model.puzzle?.cluesRemaining, clues, "phase=\(phase)")
        }
    }

    func testPlayingAndKeepFillingRetainNormalTurnAndTossControls() throws {
        var game = try game()
        for keepFilling in [false, true] {
            if keepFilling {
                game.qaMeetTarget()
                try game.keepFilling()
            }
            let model = GameModel(frozen: game, page: .puzzle)
            XCTAssertTrue(model.acceptsPuzzleInput)
            XCTAssertTrue(model.canToss)
            let tosses = try XCTUnwrap(model.puzzle?.tossesRemaining)
            model.tapHand(0)
            model.tossSelected()
            XCTAssertEqual(model.puzzle?.tossesRemaining, tosses - 1)
            let turn = try XCTUnwrap(model.puzzle?.turnNumber)
            model.endTurn()
            XCTAssertEqual(model.puzzle?.turnNumber, turn + 1)
            XCTAssertNil(model.message)
        }
    }

    func testAutomaticFinalCardPresentationUsesPostBankingScore() throws {
        var game = try game()
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
        run.puzzle = puzzle
        game = Game(run: run)

        let model = GameModel(resuming: game, savesProgress: false)
        let square = try XCTUnwrap(model.puzzle?.board.blanks.first {
            model.puzzle?.board.correctDigit(at: $0) == digit
        })
        let previousScore = model.score
        model.place(handIndex: 0, at: square)

        let performance = try XCTUnwrap(model.scorePerformance)
        XCTAssertGreaterThan(model.score, previousScore)
        XCTAssertEqual(performance.bankedFrom, previousScore)
        XCTAssertEqual(performance.finalScore, model.score,
                       "Automatic end-turn presentation must use the banked score.")
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

    private func terminalModel(phase: PuzzlePhase) throws -> GameModel {
        var game = try game()
        switch phase {
        case .won:
            game.qaMeetTarget()
        case .failed:
            game.failPuzzle()
        case .cashedOut:
            game.qaMeetTarget()
            _ = try game.cashOut()
        default:
            XCTFail("Fixture requested a non-terminal phase: \(phase)")
        }
        return GameModel(frozen: game, page: .results)
    }
}
