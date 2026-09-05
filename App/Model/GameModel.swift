import Foundation
import Observation
import ProbablySudokuEngine

/// Which page of the book is showing. The active puzzle and the shop are
/// separate pages, and you only ever get between them by turning one.
enum BookPage: Equatable {
    case briefing
    case puzzle
    case shop
    case results
    case achievements
}

/// Everything the views need that is not part of the rules: what is selected,
/// which page is showing, and the last thing that happened so it can be
/// animated. The rules themselves stay in the engine.
@MainActor
@Observable
final class GameModel {

    /// A value snapshot held across the book-closing animation. The run is
    /// deliberately discarded when the shelf returns, so the congratulations
    /// page cannot depend on a live, resumable game.
    struct BookCompletionSummary {
        let edition: BookEdition
        let levelsCleared: Int
        let bossesBeaten: Int
        let bestPuzzleScore: Int
        let loadout: [String]
        let nextBook: BookEdition?
    }

    /// A presentation identity for a Hand card. A digit is not an identity:
    /// duplicates are valid, and a carried card must not re-enter merely
    /// because another card with the same digit was spent.
    struct HandCard: Identifiable {
        let id: UUID
        let digit: Digit
        /// Staggers only cards introduced by the current Hand reconciliation.
        let arrivalOrder: Int
    }

    /// A short-lived, presentation-only explanation of why a number just
    /// moved. Rules report their outcome through `PlacementOutcome`; this
    /// queue turns that fact into motion without making the engine know about
    /// SwiftUI, frames, or accessibility settings.
    struct NumberReturn: Identifiable, Equatable {
        enum Kind: Equatable {
            case pool
            case hand
            case redraw
            case barred
            case fouled
        }

        let id = UUID()
        let kind: Kind
        let digits: [Digit]
        let square: Square?
        let fouledSquares: [Square]
        let penalty: Int?
    }

    /// A short presentation receipt for rule effects that fired from a played
    /// square. Rule ownership stays in the engine; this only makes the engine
    /// result legible at the moment it matters.
    struct EffectActivation: Identifiable {
        let id = UUID()
        let markerSquare: Square?
        let markerText: String?
        let bookmarkIDs: Set<String>
    }

    private(set) var numberReturns: [NumberReturn] = []
    private(set) var effectActivation: EffectActivation?

    private struct BossFeedbackSnapshot {
        let blocked: Set<Digit>
        let fouled: Set<Square>

        init(_ puzzle: PuzzleState?) {
            blocked = puzzle?.blockedDigits ?? []
            fouled = puzzle.map { $0.bossTurn.map { Set($0.fouled.keys) } ?? [] } ?? []
        }
    }

    private(set) var game: Game {
        willSet {
            #if DEBUG && targetEnvironment(simulator)
            recordQAUndoSnapshot()
            #endif
        }
        didSet { persist() }
    }
    private(set) var handCards: [HandCard] = []
    /// A frozen model is the page already lifting away, not a fresh deal.
    private(set) var animatesHandArrival = true
    private(set) var page: BookPage = .briefing
    /// A terminal Book outcome can cause more than one presentation update.
    /// Record permanent consequences once, at the model boundary.
    private var didRecordTerminalOutcome = false
    private var rewardedRescue = RewardedRescueSession()
    /// Captured before the profile is updated. The profile records that the
    /// lesson started, while this model keeps its six lines visible for the
    /// current first Puzzle.
    private var isTeachingFirstRun = false
    /// These facts belong to one dealt Puzzle. A resumed run lacks the earlier
    /// action history, so it deliberately cannot mint a flawless/no-clue award
    /// from an incomplete snapshot.
    private var isTrackingAchievementPuzzle = false
    private var usedClueThisPuzzle = false
    private var madeWrongPlacementThisPuzzle = false
    private var returnPageAfterAchievements: BookPage?
    /// A marker chosen from the Debug QA panel while the next Puzzle is still
    /// on the briefing page. It is applied only after that Puzzle has been
    /// dealt, so the marker always targets a real blank without starting play
    /// from a settings sheet.
    #if DEBUG && targetEnvironment(simulator)
    private var pendingQAMarker: String?
    #endif

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
        let unit: ProbablySudokuEngine.Unit
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
    /// Kept on the next briefing so taking a Clipping has a visible, specific
    /// result instead of silently changing a future rule or balance.
    private(set) var lastClipping: Clipping?
    private(set) var message: String?

    init(seed: String = GameModel.randomSeed(),
         book: Book = .probably,
         obstacle: Obstacle = .none) {
        game = Game(seed: seed, book: book, obstacle: obstacle)
        armFirstRunTutorialIfEligible()
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
        if let puzzle = game.puzzle,
           puzzle.phase == .playing || puzzle.phase == .keepFilling {
            page = .puzzle
            refreshHandCards(replacing: true)
            startClock()
        } else if game.puzzle != nil {
            // A target can have been reached just before the app is closed or
            // replaced by a new build. The Puzzle still exists for the payout
            // and next-page decision, but it is no longer playable.
            page = .results
        } else if game.shop != nil {
            page = .shop
        } else if game.run.outcome != nil {
            page = .results
        }
    }

    private func persist() {
        PlayerProfileStore.shared.recordCoinBalance(game.run.coins)
        guard let outcome = game.run.outcome else {
            RunStore.save(game)
            return
        }

        guard !didRecordTerminalOutcome else {
            RunStore.save(game)
            return
        }

        didRecordTerminalOutcome = true
        switch outcome {
        case .bookCompleted:
            RunStore.recordBookCompleted(game.run.book)
            PlayerProfileStore.shared.recordBookCompleted(volume: game.run.book.volume,
                                                          obstacle: game.run.obstacle)
            report(RunStore.booksCompleted, to: .booksCompleted)
        case .failed:
            break
        }
        RunStore.save(game)
    }

    nonisolated static func randomSeed() -> String {
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

    var canOfferRewardedRescue: Bool {
        animatesHandArrival && !wantsMenu && game.canClaimRewardedRescue
    }
    var hasRewardedRescueInFlight: Bool { rewardedRescue.isActive }

    func beginRewardedRescue() -> UUID? {
        guard canOfferRewardedRescue, page == .results else { return nil }
        return rewardedRescue.begin(for: game)
    }

    @discardableResult
    func receiveRewardedRescue(_ ticket: UUID) -> Bool {
        guard animatesHandArrival, !wantsMenu else { return false }
        // Mutating the single Game value runs the normal atomic save path:
        // the +3 budget and consumed reward are persisted together, before
        // the ad closes. Relaunching now resumes the rewarded puzzle.
        return rewardedRescue.receive(ticket, game: &game)
    }

    func hasEarnedRewardedRescue(_ ticket: UUID) -> Bool {
        rewardedRescue.hasEarned(ticket)
    }

    func finishRewardedRescue(_ ticket: UUID) {
        guard rewardedRescue.finish(ticket, game: game), !wantsMenu else { return }
        refreshHandCards()
        clearSelection()
        lastOutcome = nil
        message = "Three more turns. Make them count."
        // Preserve a running boss clock; only a restored pending offer lacks
        // its presentation timer, just like the existing resume path.
        if secondsLeft == nil { startClock() }
        page = .puzzle
    }

    func declineRewardedRescue() {
        guard !hasRewardedRescueInFlight else { return }
        rewardedRescue.invalidate()
        guard game.declineRewardedRescue() else { return }
        showResults()
    }

    var bookCompletionSummary: BookCompletionSummary? {
        guard run.outcome == .bookCompleted else { return nil }
        let loadout = run.bookmarks.map { $0.def.name }
            + run.markers.map { $0.def.name }
            + run.buffs.map { $0.def.name }
            + run.subscriptions.map { $0.def.name }
        let nextBook = BookEdition.shelf.first { $0.rule.volume == run.book.volume + 1 }
        return BookCompletionSummary(
            edition: edition,
            levelsCleared: 9,
            bossesBeaten: 9,
            bestPuzzleScore: run.bestPuzzleScore,
            loadout: loadout,
            nextBook: nextBook
        )
    }

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

    private func presentReturn(kind: NumberReturn.Kind, digits: [Digit] = [],
                               square: Square? = nil, fouledSquares: [Square] = [],
                               penalty: Int? = nil) {
        let event = NumberReturn(kind: kind, digits: digits, square: square,
                                 fouledSquares: fouledSquares, penalty: penalty)
        numberReturns.append(event)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(850))
            numberReturns.removeAll { $0.id == event.id }
        }
    }

    /// Bosses change state at the start of a Turn. Compare the two public
    /// rule-state snapshots rather than duplicating any selection logic here.
    private func presentBossChanges(from previous: BossFeedbackSnapshot) {
        let current = BossFeedbackSnapshot(puzzle)
        let newlyBlocked = current.blocked.subtracting(previous.blocked).sorted()
        if !newlyBlocked.isEmpty {
            presentReturn(kind: .barred, digits: newlyBlocked)
        }

        let newlyFouled = current.fouled.subtracting(previous.fouled).sorted {
            $0.index < $1.index
        }
        if !newlyFouled.isEmpty {
            presentReturn(kind: .fouled, fouledSquares: newlyFouled)
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
            showResults()
        } else {
            secondsLeft = remaining
        }
    }

    /// Which Book this is, and therefore what it says in the margins.
    var edition: BookEdition { BookEdition.edition(for: game.run.book) }

    /// The line written in the margin this Turn, if the Book has anything to
    /// say. Derived from the seed, so a Book always says the same things in the
    /// same places.
    var marginNote: MarginNote? {
        guard let puzzle, puzzle.phase == .playing || puzzle.phase == .keepFilling else {
            return nil
        }
        if isTeachingFirstRun,
           let index = FirstRunTutorial.lineIndex(book: run.book, level: puzzle.level,
                                                  slot: puzzle.slot, turn: puzzle.turnNumber) {
            return MarginNote.firstRunTeachingLine(at: index)
        }
        return MarginNote.roll(seed: run.seed,
                               level: puzzle.level,
                               slot: puzzle.slot.rawValue,
                               turn: puzzle.turnNumber,
                               from: edition)
    }

    private func armFirstRunTutorialIfEligible() {
        isTeachingFirstRun = game.run.book == .probably
            && PlayerProfileStore.shared.needsFirstRunTutorial
    }

    /// Squares carrying a Marker, unless The Fog is hiding them (§13).
    var visibleMarkers: [Square: OwnedMarker] {
        guard puzzle?.boss?.hidesMarkedSquares != true else { return [:] }
        return run.markedSquares
    }
    var activeBookmarkIDs: Set<String> { effectActivation?.bookmarkIDs ?? [] }
    func markerEffect(at square: Square) -> String? {
        effectActivation?.markerSquare == square ? effectActivation?.markerText : nil
    }
    var markersAreHidden: Bool { puzzle?.boss?.hidesMarkedSquares == true }
    var sleepingBookmark: Int? { puzzle?.disabledBookmark }
    /// Kept separate from the generic barred set so a Boss board can print
    /// Over Pusher's wet ink differently from either of the Garrys' greyed
    /// units without learning any game rules itself.
    var fouledSquares: Set<Square> {
        guard let fouled = puzzle?.bossTurn?.fouled else { return [] }
        return Set(fouled.keys)
    }
    var greyedSquares: Set<Square> { puzzle?.bossTurn?.greyed ?? [] }
    func isBarred(_ square: Square) -> Bool { puzzle?.isBarred(square) ?? false }

    var selectedDigit: Digit? {
        guard let index = selectedHandIndex, hand.indices.contains(index) else { return nil }
        return hand[index]
    }

    /// Litmus is deliberately usable with the normal semantic controls: select
    /// a number, inspect each labelled blank, then activate the intended
    /// square. A drag is not required for the feedback.
    var isReadingLitmus: Bool {
        puzzle?.armedFlags.contains(.litmus) ?? false
    }

    func litmusReading(at square: Square) -> Bool? {
        guard isReadingLitmus, let puzzle, let digit = selectedDigit,
              puzzle.board.isBlank(square), !puzzle.isBarred(square) else { return nil }
        return puzzle.board.correctDigit(at: square) == digit
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

    /// Neutral page areas let a player put the pencil down without changing a
    /// square, spending a Buff, or opening any Book chrome.
    func dismissSelection() {
        clearSelection()
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
        if isBlocked(handIndex: index) {
            message = "\(hand[index].rawValue) is blocked this Turn — it can still be Tossed"
        }
        selectedHandIndex = selectedHandIndex == index ? nil : index
    }

    /// Obstacle III bars one number a Turn. It stays in the Hand — it can be
    /// seen and Tossed — but it cannot go on the board.
    func isBlocked(handIndex: Int) -> Bool {
        puzzle?.isBlocked(handIndex: handIndex) ?? false
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
        guard hand.indices.contains(handIndex) else { return }
        let digit = hand[handIndex]
        let wasKeepingFilling = puzzle?.phase == .keepFilling
        let bossBefore = BossFeedbackSnapshot(puzzle)
        do {
            let outcome = try game.place(handIndex: handIndex, at: square)
            if isTrackingAchievementPuzzle {
                madeWrongPlacementThisPuzzle = madeWrongPlacementThisPuzzle || !outcome.correct
                PlayerProfileStore.shared.recordPlacement(outcome, duringKeepFilling: wasKeepingFilling)
            }
            refreshHandCards()
            lastOutcome = outcome
            lastPlacedSquare = square
            if outcome.correct { Haptics.scored(points: outcome.points) }
            presentEffectActivation(for: outcome, at: square)
            markCleared(outcome, at: square)
            // A placement consumes the card and changes the square, so neither
            // side of the former selection still describes an available action.
            clearSelection()
            message = outcome.correct ? nil : "Wrong number — \(outcome.penalty) points"
            if !outcome.correct {
                presentReturn(kind: outcome.returnedToHand ? .hand : .pool,
                              digits: [digit], square: square, penalty: outcome.penalty)
            }
            // A correct final card auto-ends a Turn in the engine. That needs
            // the same Boss feedback as an explicit End Turn button press.
            presentBossChanges(from: bossBefore)
        } catch {
            message = describe(error)
        }
    }

    private func presentEffectActivation(for outcome: PlacementOutcome, at square: Square) {
        let events: Set<GameEvent> = {
            if outcome.correct {
                var values: Set<GameEvent> = [.place, .anyScore]
                if !outcome.lineClears.isEmpty { values.insert(.lineClear) }
                if outcome.fullClear { values.insert(.fullClear) }
                return values
            }
            return [.wrongPlace]
        }()
        guard !events.isEmpty else { return }

        let marker = run.markedSquares[square]
        let markerFired = marker.flatMap { owned in
            events.contains { owned.def.hooks[$0] != nil } ? owned : nil
        }
        let bookmarkIDs = Set<String>(run.bookmarks.enumerated().compactMap { index, owned in
            guard sleepingBookmark != index,
                  events.contains(where: { owned.def.hooks[$0] != nil }) else { return nil }
            return owned.defID
        })
        guard markerFired != nil || !bookmarkIDs.isEmpty else { return }

        let activation = EffectActivation(markerSquare: markerFired == nil ? nil : square,
                                          markerText: markerFired?.def.text,
                                          bookmarkIDs: bookmarkIDs)
        effectActivation = activation
        Task { @MainActor in
            // Long enough to read the receipt during normal play, but short
            // enough that it never becomes persistent board chrome.
            try? await Task.sleep(for: .seconds(3))
            guard effectActivation?.id == activation.id else { return }
            effectActivation = nil
        }
    }

    /// Shows each completed unit briefly. Cleared once, on a ticket, so a
    /// second clear arriving mid-flash cannot cancel the first one's fade.
    private func markCleared(_ outcome: PlacementOutcome, at square: Square) {
        guard !outcome.lineClears.isEmpty || outcome.fullClear else { return }
        Haptics.cleared(units: outcome.lineClears.count, isFullClear: outcome.fullClear)
        clearTicket += 1
        let ticket = clearTicket
        cleared = outcome.lineClears.map { Cleared(unit: $0, square: square, ticket: ticket) }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1100))
            if clearTicket == ticket { cleared = [] }
        }
    }

    /// §5.1 — a Toss is one selected Hand slot, one number returned to the
    /// Pool. The allowance controls how often the player may repeat that
    /// action; it never turns several selected cards into a batch operation.
    func tossSelected() {
        guard let index = selectedHandIndex, hand.indices.contains(index) else {
            message = "Pick one number to Toss"
            return
        }
        let digit = hand[index]
        do {
            _ = try game.toss(handIndex: index)
            refreshHandCards()
            message = nil
            presentReturn(kind: .pool, digits: [digit])
        } catch {
            message = describe(error)
        }
        clearSelection()
    }

    var canToss: Bool {
        !handCards.isEmpty && (puzzle?.tossesRemaining ?? 0) > 0
    }

    var tossButtonTitle: String {
        "Toss"
    }

    var tossButtonSubtitle: String {
        "\(puzzle?.tossesRemaining ?? 0) left this puzzle"
    }

    func useClue(at square: Square) {
        do {
            let outcome = try game.useClue(at: square)
            if isTrackingAchievementPuzzle {
                usedClueThisPuzzle = true
                PlayerProfileStore.shared.recordPlacement(outcome, duringKeepFilling: false)
            }
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
            let redrawn = redrawsHand ? hand : []
            _ = try game.useBuff(at: index, digit: digit)
            refreshHandCards(replacing: redrawsHand)
            if !redrawn.isEmpty {
                presentReturn(kind: .redraw, digits: redrawn)
            }
            // Redraw and Lucky Dip both reshape the Hand under the selection.
            dropHandSelection()
        } catch {
            message = describe(error)
        }
    }

    func endTurn() {
        let bossBefore = BossFeedbackSnapshot(puzzle)
        do {
            let result = try game.endTurn()
            refreshHandCards()
            clearSelection()
            presentBossChanges(from: bossBefore)
            if result.puzzleFailed { showResults() }
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
        if let puzzle, puzzle.phase != .outOfTurns {
            report(puzzle.score, to: .highestPuzzleScore)
            report(puzzle.level, to: .highestLevelReached)
        }
        page = .results
    }

    func cashOut() {
        let finishedPuzzle = puzzle
        do {
            lastPayout = try game.cashOut()
            if let puzzle = finishedPuzzle, isTrackingAchievementPuzzle {
                PlayerProfileStore.shared.recordPuzzleFinished(
                    score: puzzle.score,
                    wasBoss: puzzle.isBoss,
                    hadWrongPlacement: madeWrongPlacementThisPuzzle,
                    usedClue: usedClueThisPuzzle,
                    wasLastTurn: puzzle.turnsRemaining == 1
                )
                if puzzle.isBoss, let boss = puzzle.boss {
                    PlayerProfileStore.shared.recordBossDefeated(
                        encounterID: "\(game.run.seed):\(puzzle.level):\(boss.rawValue)"
                    )
                }
                isTrackingAchievementPuzzle = false
            }
        }
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
        rewardedRescue.invalidate()
        guard game.advance() else {
            isTrackingAchievementPuzzle = false
            page = .results
            return
        }
        selectedHandIndex = nil
        selectedSquare = nil
        lastOutcome = nil
        lastPayout = nil
        page = .briefing
    }

    /// Dealing starts only after the player accepts this Puzzle. That keeps a
    /// Clipping an actual choice rather than something revealed after the
    /// board, pool, and Boss have already been rolled.
    func beginPuzzle() {
        rewardedRescue.invalidate()
        do {
            try game.startPuzzle()
            #if DEBUG && targetEnvironment(simulator)
            applyPendingQAMarker()
            #endif
            isTrackingAchievementPuzzle = true
            usedClueThisPuzzle = false
            madeWrongPlacementThisPuzzle = false
            if let level = puzzle?.level {
                report(level, to: .highestLevelReached)
                PlayerProfileStore.shared.recordReachedLevel(level)
            }
            if isTeachingFirstRun { PlayerProfileStore.shared.startFirstRunTutorial() }
            refreshHandCards(replacing: true)
            startClock()
            selectedHandIndex = nil
            selectedSquare = nil
            lastOutcome = nil
            lastClipping = nil
            page = .puzzle
            presentBossChanges(from: BossFeedbackSnapshot(nil))
        } catch {
            message = describe(error)
        }
    }

    func skipCurrentPuzzle() {
        rewardedRescue.invalidate()
        do {
            lastClipping = try game.skipPuzzle()
            PlayerProfileStore.shared.recordSkipsUsed(game.run.skipsUsed)
            isTrackingAchievementPuzzle = false
            selectedHandIndex = nil
            selectedSquare = nil
            lastOutcome = nil
            lastPayout = nil
            page = .briefing
        } catch {
            message = describe(error)
        }
    }

    func buy(slot: Int) {
        let kind = shop?.offers.first(where: { $0.slot == slot })?.def.kind
        do {
            try game.buy(slot: slot)
            if let kind {
                PlayerProfileStore.shared.recordPurchase(kind: kind,
                                                         bookmarkCount: game.run.bookmarks.count)
            }
        }
        catch { message = describe(error) }
    }

    func reroll() {
        do { try game.reroll() }
        catch { message = describe(error) }
    }

    /// §10 — sell a Bookmark or Buff for its deterministic partial refund.
    func sell(kind: ItemKind, index: Int) {
        let boughtAtLevel: Int?
        switch kind {
        case .bookmark: boughtAtLevel = game.run.bookmarks.indices.contains(index)
                ? game.run.bookmarks[index].boughtAtLevel : nil
        case .buff, .marker, .subscription: boughtAtLevel = nil
        }
        do {
            let coins = try game.sell(kind: kind, index: index)
            PlayerProfileStore.shared.recordSale(boughtAtLevel: boughtAtLevel,
                                                 currentLevel: game.run.level)
            message = "Sold for \(coins) \(coins == 1 ? "coin" : "coins")"
            dropHandSelection()
        } catch {
            message = describe(error)
        }
    }

    func sellPrice(_ pricePaid: Int) -> Int { Shop.sellPrice(pricePaid) }

    /// The achievement page is a page in the current Book. Keep the origin so
    /// closing it returns to the exact puzzle, results, or shop page the
    /// player was reading rather than inventing a navigation reset.
    func openAchievements() {
        guard page != .achievements else { return }
        returnPageAfterAchievements = page
        page = .achievements
    }

    func closeAchievements() {
        page = returnPageAfterAchievements ?? .puzzle
        returnPageAfterAchievements = nil
    }

    @discardableResult
    func claimSquare(markerIndex: Int, square: Square) -> Bool {
        do {
            try game.claimSquare(markerIndex: markerIndex, square: square)
            return true
        } catch {
            message = describe(error)
            return false
        }
    }

    /// Leaving a run returns to the cover because a Book carries its own rules
    /// and benefit; a new Book has to be opened, not silently dealt.
    var wantsMenu = false

    /// Give the run up. This has to actually destroy the save — leaving it on
    /// disk means the shelf offers to continue a Book the player was told they
    /// had abandoned. Putting a Book down needs no button: closing the app
    /// keeps it, and the shelf offers to continue.
    func abandonRun() {
        rewardedRescue.invalidate()
        RunStore.clearRun()
        wantsMenu = true
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Restarts in place, without going back to the cover. Used by QA only.
    func startNewBook(book: Book? = nil) {
        game = Game(seed: Self.randomSeed(), book: book ?? game.run.book,
                    obstacle: game.run.obstacle)
        selectedHandIndex = nil
        selectedSquare = nil
        lastOutcome = nil
        isTrackingAchievementPuzzle = false
        usedClueThisPuzzle = false
        madeWrongPlacementThisPuzzle = false
        lastPayout = nil
        message = nil
        armFirstRunTutorialIfEligible()
        page = .briefing
    }
    #endif

    func clearMessage() { message = nil }

    /// GameKit is an optional reporter, not part of the rules. Deferring onto
    /// the main actor keeps its system API out of every gameplay action's
    /// critical path and leaves the engine entirely platform-independent.
    private func report(_ value: Int, to leaderboard: GameCenterService.Leaderboard) {
        Task { @MainActor in
            GameCenterService.shared.record(value, for: leaderboard)
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    // QA shortcuts never compile into Release or physical-device builds.
    private static let qaUndoLimit = 20
    private var qaUndoStack: [Game] = []
    private var isRestoringQAUndo = false

    var qaCanUndo: Bool { !qaUndoStack.isEmpty }

    /// `Game` owns the entire value-type run state, including the seeded RNG
    /// streams. Capturing it at the write boundary keeps the QA escape hatch
    /// exact without teaching production rules about inverse operations.
    private func recordQAUndoSnapshot() {
        guard !isRestoringQAUndo else { return }
        if qaUndoStack.count == Self.qaUndoLimit { qaUndoStack.removeFirst() }
        qaUndoStack.append(game)
    }

    func qaUndoLastAction() {
        guard let snapshot = qaUndoStack.popLast() else { return }
        isRestoringQAUndo = true
        game = snapshot
        isRestoringQAUndo = false

        selectedHandIndex = nil
        selectedSquare = nil
        highlightSource = nil
        cleared = []
        lastOutcome = nil
        lastPlacedSquare = nil
        lastPayout = nil
        message = nil
        if game.puzzle != nil {
            page = .puzzle
            refreshHandCards(replacing: true)
            startClock()
        } else if game.shop != nil {
            page = .shop
            stopClock()
        } else if game.run.outcome != nil {
            page = .results
            stopClock()
        } else {
            page = .briefing
            stopClock()
        }
    }

    func qaAward(points: Int) { game.qaAward(points: points) }
    func qaAward(coins: Int) { game.qaAward(coins: coins) }
    func qaMeetTarget() { game.qaMeetTarget() }
    func qaCompleteBook() {
        game.qaCompleteBook()
        page = .results
    }
    func qaFailPuzzle() { game.qaFailPuzzle(); page = .results }
    func qaFailBook(atLevel level: Int) {
        game.qaFailBook(atLevel: level)
        page = .results
    }
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
        if let square = puzzle?.board.blanks.first {
            game.qaSetMarker(defID, at: square)
        } else {
            pendingQAMarker = defID
        }
    }

    private func applyPendingQAMarker() {
        guard let defID = pendingQAMarker,
              let square = puzzle?.board.blanks.first else { return }
        game.qaSetMarker(defID, at: square)
        pendingQAMarker = nil
    }
    func qaSetBuff(_ defID: String) { game.qaSetBuff(defID) }
    func qaSetSubscription(_ defID: String) {
        game.qaSetSubscription(defID)
        refreshHandCards()
    }
    func qaSetBoss(_ boss: BossModifier) {
        game.qaSetBoss(boss)
        refreshHandCards()
        startClock()
    }
    func qaEarnAchievement(_ id: String) {
        PlayerProfileStore.shared.qaEarnAchievement(id)
    }
    func qaResetFirstRunTutorial() {
        PlayerProfileStore.shared.resetFirstRunTutorial()
        startNewBook(book: .probably)
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
