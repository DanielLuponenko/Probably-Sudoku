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

    /// A presentation identity for a Hand card. A digit is not an identity:
    /// duplicates are valid, and a carried card must not re-enter merely
    /// because another card with the same digit was spent.
    struct HandCard: Identifiable {
        let id: UUID
        let digit: Digit
        /// Staggers only cards introduced by the current Hand reconciliation.
        let arrivalOrder: Int
    }

    private(set) var game: Game {
        didSet { persist() }
    }
    private(set) var handCards: [HandCard] = []
    /// A frozen model is the page already lifting away, not a fresh deal.
    private(set) var animatesHandArrival = true
    private(set) var page: BookPage = .puzzle

    /// Which of the two selections the board should be highlighting. Both a
    /// Hand tile and a square can be selected at once, so without this the
    /// older of the two wins and the highlight looks stuck on the number you
    /// picked first.
    enum Highlight { case hand, square }
    private(set) var highlightSource: Highlight?

    /// Index into the Hand, not a digit — the Hand can hold duplicates.
    var selectedHandIndex: Int? {
        didSet { if selectedHandIndex != nil { highlightSource = .hand } }
    }
    var selectedSquare: Square?

    /// A row, column or box that has just been completed, held long enough to
    /// be marked on the board and then dropped.
    struct Cleared: Equatable, Identifiable {
        let unit: NumberClubEngine.Unit
        let square: Square
        /// A single placement can complete all three unit types. The unit must
        /// be part of the identity or SwiftUI coalesces those overlays into one
        /// view and only one clear is visible.
        let ticket: Int

        var id: String { "\(ticket)-\(unit.rawValue)" }
    }
    private(set) var cleared: [Cleared] = []
    private var clearTicket = 0

    /// The most recent placement, for the score flourish and the ink animation.
    private(set) var lastOutcome: PlacementOutcome?
    private(set) var lastPlacedSquare: Square?
    private(set) var lastPayout: RunState.Payout?
    private(set) var message: String?

    init(seed: String = GameModel.randomSeed(),
         startingBoard: StartingBoard = .scholar,
         obstacle: Obstacle = .none) {
        game = Game(seed: seed, startingBoard: startingBoard, obstacle: obstacle)
        try? game.startPuzzle()
        refreshHandCards(replacing: true)
        startClock()
    }

    /// A read-only copy of the game as it was, for drawing the page that is
    /// leaving during a turn. Cheap: `Game` is a value type.
    init(frozen game: Game, page: BookPage) {
        self.game = game
        self.page = page
        self.animatesHandArrival = false
        refreshHandCards(replacing: true)
    }

    /// Resumes a Book that was put down.
    init(resuming game: Game) {
        self.game = game
        refreshHandCards(replacing: true)
        startClock()
    }

    private func persist() {
        if game.run.outcome == .bookCompleted { RunStore.recordBookCompleted() }
        RunStore.save(game)
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

    /// Reuses the identity of cards that remain in the Hand and gives each
    /// newly dealt card an identity of its own. A full Redraw intentionally
    /// opts out: every replacement card should arrive as new.
    private func refreshHandCards(replacing: Bool = false) {
        let updatedHand = hand
        guard !replacing else {
            handCards = updatedHand.enumerated().map {
                HandCard(id: UUID(), digit: $0.element, arrivalOrder: $0.offset)
            }
            return
        }

        var remainingCards = handCards
        var nextArrivalOrder = 0
        handCards = updatedHand.map { digit in
            if let index = remainingCards.firstIndex(where: { $0.digit == digit }) {
                return remainingCards.remove(at: index)
            }
            defer { nextArrivalOrder += 1 }
            return HandCard(id: UUID(), digit: digit, arrivalOrder: nextArrivalOrder)
        }
    }

    /// Tik Tak's clock is presentation state, not an engine timer: a Book
    /// must not lose while its app is in the background. Expiry still uses the
    /// engine's production failure path.
    private(set) var secondsLeft: Double?

    func startClock() { secondsLeft = puzzle?.boss?.secondsAllowed }
    func stopClock() { secondsLeft = nil }

    /// Called by the puzzle page once a second only while Tik Tak is active.
    func tickClock(by seconds: Double) {
        guard var remaining = secondsLeft, puzzle?.phase == .playing else { return }
        remaining -= seconds
        if remaining <= 0 {
            secondsLeft = 0
            message = "Out of time"
            game.failPuzzle()
            page = .results
        } else {
            secondsLeft = remaining
        }
    }

    /// Which Book this is, and therefore what it says in the margins.
    var edition: BookEdition { BookEdition.edition(forBookTier: 1) }

    /// The line written in the margin this Turn, if the Book has anything to
    /// say. Derived from the seed, so a Book always says the same things in the
    /// same places.
    var marginNote: MarginNote? {
        guard let puzzle, puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            return nil
        }
        return MarginNote.roll(seed: run.seed,
                               level: puzzle.level,
                               slot: puzzle.slot.rawValue,
                               turn: puzzle.turnNumber,
                               from: edition)
    }

    /// Squares carrying a Marker, unless The Fog is hiding them (§13).
    var visibleMarkers: [Square: OwnedMarker] {
        guard puzzle?.boss?.hidesMarkedSquares != true else { return [:] }
        return run.markedSquares
    }
    var markersAreHidden: Bool { puzzle?.boss?.hidesMarkedSquares == true }
    var sleepingBookmark: Int? { puzzle?.disabledBookmark }
    func isBarred(_ square: Square) -> Bool { puzzle?.isBarred(square) ?? false }

    var selectedDigit: Digit? {
        guard let index = selectedHandIndex, hand.indices.contains(index) else { return nil }
        return hand[index]
    }

    /// The number the board should be highlighting. Scanning for every 7 is the
    /// core reading motion of a sudoku, so it is worth making free — but only
    /// one number at a time, and it is always the one you touched last.
    var highlightedDigit: Digit? {
        switch highlightSource {
        case .hand:
            return selectedDigit ?? squareDigit
        case .square:
            return squareDigit ?? selectedDigit
        case nil:
            return nil
        }
    }

    private var squareDigit: Digit? {
        guard let square = selectedSquare else { return nil }
        return puzzle?.board[square]
    }

    /// Hand indices go stale the moment the Hand changes — after a placement,
    /// a Toss, a Buff or a refill — and a stale index quietly points at a
    /// different number rather than at nothing.
    private func dropHandSelection() {
        selectedHandIndex = nil
        if highlightSource == .hand {
            highlightSource = selectedSquare == nil ? nil : .square
        }
    }

    /// A Toss or Turn transition makes both selections stale. Keeping either
    /// one tells the board to highlight state that cannot be acted on anymore.
    private func clearSelection() {
        selectedHandIndex = nil
        selectedSquare = nil
        highlightSource = nil
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
        guard hand.indices.contains(index) else { return }
        if isBlocked(hand[index]) {
            message = "\(hand[index].rawValue) is blocked this Turn"
            return
        }
        selectedHandIndex = selectedHandIndex == index ? nil : index
    }

    /// Obstacle III bars one number a Turn. It stays in the Hand — it can be
    /// seen and Tossed — but it cannot go on the board.
    func isBlocked(_ digit: Digit) -> Bool {
        puzzle?.isBlocked(digit) ?? false
    }

    func tapSquare(_ square: Square) {
        guard let puzzle else { return }
        guard !puzzle.isBarred(square) else {
            message = "That square is barred this Turn"
            return
        }
        selectedSquare = square
        highlightSource = .square

        guard puzzle.board.isBlank(square), let index = selectedHandIndex else { return }
        place(handIndex: index, at: square)
    }

    func place(handIndex: Int, at square: Square) {
        do {
            let outcome = try game.place(handIndex: handIndex, at: square)
            refreshHandCards()
            lastOutcome = outcome
            lastPlacedSquare = square
            markCleared(outcome, at: square)
            // A placement consumes the card and changes the square, so neither
            // side of the former selection still describes an available action.
            clearSelection()
            message = outcome.correct ? nil : "Wrong number — \(outcome.penalty) points"
        } catch {
            message = describe(error)
        }
    }

    /// Shows each completed unit briefly. Cleared once, on a ticket, so a
    /// second clear arriving mid-flash cannot cancel the first one's fade.
    private func markCleared(_ outcome: PlacementOutcome, at square: Square) {
        guard !outcome.lineClears.isEmpty || outcome.fullClear else { return }
        clearTicket += 1
        let ticket = clearTicket
        cleared = outcome.lineClears.map { Cleared(unit: $0, square: square, ticket: ticket) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            if clearTicket == ticket { cleared = [] }
        }
    }

    /// §5.1, revised — one number at a time, out of a budget for the whole
    /// Puzzle. The number you have picked up is the one thrown back, so there
    /// is no separate staging mode to be in.
    func tossSelected() {
        guard let index = selectedHandIndex else { return }
        do {
            _ = try game.toss(handIndex: index)
            refreshHandCards()
            message = nil
        } catch {
            message = describe(error)
        }
        clearSelection()
    }

    var canToss: Bool {
        selectedHandIndex != nil && (puzzle?.tossesRemaining ?? 0) > 0
    }

    /// Tossing is the one thing a blocked number can still be used for, so it
    /// has its own path in from the Hand.
    func tossBlocked(at index: Int) {
        do {
            _ = try game.toss(handIndex: index)
            refreshHandCards()
            message = nil
        } catch {
            message = describe(error)
        }
        clearSelection()
    }

    func useClue(at square: Square) {
        do {
            let outcome = try game.useClue(at: square)
            refreshHandCards()
            lastPlacedSquare = square
            markCleared(outcome, at: square)
        } catch {
            message = describe(error)
        }
    }

    func useBuff(at index: Int, digit: Digit? = nil) {
        do {
            let redrawsHand = game.run.buffs.indices.contains(index)
                && game.run.buffs[index].defID == Buffs.redraw
            _ = try game.useBuff(at: index, digit: digit)
            refreshHandCards(replacing: redrawsHand)
            // Redraw and Lucky Dip both reshape the Hand under the selection.
            dropHandSelection()
        } catch {
            message = describe(error)
        }
    }

    func endTurn() {
        do {
            let result = try game.endTurn()
            refreshHandCards()
            clearSelection()
            if result.puzzleFailed { page = .results }
        } catch {
            message = describe(error)
        }
    }

    // MARK: - Page turns

    /// What cashing out would pay, worked out before you commit to it. Pure, so
    /// showing it costs nothing and the decision is an informed one.
    var payoutPreview: RunState.Payout? {
        guard let puzzle else { return nil }
        return run.payout(for: puzzle)
    }

    /// Finishing a Puzzle turns the page rather than throwing up a panel.
    func showResults() {
        page = .results
    }

    func cashOut() {
        do { lastPayout = try game.cashOut() }
        catch { message = describe(error) }
    }

    /// §7 — play on with the Turns you have left, back on the Puzzle page.
    func keepFilling() {
        try? game.keepFilling()
        page = .puzzle
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
            refreshHandCards(replacing: true)
            startClock()
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

    /// §10 — sell a Bookmark or Buff for its deterministic partial refund.
    func sell(kind: ItemKind, index: Int) {
        do {
            let coins = try game.sell(kind: kind, index: index)
            message = "Sold for \(coins) \(coins == 1 ? "coin" : "coins")"
            dropHandSelection()
        } catch {
            message = describe(error)
        }
    }

    func sellPrice(_ pricePaid: Int) -> Int { Shop.sellPrice(pricePaid) }

    func claimSquare(markerIndex: Int, square: Square) {
        do { try game.claimSquare(markerIndex: markerIndex, square: square) }
        catch { message = describe(error) }
    }

    /// Leaving a run returns to the cover, because §3 makes the Starting Board
    /// a choice you make when you open a Book — so a new Book has to be opened,
    /// not silently dealt.
    var wantsMenu = false

    /// Give the run up. This has to actually destroy the save — leaving it on
    /// disk means the shelf offers to continue a Book the player was told they
    /// had abandoned. Putting a Book down needs no button: closing the app
    /// keeps it, and the shelf offers to continue.
    func abandonRun() {
        RunStore.clearRun()
        wantsMenu = true
    }

    /// Restarts in place, without going back to the cover. Used by QA only.
    func startNewBook(startingBoard: StartingBoard? = nil) {
        game = Game(seed: Self.randomSeed(),
                    startingBoard: startingBoard ?? game.run.startingBoard,
                    obstacle: game.run.obstacle)
        selectedHandIndex = nil
        selectedSquare = nil
        lastOutcome = nil
        lastPayout = nil
        message = nil
        page = .puzzle
        try? game.startPuzzle()
        refreshHandCards(replacing: true)
        startClock()
    }

    func clearMessage() { message = nil }

    #if DEBUG
    // QA shortcuts. Compiled out of release builds, as are the engine calls.
    func qaAward(points: Int) { game.qaAward(points: points) }
    func qaAward(coins: Int) { game.qaAward(coins: coins) }
    func qaMeetTarget() { game.qaMeetTarget() }
    func qaFailPuzzle() { game.qaFailPuzzle(); page = .results }
    func qaFillBoard() {
        game.qaFillBoard()
        refreshHandCards()
    }
    func qaGrantBuff(_ defID: String) { game.qaGrantBuff(defID) }
    func qaSetBookmark(_ defID: String) {
        game.qaSetBookmark(defID)
        refreshHandCards()
    }
    func qaSetMarker(_ defID: String) {
        guard let square = puzzle?.board.blanks.first else { return }
        game.qaSetMarker(defID, at: square)
    }
    func qaSetBuff(_ defID: String) { game.qaSetBuff(defID) }
    func qaSetBoss(_ boss: BossModifier) {
        game.qaSetBoss(boss)
        refreshHandCards()
        startClock()
    }

    /// Fills the bookmarks, so the row can be looked at populated.
    func qaFillLoadout() {
        for ad in Catalog.items(of: .bookmark).prefix(3) { game.qaGrantAd(ad.id) }
        game.qaGrantBuff(Buffs.peek)
        game.qaGrantBuff(Buffs.freshInk)
    }

    /// Fills the emptiest row but for one square, then plays that square, so
    /// the completed-unit mark can be looked at.
    func qaCompleteARow() {
        guard let puzzle = game.puzzle else { return }
        let row = (0..<9).max {
            Geometry.rows[$0].filter(puzzle.board.isBlank).count
                < Geometry.rows[$1].filter(puzzle.board.isBlank).count
        }!
        let blanks = Geometry.rows[row].filter { game.puzzle!.board.isBlank($0) }
        guard let last = blanks.last else { return }
        for square in blanks.dropLast() {
            let digit = game.puzzle!.board.correctDigit(at: square)
            guard game.qaPlace(digit: digit, at: square) else { return }
        }
        let digit = game.puzzle!.board.correctDigit(at: last)
        guard let index = stageDigitInHand(digit) else { return }
        place(handIndex: index, at: last)
    }

    /// Puts a specific number into the Hand, taken from the Pool so the
    /// conservation rule still holds.
    private func stageDigitInHand(_ digit: Digit) -> Int? {
        guard var puzzle = game.puzzle else { return nil }
        if let existing = puzzle.hand.firstIndex(of: digit) { return existing }
        guard game.qaTakeFromPool(digit) else { return nil }
        puzzle = game.puzzle!
        return puzzle.hand.firstIndex(of: digit)
    }
    #endif

    private func describe(_ error: Error) -> String {
        switch error {
        case PlacementError.noCluesLeft: return "No Clues left"
        case PlacementError.cluesDisabled: return "The Paywall has disabled Clues"
        case PlacementError.tossAllowanceSpent: return "No Tosses left this Puzzle"
        case PlacementError.numberBlocked: return "That number is blocked this Turn"
        case PlacementError.squareBarred: return "That square is barred this Turn"
        case PlacementError.buffsDisabled: return "This Boss has disabled Buffs"
        case PlacementError.squareNotBlank: return "That square is already filled"
        case Shop.ShopError.notEnoughCoins: return "Not enough coins"
        case Shop.ShopError.slotsFull: return "No free slot"
        case Shop.MarkerError.squareTaken: return "Another Marker owns that square"
        default: return "\(error)"
        }
    }
}
