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

    /// Immutable completion facts used by the final page and retained across
    /// book closing, so the returning shelf keeps the completed volume's identity.
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
    private(set) var scorePerformance: ScorePerformance?
    private(set) var scoreBeat: ScorePerformance.Beat?
    private(set) var presentedScore: Int?
    private(set) var presentedQueue: Int?
    var isPresentingScore: Bool { scorePerformance != nil }

    func presentScore(_ performance: ScorePerformance) {
        guard animatesHandArrival, !performance.beats.isEmpty else {
            finishScorePresentation()
            return
        }
        effectActivation = nil
        scorePerformance = performance
        scoreBeat = performance.beats.first
        presentedScore = performance.bankedFrom
        presentedQueue = performance.queuedFrom
    }

    func advanceScore(_ beat: ScorePerformance.Beat, performanceID: UUID) {
        guard scorePerformance?.id == performanceID else { return }
        scoreBeat = beat
        if let queuedBase = beat.queuedBase { presentedQueue = queuedBase }
        if beat.kind == .bank { presentedScore = scorePerformance?.finalScore }
    }

    func finishScorePresentation(id: UUID? = nil) {
        guard id == nil || scorePerformance?.id == id else { return }
        scorePerformance = nil
        scoreBeat = nil
        presentedScore = nil
        presentedQueue = nil
    }

    func bookmarkScoreLabel(_ id: String) -> String? {
        scoreBeat?.sourceID == id ? scoreBeat?.value : nil
    }

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
        didSet {
            invalidatePuzzlePreparation()
            persist()
        }
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
    private(set) var isChoosingClue = false

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
    struct CoinCharge: Identifiable {
        let id = UUID()
        let amount: Int
    }
    private(set) var lastCoinCharge: CoinCharge?
    private(set) var lastPlacedSquare: Square?
    private(set) var lastPayout: RunState.Payout?
    /// Kept on the next briefing so taking a Clipping has a visible, specific
    /// result instead of silently changing a future rule or balance.
    private(set) var lastClipping: Clipping?
    private(set) var message: String?
    /// Render-only snapshots must never write stale state over a live Book.
    private var savesProgress = true

    /// The revision covers the entire value-type Game, including inventory and
    /// all RNG streams. A prepared deal never overwrites a newer player action.
    private(set) var puzzlePreparationRevision: UInt64 = 0
    struct PreparedPuzzle: Sendable {
        fileprivate let revision: UInt64
        fileprivate let requestID: UUID
        fileprivate let game: Game
    }
    private struct PuzzlePreparation: Sendable {
        let revision: UInt64
        let requestID: UUID
        let task: Task<Result<Game, Error>, Never>
    }
    @ObservationIgnored private var puzzlePreparation: PuzzlePreparation?
    @ObservationIgnored private var preparedPuzzle: PreparedPuzzle?

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
        self.savesProgress = false
        self.animatesHandArrival = false
        self.secondsLeft = game.puzzle.flatMap { puzzle in
            puzzle.boss?.secondsAllowed.map { limit in
                min(limit, max(0, puzzle.clockSecondsRemaining ?? limit)).rounded(.up)
            }
        }
        self.clockIsUrgent = secondsLeft.map { $0 <= 30 } ?? false
        refreshHandCards(replacing: true)
    }

    /// Resumes a Book that was put down.
    init(resuming game: Game, savesProgress: Bool = true) {
        self.game = game
        self.savesProgress = savesProgress
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
            startClock()
        } else if game.shop != nil {
            page = .shop
        } else if game.run.outcome != nil {
            page = .results
        }
        settleFinalVictoryIfNeeded()
        if self.game.run.outcome == .bookCompleted {
            page = .results
            // A legacy paid final board/Shop can normalize to completed while
            // decoding, before this model observes any Game mutation.
            if !didRecordTerminalOutcome { persist() }
        }
    }

    private func persist() {
        guard savesProgress, !wantsMenu else { return }
        let savedGame = gameForPersistence
        PlayerProfileStore.shared.recordCoinBalance(game.run.coins)
        guard let outcome = game.run.outcome else {
            RunStore.save(savedGame)
            return
        }

        guard !didRecordTerminalOutcome else {
            RunStore.save(savedGame)
            return
        }

        didRecordTerminalOutcome = true
        switch outcome {
        case .bookCompleted:
            RunStore.recordBookCompleted(game.run.book, obstacle: game.run.obstacle)
            PlayerProfileStore.shared.recordBookCompleted(volume: game.run.book.volume,
                                                          obstacle: game.run.obstacle)
            report(RunStore.booksCompleted, to: .booksCompleted)
        case .failed:
            break
        }
        RunStore.save(savedGame)
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
    private func refreshHandCards(replacing: Bool = false,
                                  consuming index: Int? = nil,
                                  returningConsumedCard: Bool = false) {
        let updatedHand = hand
        guard !replacing else {
            handCards = updatedHand.enumerated().map {
                HandCard(id: UUID(), digit: $0.element, arrivalOrder: $0.offset)
            }
            return
        }

        var remainingCards = handCards
        // A printed digit is not a card's identity. Remove the exact card the
        // engine consumed before matching survivors, or playing the first of
        // two identical numbers makes the later, untouched card disappear.
        if let index, remainingCards.indices.contains(index) {
            let consumed = remainingCards.remove(at: index)
            if returningConsumedCard { remainingCards.append(consumed) }
        }
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

    /// Display ticks do not mutate the observed Game (or its board). The
    /// fractional active-play budget is merged into every saved Game copy.
    private(set) var secondsLeft: Double?
    private(set) var clockIsUrgent = false
    @ObservationIgnored private var clockRemaining: Double?
    @ObservationIgnored private var clockLastSample: ContinuousClock.Instant?
    @ObservationIgnored private var clockPuzzleID: String?

    private var currentClockPuzzleID: String? {
        guard let puzzle, let boss = puzzle.boss, boss.secondsAllowed != nil else { return nil }
        return "\(run.seed):\(puzzle.level):\(puzzle.slot.rawValue):\(boss.rawValue)"
    }

    /// Use this snapshot for persistence, not the display-only timer label.
    /// Other game actions cannot overwrite a newer countdown checkpoint.
    var gameForPersistence: Game {
        guard let clockRemaining, let clockPuzzleID,
              clockPuzzleID == currentClockPuzzleID else { return game }
        var savedRun = game.run
        savedRun.puzzle?.clockSecondsRemaining = clockRemaining
        return Game(run: savedRun)
    }

    var isClockRunning: Bool { clockLastSample != nil }

    func startClock() {
        guard animatesHandArrival else { return }
        guard let identifier = currentClockPuzzleID, let limit = puzzle?.boss?.secondsAllowed else {
            stopClock()
            return
        }
        if clockPuzzleID != identifier || clockRemaining == nil {
            let saved = puzzle?.clockSecondsRemaining ?? limit
            clockRemaining = saved.isFinite ? min(limit, max(0, saved)) : limit
        }
        clockPuzzleID = identifier
        clockLastSample = nil
        updateClockDisplay()
    }

    func stopClock() {
        guard animatesHandArrival else { return }
        clockLastSample = nil
        clockPuzzleID = nil
        clockRemaining = nil
        updateClockDisplay()
    }

    /// A single lifecycle gate owns pause/resume. Re-enabling it starts a new
    /// monotonic sample rather than charging time spent under a slip or away.
    func setClockRunning(_ running: Bool, at now: ContinuousClock.Instant = ContinuousClock().now) {
        guard animatesHandArrival, clockPuzzleID == currentClockPuzzleID,
              clockRemaining != nil else { return }
        let playable = puzzle?.phase == .playing || puzzle?.phase == .keepFilling
        if running && playable && page == .puzzle && !wantsMenu {
            if clockRemaining == 0 { expireClock(); return }
            if clockLastSample == nil { clockLastSample = now }
        } else if clockLastSample != nil {
            advanceClock(to: now)
            clockLastSample = nil
            saveClockCheckpoint(publishToCloud: true)
        }
    }

    /// Scheduled once a second, but charges the real monotonic interval so
    /// a delayed main-actor wakeup cannot silently lengthen the four minutes.
    func tickClock(at now: ContinuousClock.Instant = ContinuousClock().now) {
        guard animatesHandArrival, page == .puzzle, !wantsMenu,
              clockPuzzleID == currentClockPuzzleID, clockLastSample != nil else { return }
        advanceClock(to: now)
        saveClockCheckpoint(publishToCloud: false)
    }

    private func advanceClock(to now: ContinuousClock.Instant) {
        guard let previous = clockLastSample, let remaining = clockRemaining,
              puzzle?.phase == .playing || puzzle?.phase == .keepFilling else { return }
        let duration = previous.duration(to: now).components
        let elapsed = Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        guard elapsed.isFinite, elapsed > 0 else { return }
        clockLastSample = now
        clockRemaining = max(0, remaining - elapsed)
        updateClockDisplay()
        if clockRemaining == 0 { expireClock() }
    }

    private func expireClock() {
        guard animatesHandArrival,
              puzzle?.phase == .playing || puzzle?.phase == .keepFilling else { return }
        clockLastSample = nil
        clockRemaining = 0
        updateClockDisplay()
        message = "Out of time"
        game.failPuzzle()
        // The displayed Puzzle stays intact for the outgoing leaf. GameView
        // presents results after its first frame (or when a covering slip closes).
    }

    private func updateClockDisplay() {
        let display = clockRemaining?.rounded(.up)
        if secondsLeft != display { secondsLeft = display }
        let urgent = clockRemaining.map { $0 <= 30 } ?? false
        if clockIsUrgent != urgent { clockIsUrgent = urgent }
    }

    private func saveClockCheckpoint(publishToCloud: Bool) {
        guard savesProgress, !wantsMenu, animatesHandArrival, run.outcome == nil,
              clockRemaining != nil, clockPuzzleID == currentClockPuzzleID else { return }
        RunStore.save(gameForPersistence, publishToCloud: publishToCloud)
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
    var activeBookmarkIDs: Set<String> {
        if let id = scoreBeat?.sourceID { return [id] }
        return effectActivation?.bookmarkIDs ?? []
    }
    func markerEffect(at square: Square) -> String? {
        guard !markersAreHidden else { return nil }
        return effectActivation?.markerSquare == square ? effectActivation?.markerText : nil
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
        isChoosingClue = false
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

    /// The score can finish printing after the engine has already won/lost.
    /// Outgoing controls must not submit another action during that interval.
    var acceptsPuzzleInput: Bool {
        puzzle?.phase == .playing || puzzle?.phase == .keepFilling
    }

    func tapHand(_ index: Int) {
        guard acceptsPuzzleInput else { return }
        guard hand.indices.contains(index) else { return }
        let choosingClue = isChoosingClue
        if isBlocked(handIndex: index) {
            message = "\(hand[index].rawValue) is blocked this Turn — it can still be Tossed"
        }
        let nextIndex = selectedHandIndex == index ? nil : index
        // A hand tap starts a new choice, not a second selection beside the
        // board. Tapping the same card again puts the pencil down completely.
        clearSelection()
        selectedHandIndex = nextIndex
        if animatesHandArrival, nextIndex != nil {
            GameAudio.shared.play(.menuTap)
            Haptics.lift()
        }
        if choosingClue {
            selectedHandIndex = index
            revealClueForSelectedCard()
        }
    }

    /// Obstacle III bars one number a Turn. It stays in the Hand — it can be
    /// seen and Tossed — but it cannot go on the board.
    func isBlocked(handIndex: Int) -> Bool {
        puzzle?.isBlocked(handIndex: handIndex) ?? false
    }

    func tapSquare(_ square: Square) {
        guard let puzzle,
              puzzle.phase == .playing || puzzle.phase == .keepFilling else { return }
        guard !puzzle.isBarred(square) else {
            message = "That square is barred this Turn"
            return
        }
        // An occupied square is for reading its digit, never placing the
        // previously held card. Preserve the hand only for blank-square play.
        if !puzzle.board.isBlank(square) { dropHandSelection() }
        isChoosingClue = false
        selectedSquare = square
        highlightSource = .square

        guard puzzle.board.isBlank(square), let index = selectedHandIndex else { return }
        place(handIndex: index, at: square)
    }

    func place(handIndex: Int, at square: Square) {
        // A delayed drag/tap can arrive after the results page has replaced
        // the board. The engine rejects it, but the presentation boundary
        // must also avoid turning that expected rejection into a new message.
        guard puzzle?.phase == .playing || puzzle?.phase == .keepFilling else { return }
        guard hand.indices.contains(handIndex) else { return }
        let digit = hand[handIndex]
        let wasKeepingFilling = puzzle?.phase == .keepFilling
        let coinCost = puzzle?.boss?.coinsPerPlacement ?? 0
        let bossBefore = BossFeedbackSnapshot(puzzle)
        let previousScore = puzzle?.score ?? 0
        let previousQueue = puzzle?.pendingBase ?? 0
        do {
            let outcome = try game.place(handIndex: handIndex, at: square)
            if coinCost > 0 { lastCoinCharge = CoinCharge(amount: coinCost) }
            if isTrackingAchievementPuzzle {
                madeWrongPlacementThisPuzzle = madeWrongPlacementThisPuzzle || !outcome.correct
            }
            if savesProgress {
                PlayerProfileStore.shared.recordPlacement(outcome, duringKeepFilling: wasKeepingFilling)
            }
            refreshHandCards(consuming: handIndex,
                             returningConsumedCard: outcome.returnedToHand)
            lastOutcome = outcome
            lastPlacedSquare = square
            if animatesHandArrival {
                if outcome.correct {
                    GameAudio.shared.play(.tilePlace)
                    // A clear owns one deliberate pattern; do not layer a
                    // second buzzing score pattern over the same placement.
                    if outcome.lineClears.isEmpty && !outcome.fullClear {
                        Haptics.scored(points: outcome.points)
                    }
                } else {
                    GameAudio.shared.play(.error)
                    Haptics.error()
                }
            }
            presentEffectActivation(for: outcome, at: square)
            if outcome.correct {
                presentScore(.placement(outcome, square: square,
                                        previousScore: previousScore, finalScore: puzzle?.score ?? 0,
                                        previousQueue: previousQueue))
            } else {
                finishScorePresentation()
            }
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

        let marker = markersAreHidden ? nil : run.markedSquares[square]
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
        guard acceptsPuzzleInput else { return }
        guard let index = selectedHandIndex, hand.indices.contains(index) else {
            message = "Pick one number to Toss"
            return
        }
        let digit = hand[index]
        do {
            _ = try game.toss(handIndex: index)
            if animatesHandArrival {
                GameAudio.shared.play(.toss)
                Haptics.tossed()
            }
            refreshHandCards(consuming: index)
            message = nil
            presentReturn(kind: .pool, digits: [digit])
        } catch {
            message = describe(error)
        }
        clearSelection()
    }

    var canToss: Bool {
        acceptsPuzzleInput && !handCards.isEmpty && (puzzle?.tossesRemaining ?? 0) > 0
    }

    var tossButtonTitle: String {
        "Toss"
    }

    var tossButtonSubtitle: String {
        "\(puzzle?.tossesRemaining ?? 0) left this puzzle"
    }

    func useClue(at square: Square) {
        let wasKeepingFilling = puzzle?.phase == .keepFilling
        // The legacy direct-square action takes the solution number from the
        // Pool first, otherwise the first matching Hand slot. Record only that
        // identity decision; no Pool counts are exposed in the presentation.
        let consumedIndex = puzzle.flatMap { puzzle -> Int? in
            let digit = puzzle.board.correctDigit(at: square)
            return puzzle.poolCount(of: digit) == 0 ? puzzle.hand.firstIndex(of: digit) : nil
        }
        do {
            let outcome = try game.useClue(at: square)
            if isTrackingAchievementPuzzle {
                usedClueThisPuzzle = true
            }
            if savesProgress {
                PlayerProfileStore.shared.recordPlacement(outcome, duringKeepFilling: wasKeepingFilling)
            }
            refreshHandCards(consuming: consumedIndex)
            clearSelection()
            lastPlacedSquare = square
            markCleared(outcome, at: square)
        } catch {
            message = describe(error)
        }
    }

    /// A Clue now starts with a card, never an arbitrary board square.
    /// Selection mode itself is free; the engine spends the clue only when it
    /// has a legal destination to reveal for a playable held number.
    func chooseClue() {
        guard acceptsPuzzleInput else { return }
        if isChoosingClue {
            dismissSelection()
        } else if selectedHandIndex != nil {
            revealClueForSelectedCard()
        } else if puzzle?.canUseClue == true {
            clearSelection()
            isChoosingClue = true
            message = "Choose a number from your hand for the Clue"
        }
    }

    private func revealClueForSelectedCard() {
        guard let index = selectedHandIndex else { return }
        do {
            let square = try game.revealClue(handIndex: index)
            if isTrackingAchievementPuzzle { usedClueThisPuzzle = true }
            isChoosingClue = false
            selectedSquare = nil
            highlightSource = .hand
            message = "Clue: place \(hand[index].rawValue) in row \(square.row + 1), column \(square.col + 1)"
        } catch {
            isChoosingClue = false
            message = describe(error)
        }
    }

    func isClueDestination(_ square: Square) -> Bool {
        guard let puzzle, puzzle.boss?.disablesClues != true,
              let digit = selectedDigit,
              puzzle.clueReveals.contains(square), puzzle.board.isBlank(square),
              !puzzle.isBarred(square),
              let index = selectedHandIndex, !puzzle.isBlocked(handIndex: index) else { return false }
        return puzzle.board.correctDigit(at: square) == digit
    }

    @discardableResult
    func useBuff(at index: Int, digit: Digit? = nil) -> Bool {
        finishScorePresentation()
        do {
            let peeks = game.run.buffs.indices.contains(index)
                && game.run.buffs[index].defID == Buffs.peek
            let redrawsHand = game.run.buffs.indices.contains(index)
                && game.run.buffs[index].defID == Buffs.redraw
            let redrawn = redrawsHand ? hand : []
            guard try game.useBuff(at: index, digit: digit) else {
                message = "This Buff has no effect right now — kept"
                return false
            }
            if savesProgress { PlayerProfileStore.shared.recordBuffUsed() }
            if animatesHandArrival { GameAudio.shared.play(.paperTurn) }
            refreshHandCards(replacing: redrawsHand)
            if !redrawn.isEmpty {
                presentReturn(kind: .redraw, digits: redrawn)
            }
            // Redraw and Lucky Dip both reshape the Hand under the selection.
            dropHandSelection()
            if peeks { chooseClue() }
            return true
        } catch {
            message = describe(error)
            return false
        }
    }

    func endTurn() {
        guard acceptsPuzzleInput else { return }
        let bossBefore = BossFeedbackSnapshot(puzzle)
        let previousScore = puzzle?.score ?? 0
        do {
            let result = try game.endTurn()
            presentScore(.banking(result, previousScore: previousScore, finalScore: puzzle?.score ?? 0))
            refreshHandCards()
            clearSelection()
            presentBossChanges(from: bossBefore)
            // Phase changes drive GameView's page turn; changing `page` here
            // would replace the outgoing board before it can be captured.
        } catch {
            message = describe(error)
        }
    }

    // MARK: - Page turns

    /// What cashing out would pay, worked out before you commit to it. Pure, so
    /// showing it costs nothing and the decision is an informed one. A banked
    /// Puzzle instead returns its original receipt, if the save contains one.
    var payoutPreview: RunState.Payout? {
        guard let puzzle else { return nil }
        if puzzle.phase == .cashedOut { return puzzle.bankedPayout }
        return run.payout(for: puzzle)
    }

    /// Finishing a Puzzle turns the page rather than throwing up a panel.
    func showResults() {
        if animatesHandArrival, page != .results,
           let puzzle, puzzle.phase == .won || puzzle.phase == .cashedOut {
            GameAudio.shared.play(.win)
        }
        if savesProgress, let puzzle, puzzle.phase != .outOfTurns {
            report(puzzle.score, to: .highestPuzzleScore)
            report(puzzle.level, to: .highestLevelReached)
        }
        settleFinalVictoryIfNeeded()
        page = .results
    }
    /// The last Boss ends the Book, not another payout/Keep Filling choice.
    /// Use the existing cash-out action so its receipt and achievement hooks
    /// stay identical. Frozen construction never calls this explicit action.
    private func settleFinalVictoryIfNeeded() {
        guard run.outcome == nil, run.isFinalPuzzle,
              let puzzle, puzzle.level == 9, puzzle.isBoss,
              puzzle.boss != nil, puzzle.phase == .won else { return }
        cashOut()
    }

    func cashOut() {
        let finishedPuzzle = puzzle
        do {
            lastPayout = try game.cashOut()
            if let puzzle = finishedPuzzle, savesProgress {
                PlayerProfileStore.shared.recordPuzzleFinished(
                    score: puzzle.score,
                    target: puzzle.target,
                    wasBoss: puzzle.isBoss,
                    hadWrongPlacement: madeWrongPlacementThisPuzzle,
                    usedClue: usedClueThisPuzzle,
                    tossesUsed: puzzle.tossedThisPuzzle,
                    turnsRemaining: puzzle.turnsRemaining,
                    hasCompleteHistory: isTrackingAchievementPuzzle
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
        do {
            try game.keepFilling()
            page = .puzzle
        } catch {
            message = describe(error)
        }
    }

    /// Results → shop, the first of the two page turns between Puzzles.
    func openShop() {
        game.openShop()
        // The final cash-out completes the Book, so the engine intentionally
        // creates no Shop. Keep its final board and results page in place.
        page = game.run.outcome == nil && game.shop != nil ? .shop : .results
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

    /// The live deal commits only after the player accepts this Puzzle. That keeps a
    /// Clipping an actual choice rather than something revealed after the
    /// board, pool, and Boss have already been rolled.
    func beginPuzzle() {
        finishScorePresentation()
        cancelPuzzlePreparation()
        rewardedRescue.invalidate()
        stopClock()
        do {
            try game.startPuzzle()
            finishBeginningPuzzle()
        } catch {
            message = describe(error)
        }
    }

    /// The worker owns a copy. Until the first printed flip frame commits it,
    /// neither the live board stream nor a saved Book has advanced.
    func prepareUpcomingPuzzle(
        reportFailure: Bool = false,
        using generate: @escaping @Sendable (Game) throws -> Game = { try GameModel.generateUpcomingPuzzle($0) },
        warmingPersistenceWith warmEncoding: @escaping @Sendable (Game) -> Void = { GameModel.warmPersistenceEncoding($0) }
    ) async -> PreparedPuzzle? {
        guard canPreparePuzzle, !Task.isCancelled else { return nil }
        if let preparedPuzzle, preparedPuzzle.revision == puzzlePreparationRevision {
            return preparedPuzzle
        }

        let work: PuzzlePreparation
        if let current = puzzlePreparation,
           current.revision == puzzlePreparationRevision, !current.task.isCancelled {
            work = current
        } else {
            let source = game
            let task = Task.detached(priority: .userInitiated) {
                Result<Game, Error> {
                    try Task.checkCancellation()
                    let generated = try generate(source)
                    try Task.checkCancellation()
                    // First-use Codable metadata was being realized by the
                    // synchronous save inside the page curl's first-frame
                    // callback. Warm only the worker's value; this writes no
                    // save and cannot advance the live Book or its RNG.
                    warmEncoding(generated)
                    try Task.checkCancellation()
                    return generated
                }
            }
            work = PuzzlePreparation(revision: puzzlePreparationRevision,
                                     requestID: UUID(), task: task)
            puzzlePreparation = work
        }

        // The briefing owns this shared worker; a cancelled Play waiter must
        // not cancel the same preparation still being warmed by the page.
        // Departure/background/revision changes explicitly cancel its owner.
        let result = await work.task.value
        guard !Task.isCancelled, !work.task.isCancelled, canPreparePuzzle,
              work.revision == puzzlePreparationRevision,
              puzzlePreparation?.requestID == work.requestID else { return nil }
        switch result {
        case .success(let generated):
            let ready = PreparedPuzzle(revision: work.revision,
                                       requestID: work.requestID, game: generated)
            preparedPuzzle = ready
            return ready
        case .failure(let error):
            if reportFailure, !(error is CancellationError) { message = describe(error) }
            return nil
        }
    }

    /// Called only by PageFlipper's first-frame commit. Revalidate here as well
    /// as after awaiting: a Clipping, purchase, QA change, or cancelled briefing
    /// may have invalidated this prepared state while the renderer was priming.
    @discardableResult
    func beginPreparedPuzzle(_ prepared: PreparedPuzzle) -> Bool {
        guard canPreparePuzzle, prepared.revision == puzzlePreparationRevision,
              preparedPuzzle?.requestID == prepared.requestID else { return false }
        rewardedRescue.invalidate()
        stopClock()
        game = prepared.game
        finishBeginningPuzzle()
        return true
    }

    func cancelPuzzlePreparation() {
        puzzlePreparation?.task.cancel()
        puzzlePreparation = nil
        preparedPuzzle = nil
    }

    var hasPreparedPuzzle: Bool {
        canPreparePuzzle && preparedPuzzle?.revision == puzzlePreparationRevision
    }

    private func invalidatePuzzlePreparation() {
        cancelPuzzlePreparation()
        puzzlePreparationRevision &+= 1
    }

    private var canPreparePuzzle: Bool {
        animatesHandArrival && !wantsMenu && page == .briefing
            && game.puzzle == nil && game.shop == nil && game.run.outcome == nil
    }

    nonisolated private static func generateUpcomingPuzzle(_ source: Game) throws -> Game {
        var generated = source
        try generated.startPuzzle()
        return generated
    }

    nonisolated static func warmPersistenceEncoding(_ game: Game) {
        // Discard these bytes. The accepted commit still saves the current
        // live state synchronously, preserving durable reward/clock ordering.
        _ = try? game.encoded()
    }

    private func finishBeginningPuzzle() {
        #if DEBUG && targetEnvironment(simulator)
        applyPendingQAMarker()
        #endif
        isTrackingAchievementPuzzle = savesProgress
        usedClueThisPuzzle = false
        madeWrongPlacementThisPuzzle = false
        if savesProgress, let level = puzzle?.level {
            report(level, to: .highestLevelReached)
            PlayerProfileStore.shared.recordReachedLevel(level)
        }
        if savesProgress, isTeachingFirstRun { PlayerProfileStore.shared.startFirstRunTutorial() }
        refreshHandCards(replacing: true)
        startClock()
        selectedHandIndex = nil
        selectedSquare = nil
        lastOutcome = nil
        lastClipping = nil
        page = .puzzle
        presentBossChanges(from: BossFeedbackSnapshot(nil))
    }

    /// An animated coupon commits only if the exact offer is still on this
    /// page. The game revision changes after a skip, purchase, restore or deal.
    struct ClippingClaim: Equatable {
        fileprivate let ownerID: UUID
        fileprivate let revision: UInt64
        fileprivate let clipping: Clipping
    }
    @ObservationIgnored private let clippingOwnerID = UUID()

    var currentClippingClaim: ClippingClaim? {
        guard page == .briefing, !wantsMenu, game.puzzle == nil, game.shop == nil,
              game.run.outcome == nil, let clipping = run.currentClipping else { return nil }
        return ClippingClaim(ownerID: clippingOwnerID, revision: puzzlePreparationRevision, clipping: clipping)
    }

    @discardableResult
    func takeClipping(ifCurrent claim: ClippingClaim) -> Bool {
        guard currentClippingClaim == claim else { return false }
        skipCurrentPuzzle()
        return puzzlePreparationRevision != claim.revision
    }

    func skipCurrentPuzzle() {
        rewardedRescue.invalidate()
        do {
            lastClipping = try game.skipPuzzle()
            if savesProgress { PlayerProfileStore.shared.recordSkipsUsed(game.run.skipsUsed) }
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
            if animatesHandArrival { GameAudio.shared.play(.menuTap) }
            if let kind, savesProgress {
                PlayerProfileStore.shared.recordPurchase(kind: kind,
                                                         bookmarkCount: game.run.bookmarks.count)
            }
        }
        catch { message = describe(error) }
    }

    func reroll() {
        do {
            try game.reroll()
            if animatesHandArrival { Haptics.pageTurn() }
        }
        catch { message = describe(error) }
    }

    /// §10 — sell a Bookmark or Buff for its deterministic partial refund.
    func sell(kind: ItemKind, index: Int) {
        let boughtInShopVisitID: Int?
        switch kind {
        case .bookmark: boughtInShopVisitID = game.run.bookmarks.indices.contains(index)
                ? game.run.bookmarks[index].boughtInShopVisitID : nil
        case .buff: boughtInShopVisitID = game.run.buffs.indices.contains(index)
                ? game.run.buffs[index].boughtInShopVisitID : nil
        case .marker, .subscription: boughtInShopVisitID = nil
        }
        let currentShopVisitID = game.run.shop?.visitID
        do {
            let coins = try game.sell(kind: kind, index: index)
            if savesProgress {
                PlayerProfileStore.shared.recordSale(boughtInShopVisitID: boughtInShopVisitID,
                                                     currentShopVisitID: currentShopVisitID)
            }
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
        guard !wantsMenu else { return }
        rewardedRescue.invalidate()
        cancelPuzzlePreparation()
        // Retire this owner before the disappearing puzzle pauses its clock.
        // That late lifecycle callback must not re-create the cleared save or
        // overwrite a replacement Book. Keep the printed time for its exit.
        clockLastSample = nil
        wantsMenu = true
        if savesProgress { RunStore.clearRun() }
        savesProgress = false
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
        stopClock()
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
        case PlacementError.noClueDestination: return "No place for that number is available this Turn — Clue kept"
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
