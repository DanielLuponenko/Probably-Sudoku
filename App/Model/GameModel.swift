import Foundation
import Observation
import NumberClubEngine

/// Which page of the book is showing. The active puzzle and the shop are
/// separate pages, and you only ever get between them by turning one.
enum BookPage: Equatable {
    case puzzle
    case shop
    case results
}

/// Everything the views need that is not part of the rules: what is selected,
/// which page is showing, and the last thing that happened so it can be
/// animated. The rules themselves stay in the engine.
@Observable
final class GameModel {

    private(set) var game: Game
    private(set) var page: BookPage = .puzzle

    /// Index into the Hand, not a digit — the Hand can hold duplicates.
    var selectedHandIndex: Int?
    var selectedSquare: Square?
    /// Hand indices staged for a Toss. Toss is a multi-select (§5.1).
    var tossSelection: Set<Int> = []
    var isTossing = false

    /// The most recent placement, for the score flourish and the ink animation.
    private(set) var lastOutcome: PlacementOutcome?
    private(set) var lastPlacedSquare: Square?
    private(set) var lastPayout: RunState.Payout?
    private(set) var message: String?

    init(seed: String = GameModel.randomSeed(), startingBoard: StartingBoard = .scholar) {
        game = Game(seed: seed, startingBoard: startingBoard)
        try? game.startPuzzle()
    }

    /// A read-only copy of the game as it was, for drawing the page that is
    /// leaving during a turn. Cheap: `Game` is a value type.
    init(frozen game: Game, page: BookPage) {
        self.game = game
        self.page = page
    }

    static func randomSeed() -> String {
        // The only place randomness is allowed in: choosing which Book to play.
        String(UInt32.random(in: 0..<0xFFFFFF), radix: 36, uppercase: true)
    }

    // MARK: - Derived state

    var puzzle: PuzzleState? { game.puzzle }
    var run: RunState { game.run }
    var shop: ShopState? { game.shop }

    var hand: [Digit] { puzzle?.hand ?? [] }
    var score: Int { puzzle?.score ?? 0 }
    var target: Int { puzzle?.target ?? 0 }
    var progress: Double {
        guard let puzzle, puzzle.target > 0 else { return 0 }
        return min(1, Double(puzzle.score) / Double(puzzle.target))
    }
    var coins: Int { run.coins }

    /// Squares carrying a Marker, unless The Fog is hiding them (§13).
    var visibleMarkers: [Square: OwnedMarker] {
        guard puzzle?.boss?.hidesMarkedSquares != true else { return [:] }
        return run.markedSquares
    }
    var markersAreHidden: Bool { puzzle?.boss?.hidesMarkedSquares == true }

    /// Squares that would light up as related to the selection, the way a
    /// paper solver's eye follows a row and column.
    var peerSquares: Set<Square> {
        guard let square = selectedSquare else { return [] }
        return Set(Geometry.rows[square.row] + Geometry.cols[square.col] + Geometry.boxes[square.box])
    }

    var selectedDigit: Digit? {
        guard let index = selectedHandIndex, hand.indices.contains(index) else { return nil }
        return hand[index]
    }

    /// The number the board should be highlighting: whichever you picked up
    /// from the Hand, or the one already sitting in the square you tapped.
    /// Scanning for every 7 is the core reading motion of a sudoku, so it is
    /// worth making free.
    var highlightedDigit: Digit? {
        if let selectedDigit { return selectedDigit }
        if let square = selectedSquare { return puzzle?.board[square] }
        return nil
    }

    /// Blanks the selected number could legally go in — every empty square, but
    /// the ones that already hold that number elsewhere in the unit are worth
    /// warning about.
    func wouldConflict(_ square: Square, with digit: Digit) -> Bool {
        guard let board = puzzle?.board else { return false }
        return Geometry.peers[square.index].contains { board.placed[$0] == digit }
    }

    // MARK: - Actions

    func tapHand(_ index: Int) {
        if isTossing {
            if tossSelection.contains(index) { tossSelection.remove(index) }
            else if tossSelection.count < (puzzle?.tossesRemaining ?? 0) { tossSelection.insert(index) }
            return
        }
        selectedHandIndex = selectedHandIndex == index ? nil : index
    }

    func tapSquare(_ square: Square) {
        guard let puzzle else { return }
        guard puzzle.board.isBlank(square) else {
            selectedSquare = square
            return
        }
        selectedSquare = square
        guard let index = selectedHandIndex else { return }
        place(handIndex: index, at: square)
    }

    func place(handIndex: Int, at square: Square) {
        do {
            let outcome = try game.place(handIndex: handIndex, at: square)
            lastOutcome = outcome
            lastPlacedSquare = square
            selectedHandIndex = nil
            message = outcome.correct ? nil : "Wrong number — \(outcome.penalty) points"
        } catch {
            message = describe(error)
        }
    }

    func beginToss() {
        isTossing = true
        tossSelection = []
        selectedHandIndex = nil
    }

    func cancelToss() {
        isTossing = false
        tossSelection = []
    }

    func confirmToss() {
        guard !tossSelection.isEmpty else { cancelToss(); return }
        do {
            _ = try game.toss(Array(tossSelection))
            message = nil
        } catch {
            message = describe(error)
        }
        cancelToss()
    }

    func useClue(at square: Square) {
        do {
            _ = try game.useClue(at: square)
            lastPlacedSquare = square
        } catch {
            message = describe(error)
        }
    }

    func useBuff(at index: Int, digit: Digit? = nil) {
        do { _ = try game.useBuff(at: index, digit: digit) }
        catch { message = describe(error) }
    }

    func endTurn() {
        do {
            let result = try game.endTurn()
            selectedHandIndex = nil
            if result.puzzleFailed { page = .results }
        } catch {
            message = describe(error)
        }
    }

    // MARK: - Page turns

    func cashOut() {
        do {
            lastPayout = try game.cashOut()
            page = .results
        } catch {
            message = describe(error)
        }
    }

    func keepFilling() {
        try? game.keepFilling()
    }

    /// Results → shop, the first of the two page turns between Puzzles.
    func openShop() {
        game.openShop()
        page = .shop
    }

    /// Shop → the next puzzle, the second page turn.
    func continueToNextPuzzle() {
        guard game.advance() else {
            page = .results
            return
        }
        do {
            try game.startPuzzle()
            selectedHandIndex = nil
            selectedSquare = nil
            lastOutcome = nil
            page = .puzzle
        } catch {
            message = describe(error)
        }
    }

    func buy(slot: Int) {
        do { try game.buy(slot: slot) }
        catch { message = describe(error) }
    }

    func reroll() {
        do { try game.reroll() }
        catch { message = describe(error) }
    }

    func claimSquare(markerIndex: Int, square: Square) {
        do { try game.claimSquare(markerIndex: markerIndex, square: square) }
        catch { message = describe(error) }
    }

    /// Finishing or failing a Book starts a fresh one. Nothing carries over
    /// except the Book difficulty you have unlocked (§2).
    func startNewBook(startingBoard: StartingBoard? = nil) {
        game = Game(seed: Self.randomSeed(),
                    startingBoard: startingBoard ?? game.run.startingBoard)
        selectedHandIndex = nil
        selectedSquare = nil
        tossSelection = []
        isTossing = false
        lastOutcome = nil
        lastPayout = nil
        message = nil
        page = .puzzle
        try? game.startPuzzle()
    }

    func clearMessage() { message = nil }

    #if DEBUG
    // QA shortcuts. Compiled out of release builds, as are the engine calls.
    func qaAward(points: Int) { game.qaAward(points: points) }
    func qaAward(coins: Int) { game.qaAward(coins: coins) }
    func qaMeetTarget() { game.qaMeetTarget() }
    func qaFailPuzzle() { game.qaFailPuzzle(); page = .results }
    func qaFillBoard() { game.qaFillBoard() }
    #endif

    private func describe(_ error: Error) -> String {
        switch error {
        case PlacementError.noCluesLeft: return "No Clues left"
        case PlacementError.cluesDisabled: return "The Paywall has disabled Clues"
        case PlacementError.tossAllowanceSpent: return "No Tosses left this Turn"
        case PlacementError.squareNotBlank: return "That square is already filled"
        case Shop.ShopError.notEnoughCoins: return "Not enough coins"
        case Shop.ShopError.slotsFull: return "No free slot"
        case Shop.MarkerError.squareTaken: return "Another Marker owns that square"
        default: return "\(error)"
        }
    }
}
