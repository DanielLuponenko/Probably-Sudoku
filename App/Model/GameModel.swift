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
    /// The model acknowledges durable run and completion writes separately.
    /// Tests inject isolated storage without changing the player's files.
    struct Persistence {
        var save: (Game, Bool) -> Bool
        var recordCompletion: (Book, Obstacle) -> Bool
        var clear: () -> Bool
        var recordsPlayerProfile = true

        static var live: Self {
            Self(save: { RunStore.save($0, publishToCloud: $1) },
                 recordCompletion: { RunStore.recordBookCompleted($0, obstacle: $1) },
                 clear: { RunStore.clearRun() })
        }
    }
    @ObservationIgnored private var persistence = Persistence.live

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
    struct HandCard: Identifiable, Codable, Equatable {
        let id: UUID
        let digit: Digit
        /// Staggers only cards introduced by the current Hand reconciliation.
        let arrivalOrder: Int
    }

    enum HandArrangement: String, Codable {
        case dealt, ascending, descending, random
    }

    /// Presentation lives beside the saved rules. The canonical cards and
    /// permutation can be restored only when they still describe this Hand.
    struct HandPresentation: Codable, Equatable {
        let puzzleID: String
        let turn: Int
        let board: [Digit?]
        let cards: [HandCard]
        let order: [UUID]
        let arrangement: HandArrangement
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
        /// Aligned with digits; targets exact copies even after arrangement.
        var handCardIDs: [UUID] = []
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
    private(set) var presentedMultiplier: Double?
    private(set) var presentedCalculation: LiveScoreCalculation?
    var isPresentingScore: Bool { scorePerformance != nil }

    /// Current committed play updates immediately, independently of attribution
    /// beats. Banking retains its own complete receipt until its bank beat.
    var liveScoreCalculation: LiveScoreCalculation {
        guard let puzzle, puzzle.phase != .keepFilling else { return .empty }
        return presentedCalculation ?? LiveScoreCalculation(ledger: puzzle.pendingScoringLedger)
    }

    func presentScore(_ performance: ScorePerformance) {
        guard animatesHandArrival, !performance.beats.isEmpty else {
            finishScorePresentation()
            return
        }
        var performance = performance
        performance.hidesMarkerSources = performance.hidesMarkerSources || markersAreHidden
        effectActivation = nil
        scorePerformance = performance
        scoreBeat = performance.feedbackBeats.first
        presentedScore = performance.bankedFrom
        presentedQueue = performance.queuedFrom
        presentedMultiplier = performance.multiplierFrom
        presentedCalculation = performance.bankCalculation
    }

    func advanceScore(_ beat: ScorePerformance.Beat, performanceID: UUID) {
        guard scorePerformance?.id == performanceID else { return }
        if markersAreHidden, let source = beat.sourceID, Catalog.item(source)?.kind == .marker { return }
        scoreBeat = beat
        if let queuedBase = beat.queuedBase { presentedQueue = queuedBase }
        if let multiplier = beat.multiplier { presentedMultiplier = multiplier }
        if let bankedScore = beat.bankedScore { presentedScore = bankedScore }
        if scorePerformance?.bankCalculation != nil, beat.bankedScore != nil {
            presentedCalculation = .empty
        }
    }

    func finishScorePresentation(id: UUID? = nil) {
        guard id == nil || scorePerformance?.id == id else { return }
        scorePerformance = nil
        scoreBeat = nil
        presentedScore = nil
        presentedQueue = nil
        presentedMultiplier = nil
        presentedCalculation = nil
    }

    func bookmarkScoreLabel(_ id: String) -> String? {
        scoreBeat?.sourceID == id ? scoreBeat?.value : nil
    }

    func bookmarkScoreLabel(instanceID: UUID) -> String? {
        scoreBeat?.sourceInstanceID == instanceID.uuidString ? scoreBeat?.value : nil
    }

    func isBookmarkScoringActive(instanceID: UUID) -> Bool {
        scoreBeat?.sourceInstanceID == instanceID.uuidString
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
    private(set) var handPresentationOrder: [UUID] = []
    private(set) var handArrangement: HandArrangement = .dealt
    private static let handPresentationKey = "game.handPresentation.v1"
    /// A frozen model is the page already lifting away, not a fresh deal.
    private(set) var animatesHandArrival = true
    /// Presentation-only entrance identity. Restored/frozen pages begin
    /// settled; rebuilding a View never creates a new encounter event.
    private(set) var bossEntranceID: UUID?
    @ObservationIgnored private var consumedBossVisualEvents: Set<String> = []

    func consumeBossVisualEvent(_ key: String) -> Bool {
        consumedBossVisualEvents.insert(key).inserted
    }

    func hasConsumedBossVisualEvent(_ key: String) -> Bool {
        consumedBossVisualEvents.contains(key)
    }
    private(set) var page: BookPage = .briefing {
        didSet {
            if oldValue != page { invalidatePuzzlePreparation() }
        }
    }
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
    /// A Peek remains in its inventory slot until a legal hand-card hint is
    /// revealed. Merely closing its explanation is not a consumable action.
    private(set) var pendingPeekID: UUID?

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
        let createdAt: ContinuousClock.Instant

        init(amount: Int, createdAt: ContinuousClock.Instant = .now) {
            self.amount = amount
            self.createdAt = createdAt
        }

        var fadesAt: ContinuousClock.Instant { createdAt.advanced(by: .milliseconds(950)) }
        var expiresAt: ContinuousClock.Instant { createdAt.advanced(by: .milliseconds(1150)) }
        func isVisible(at instant: ContinuousClock.Instant = .now) -> Bool { instant < fadesAt }
    }
    private(set) var lastCoinCharge: CoinCharge?

    private func presentCoinCharge(_ amount: Int) {
        let charge = CoinCharge(amount: amount)
        lastCoinCharge = charge
        Task { @MainActor [weak self] in
            try? await ContinuousClock().sleep(until: charge.expiresAt)
            guard !Task.isCancelled else { return }
            self?.finishCoinCharge(id: charge.id)
        }
    }

    func finishCoinCharge(id: UUID) {
        guard lastCoinCharge?.id == id else { return }
        lastCoinCharge = nil
    }
    private(set) var lastPlacedSquare: Square?
    private(set) var lastPayout: RunState.Payout?
    /// A receipt for the consumable added by the most recent skip.
    private(set) var lastSkipReward: ItemDef?
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

        /// The briefing previews this exact prepared deal without committing it
        /// or advancing any of the live run's random streams.
        var puzzle: PuzzleState? { game.puzzle }
    }
    private struct PuzzlePreparation: Sendable {
        let revision: UInt64
        let requestID: UUID
        let task: Task<Result<Game, Error>, Never>
    }
    @ObservationIgnored private var puzzlePreparation: PuzzlePreparation?
    private var preparedPuzzle: PreparedPuzzle?
    struct PreparedShopExit: Sendable {
        fileprivate let revision: UInt64
        fileprivate let requestID: UUID
        fileprivate let game: Game
    }
    @ObservationIgnored private var shopExitPreparation: PuzzlePreparation?
    private var preparedShopExit: PreparedShopExit?

    init(seed: String = GameModel.randomSeed(),
         book: Book = .probably,
         obstacle: Obstacle = .none) {
        game = Game(seed: seed, book: book, obstacle: obstacle)
        armFirstRunTutorialIfEligible()
    }

    /// The normal start action saves the undealt Book before exposing its
    /// first offer. Merely constructing a preview/debug model is not a start.
    static func startingBook(seed: String = GameModel.randomSeed(),
                             book: Book = .probably, obstacle: Obstacle = .none,
                             saveInitial: (Game) -> Bool = { RunStore.save($0) }) -> GameModel? {
        let model = GameModel(seed: seed, book: book, obstacle: obstacle)
        guard saveInitial(model.gameForPersistence) else { return nil }
        return model
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
    init(resuming game: Game, savesProgress: Bool = true, persistence: Persistence = .live) {
        self.game = game
        self.savesProgress = savesProgress
        self.persistence = persistence
        let savedHand = savesProgress ? Self.loadHandPresentation() : nil
        if let puzzle = game.puzzle,
           puzzle.phase == .playing || puzzle.phase == .keepFilling {
            page = .puzzle
            refreshHandCards(replacing: true)
            if let savedHand { restoreHandPresentation(savedHand) }
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
        if persistence.recordsPlayerProfile {
            PlayerProfileStore.shared.recordCoinBalance(game.run.coins)
        }
        guard let outcome = game.run.outcome else {
            if !persistence.save(savedGame, true) { reportSaveFailure() }
            return
        }

        guard !didRecordTerminalOutcome else {
            if !persistence.save(savedGame, true) { reportSaveFailure() }
            return
        }

        switch outcome {
        case .bookCompleted:
            if persistence.recordCompletion(game.run.book, game.run.obstacle) {
                didRecordTerminalOutcome = true
                if persistence.recordsPlayerProfile {
                    PlayerProfileStore.shared.recordBookCompleted(volume: game.run.book.volume,
                                                                  obstacle: game.run.obstacle)
                    report(RunStore.booksCompleted, to: .booksCompleted)
                }
            } else {
                reportSaveFailure()
            }
        case .failed:
            didRecordTerminalOutcome = true
        }
        if !persistence.save(savedGame, true) { reportSaveFailure() }
    }

    private func reportSaveFailure() {
        message = "Couldn't save this Book yet. Keep it open and try again."
    }

    nonisolated static func randomSeed() -> String {
        // Gameplay randomness begins here; hand arrangement has its own
        // presentation-only randomness and never touches seeded streams.
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
        defer {
            reconcileHandPresentation()
            saveHandPresentation()
        }
        let prior = Dictionary(uniqueKeysWithValues: handCards.map { ($0.id, $0) })
        var nextArrivalOrder = 0
        handCards = (puzzle?.handCards ?? []).map { token in
            if let existing = prior[token.id], existing.digit == token.digit { return existing }
            defer { nextArrivalOrder += 1 }
            return HandCard(id: token.id, digit: token.digit, arrivalOrder: nextArrivalOrder)
        }
    }

    /// Never sort `handCards`: its indices belong to the Engine. All controls
    /// translate a displayed UUID back to that current canonical array.
    var displayedHandCards: [HandCard] {
        let cards = Dictionary(uniqueKeysWithValues: handCards.map { ($0.id, $0) })
        return handPresentationOrder.compactMap { cards[$0] }
    }

    func canonicalHandIndex(for cardID: UUID) -> Int? {
        handCards.firstIndex { $0.id == cardID }
    }

    func tapHandCard(_ cardID: UUID) {
        guard let index = canonicalHandIndex(for: cardID) else { return }
        tapHand(index)
    }

    func arrangeHand(_ arrangement: HandArrangement) {
        guard acceptsPuzzleInput else { return }
        handArrangement = arrangement
        reconcileHandPresentation()
        if arrangement == .random {
            // System randomness here is presentation-only. No seeded game,
            // board, Pool, Shop, or boss stream is read or advanced.
            handPresentationOrder.shuffle()
        }
        saveHandPresentation()
    }

    private func reconcileHandPresentation() {
        let cards = Dictionary(uniqueKeysWithValues: handCards.map { ($0.id, $0) })
        var seen = Set<UUID>()
        handPresentationOrder = (handPresentationOrder + handCards.map(\.id)).filter {
            cards[$0] != nil && seen.insert($0).inserted
        }
        switch handArrangement {
        case .dealt:
            handPresentationOrder = handCards.map(\.id)
        case .ascending, .descending:
            // Equal digits keep their prior presentation order. Sorting or a
            // Jade return must not exchange two otherwise identical cards.
            let ranks = Dictionary(uniqueKeysWithValues:
                handPresentationOrder.enumerated().map { ($0.element, $0.offset) })
            handPresentationOrder.sort { lhs, rhs in
                guard let a = cards[lhs], let b = cards[rhs] else { return false }
                if a.digit == b.digit { return ranks[lhs, default: 0] < ranks[rhs, default: 0] }
                return handArrangement == .ascending ? a.digit < b.digit : b.digit < a.digit
            }
        case .random:
            // Keep the existing permutation and append draws. A refresh is
            // never an implicit request for another shuffle.
            break
        }
    }

    private var handPresentationPuzzleID: String {
        "\(run.seed):\(run.book.rawValue):\(run.obstacle.rawValue):\(run.level):\(run.slot.rawValue)"
    }

    var handPresentation: HandPresentation? {
        guard let puzzle else { return nil }
        return HandPresentation(puzzleID: handPresentationPuzzleID, turn: puzzle.turnNumber,
                                board: puzzle.board.placed,
                                cards: handCards, order: handPresentationOrder,
                                arrangement: handArrangement)
    }

    @discardableResult
    func restoreHandPresentation(_ saved: HandPresentation) -> Bool {
        guard let puzzle, saved.puzzleID == handPresentationPuzzleID,
              saved.turn == puzzle.turnNumber, saved.board == puzzle.board.placed,
              saved.cards.map(\.digit) == hand,
              Set(saved.cards.map(\.id)).count == saved.cards.count,
              Set(saved.order) == Set(saved.cards.map(\.id)),
              saved.order.count == saved.cards.count else { return false }
        // Older releases saved presentation-only identities. Translate that
        // order once onto the engine's persisted token identities.
        let tokens = puzzle.handCards
        let migrated = Dictionary(uniqueKeysWithValues: zip(saved.cards.map(\.id), tokens.map(\.id)))
        handCards = zip(tokens, saved.cards).map {
            HandCard(id: $0.0.id, digit: $0.0.digit, arrivalOrder: $0.1.arrivalOrder)
        }
        handPresentationOrder = saved.order.compactMap { migrated[$0] }
        handArrangement = saved.arrangement
        reconcileHandPresentation()
        saveHandPresentation()
        return true
    }

    private func saveHandPresentation() {
        guard savesProgress, !wantsMenu, let handPresentation,
              let data = try? JSONEncoder().encode(handPresentation) else { return }
        UserDefaults.standard.set(data, forKey: Self.handPresentationKey)
    }

    private static func loadHandPresentation() -> HandPresentation? {
        guard let data = UserDefaults.standard.data(forKey: handPresentationKey) else { return nil }
        return try? JSONDecoder().decode(HandPresentation.self, from: data)
    }

    private func presentReturn(kind: NumberReturn.Kind, digits: [Digit] = [],
                               square: Square? = nil, fouledSquares: [Square] = [],
                               penalty: Int? = nil, handCardIDs: [UUID] = []) {
        let event = NumberReturn(kind: kind, digits: digits, square: square,
                                 fouledSquares: fouledSquares, penalty: penalty,
                                 handCardIDs: handCardIDs)
        numberReturns.append(event)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(850))
            guard !Task.isCancelled else { return }
            self?.numberReturns.removeAll { $0.id == event.id }
        }
    }

    /// Bosses change state at the start of a Turn. Compare the two public
    /// rule-state snapshots rather than duplicating any selection logic here.
    private func presentBossChanges(from previous: BossFeedbackSnapshot) {
        let current = BossFeedbackSnapshot(puzzle)
        let newlyBlocked = current.blocked.subtracting(previous.blocked)
        let blockedCards = handCards.filter { newlyBlocked.contains($0.digit) }
        if !blockedCards.isEmpty {
            presentReturn(kind: .barred, digits: blockedCards.map(\.digit),
                          handCardIDs: blockedCards.map(\.id))
        }

        let newlyFouled = current.fouled.subtracting(previous.fouled).sorted {
            $0.index < $1.index
        }
        if !newlyFouled.isEmpty {
            presentReturn(kind: .fouled, fouledSquares: newlyFouled)
        }
    }

    private func presentAutomaticBank(after previousLedger: ScoreLedger?, previousScore: Int) {
        guard let ledger = puzzle?.lastScoringLedger, ledger != previousLedger,
              ledger.operations.contains(where: { $0.kind == .bank }) else { return }
        presentScore(.banking(ledger, previousScore: previousScore, finalScore: puzzle?.score ?? previousScore,
                              hidesMarkerSources: markersAreHidden))
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

    private(set) var isClockRunning = false

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
        isClockRunning = false
        updateClockDisplay()
    }

    func stopClock() {
        guard animatesHandArrival else { return }
        clockLastSample = nil
        isClockRunning = false
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
            isClockRunning = true
        } else if clockLastSample != nil {
            advanceClock(to: now)
            clockLastSample = nil
            isClockRunning = false
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
        isClockRunning = false
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
        if !persistence.save(gameForPersistence, publishToCloud) { reportSaveFailure() }
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

    /// Essential teaching fits beside the arrangement control. Decorative
    /// marginalia does not reserve space on the active gameplay surface.
    var firstRunGuidance: String? {
        guard isTeachingFirstRun, let puzzle, acceptsPuzzleInput,
              let index = FirstRunTutorial.lineIndex(book: run.book, level: puzzle.level,
                                                     slot: puzzle.slot, turn: puzzle.turnNumber) else { return nil }
        return MarginNote.firstRunTeachingLine(at: index)?.text
    }

    private func armFirstRunTutorialIfEligible() {
        isTeachingFirstRun = game.run.book == .probably
            && PlayerProfileStore.shared.needsFirstRunTutorial
    }

    /// Squares carrying a Marker, unless The Fog is hiding them (§13).
    var visibleMarkers: [Square: OwnedMarker] {
        MarkerInspectionInfo.visibleMarkers(in: run)
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
    func isBarred(_ square: Square) -> Bool {
        guard let puzzle else { return false }
        return puzzle.isBarred(square) && !BuffRuntime.passageAllows(square, puzzle: puzzle)
    }

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
        guard isReadingLitmus, let puzzle else { return nil }
        return BuffRuntime.litmusReading(at: square, puzzle: puzzle)
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
        pendingPeekID = nil
    }

    /// Neutral page areas let a player put the pencil down without changing a
    /// square, spending a Buff, or opening any Book chrome.
    func dismissSelection() {
        if isChoosingClue { cancelClueTargeting() }
        else { clearSelection() }
    }

    /// Used by unrelated overlays, drags and backgrounding. The Peek panel's
    /// own dismissal intentionally does not call this handoff cancellation.
    func cancelClueTargeting() {
        guard isChoosingClue else { return }
        let wasPeek = pendingPeekID != nil
        clearSelection()
        message = wasPeek ? "Peek kept" : "Clue kept"
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
        !wantsMenu && run.outcome == nil && run.pendingItemDecisions.isEmpty
            && (puzzle?.phase == .playing || puzzle?.phase == .keepFilling)
    }

    func tapHand(_ index: Int) {
        guard acceptsPuzzleInput else { return }
        guard hand.indices.contains(index) else { return }
        if isChoosingClue {
            selectedHandIndex = index
            selectedSquare = nil
            revealClueForSelectedCard()
            return
        }
        if isBlocked(handIndex: index) {
            message = handRestrictionDescription(index)
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
    }

    /// Obstacle III bars one number a Turn. It stays in the Hand — it can be
    /// seen and Tossed — but it cannot go on the board.
    func isBlocked(handIndex: Int) -> Bool {
        guard let puzzle else { return false }
        return puzzle.isBlocked(handIndex: handIndex) && !BuffRuntime.releaseAllows(handIndex: handIndex, puzzle: puzzle)
    }

    func handRestrictionDescription(_ index: Int) -> String? {
        guard let p = puzzle, p.hand.indices.contains(index), isBlocked(handIndex: index) else { return nil }
        if p.bossState.sealedIDs.contains(p.handCards[index].id) { return "Sealed by The Return Slip until next Turn. Cannot be played or Tossed." }
        if p.bossTurn?.blockedHandIndices.contains(index) == true { return "Barred by Handy Dandy. Cannot be played or Tossed this Turn." }
        if p.isIndependentlyBlocked(handIndex: index) { return "This number is blocked this Turn. It can still be Tossed." }
        switch p.boss {
        case .galleyQueue: return "Play one of the two oldest available cards first. This card can still be Tossed."
        case .bookends: return "Play the lowest or highest available number. This card can still be Tossed."
        case .reprintBan: return "Use an unused number before repeating this one. This card can still be Tossed."
        case .collator: return "Waiting for two correct fills or an empty first packet. This card can still be Tossed."
        default: return "This card is blocked."
        }
    }

    func tapSquare(_ square: Square) {
        guard acceptsPuzzleInput, let puzzle else { return }
        guard !isBarred(square) else {
            message = "That square is barred this Turn"
            return
        }
        // An occupied square is for reading its digit, never placing the
        // previously held card. Preserve the hand only for blank-square play.
        if !puzzle.board.isBlank(square) { dropHandSelection() }
        isChoosingClue = false
        pendingPeekID = nil
        selectedSquare = square
        highlightSource = .square

        guard puzzle.board.isBlank(square), let index = selectedHandIndex else { return }
        place(handIndex: index, at: square)
    }

    func place(handIndex: Int, at square: Square) {
        // A delayed drag/tap can arrive after the results page has replaced
        // the board. The engine rejects it, but the presentation boundary
        // must also avoid turning that expected rejection into a new message.
        guard acceptsPuzzleInput else { return }
        guard hand.indices.contains(handIndex) else { return }
        let digit = hand[handIndex]
        let cardID = handCards[handIndex].id
        let wasKeepingFilling = puzzle?.phase == .keepFilling
        let coinCost = puzzle?.boss?.coinsPerPlacement ?? 0
        let bossBefore = BossFeedbackSnapshot(puzzle)
        let previousScore = puzzle?.score ?? 0
        let previousQueue = puzzle?.pendingBase ?? 0
        let previousLedger = puzzle?.lastScoringLedger
        do {
            let outcome = try game.place(handIndex: handIndex, at: square)
            if outcome.pendingDecision { return }
            if coinCost > 0 { presentCoinCharge(coinCost) }
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
                                        previousQueue: previousQueue,
                                        pendingLedger: puzzle?.pendingScoringLedger,
                                        committedLedger: puzzle?.lastScoringLedger,
                                        hidesMarkerSources: markersAreHidden))
            } else {
                finishScorePresentation()
                presentAutomaticBank(after: previousLedger, previousScore: previousScore)
            }
            markCleared(outcome, at: square)
            // A placement consumes the card and changes the square, so neither
            // side of the former selection still describes an available action.
            clearSelection()
            message = outcome.correct ? nil : (outcome.penalty == 0
                ? "Wrong number — penalty waived"
                : "Wrong number — −\(outcome.penalty) queued Points first")
            if !outcome.correct {
                presentReturn(kind: outcome.returnedToHand ? .hand : .pool,
                              digits: [digit], square: square, penalty: outcome.penalty,
                              handCardIDs: [cardID])
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
        Task { @MainActor [weak self] in
            // Long enough to read the receipt during normal play, but short
            // enough that it never becomes persistent board chrome. The
            // receipt's reading time must not keep a departed Book alive.
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, let self, self.effectActivation?.id == activation.id else { return }
            self.effectActivation = nil
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
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(1100))
            guard !Task.isCancelled, let self, self.clearTicket == ticket else { return }
            self.cleared = []
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
        let cardID = handCards[index].id
        let previousLedger = puzzle?.lastScoringLedger
        let previousScore = puzzle?.score ?? 0
        let bossBefore = BossFeedbackSnapshot(puzzle)
        do {
            _ = try game.toss(handIndex: index)
            if animatesHandArrival {
                GameAudio.shared.play(.toss)
                Haptics.tossed()
            }
            refreshHandCards(consuming: index)
            message = nil
            presentReturn(kind: .pool, digits: [digit], handCardIDs: [cardID])
            presentAutomaticBank(after: previousLedger, previousScore: previousScore)
            presentBossChanges(from: bossBefore)
        } catch {
            message = describe(error)
        }
        clearSelection()
    }

    var canToss: Bool {
        guard acceptsPuzzleInput, !handCards.isEmpty,
              (puzzle?.tossesRemaining ?? 0) > 0 else { return false }
        if let selectedHandIndex, let puzzle, puzzle.isTossBlocked(handIndex: selectedHandIndex),
           !BuffRuntime.releaseAllows(handIndex: selectedHandIndex, puzzle: puzzle) {
            return false
        }
        return true
    }

    var tossButtonTitle: String {
        "Toss"
    }

    var tossButtonSubtitle: String {
        "\(puzzle?.tossesRemaining ?? 0) left this puzzle"
    }

    func useClue(at square: Square) {
        guard acceptsPuzzleInput else { return }
        let wasKeepingFilling = puzzle?.phase == .keepFilling
        let previousLedger = puzzle?.lastScoringLedger
        let previousScore = puzzle?.score ?? 0
        let bossBefore = BossFeedbackSnapshot(puzzle)
        // The legacy direct-square action takes the solution number from the
        // Pool first, otherwise the first matching Hand slot. Record only that
        // identity decision; no Pool counts are exposed in the presentation.
        let consumedIndex = puzzle.flatMap { puzzle -> Int? in
            let digit = puzzle.board.correctDigit(at: square)
            return puzzle.poolCount(of: digit) == 0 ? puzzle.hand.firstIndex(of: digit) : nil
        }
        do {
            let outcome = try game.useClue(at: square)
            finishScorePresentation()
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
            presentAutomaticBank(after: previousLedger, previousScore: previousScore)
            presentBossChanges(from: bossBefore)
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
        } else if puzzle?.canUseClue == true {
            clearSelection()
            isChoosingClue = true
            message = "Choose a number from your hand for the Clue"
        } else {
            message = puzzle?.boss?.disablesClues == true
                ? "The Paywall has disabled Clues" : "No Clues available"
        }
    }

    private func revealClueForSelectedCard() {
        guard let index = selectedHandIndex, handCards.indices.contains(index),
              let currentIndex = canonicalHandIndex(for: handCards[index].id) else { return }
        do {
            var next = game
            var spentPeek = false
            let previouslyRevealed = puzzle?.clueReveals ?? []
            if let pendingPeekID {
                guard let buffIndex = next.run.buffs.firstIndex(where: { $0.id == pendingPeekID }),
                      next.run.buffs[buffIndex].defID == Buffs.peek else {
                    clearSelection()
                    message = "That Peek is no longer in your inventory"
                    return
                }
                // A destination already paid for is free to inspect. Keep the
                // selected Peek instead of converting it into a spare charge.
                let alreadyRevealed = puzzle.map { puzzle in
                    previouslyRevealed.contains {
                        puzzle.board.isBlank($0) && !puzzle.isBarred($0)
                            && puzzle.board.correctDigit(at: $0) == hand[currentIndex]
                    }
                } ?? false
                if !alreadyRevealed {
                    guard try next.useBuff(at: buffIndex) else { return }
                    spentPeek = true
                }
            }
            let square = try next.revealClue(handIndex: currentIndex)
            // Consumable, charge and revealed square enter the one saved Game
            // snapshot together. Invalid cards leave the original untouched.
            if spentPeek || !previouslyRevealed.contains(square) { game = next }
            if spentPeek, savesProgress { PlayerProfileStore.shared.recordBuffUsed() }
            if isTrackingAchievementPuzzle { usedClueThisPuzzle = true }
            isChoosingClue = false
            pendingPeekID = nil
            selectedSquare = nil
            highlightSource = .hand
            message = "Clue: place \(hand[currentIndex].rawValue) in row \(square.row + 1), column \(square.col + 1)"
        } catch {
            // Keep targeting armed so another card can be chosen. Neither a
            // charge nor the selected Peek has been committed on this path.
            dropHandSelection()
            message = describe(error)
        }
    }

    func isClueDestination(_ square: Square) -> Bool {
        guard let puzzle, puzzle.boss?.disablesClues != true,
              let digit = selectedDigit,
              puzzle.clueReveals.contains(square), puzzle.board.isBlank(square),
              !puzzle.isBarred(square),
              let index = selectedHandIndex, !isBlocked(handIndex: index) else { return false }
        return puzzle.board.correctDigit(at: square) == digit
    }

    var clueHandInstruction: String? {
        if isChoosingClue {
            return pendingPeekID == nil ? "Clue: choose a number" : "Peek: choose a number"
        }
        guard let digit = selectedDigit,
              let square = puzzle?.board.blanks.first(where: { isClueDestination($0) }) else { return nil }
        return "Place \(digit.rawValue) in row \(square.row + 1), column \(square.col + 1)"
    }

    @discardableResult
    func useBuff(at index: Int, digit: Digit? = nil) -> Bool {
        guard !wantsMenu, run.outcome == nil else { return false }
        finishScorePresentation()
        let consumedBuff = game.run.buffs.indices.contains(index) ? game.run.buffs[index] : nil
        let priorLedger = puzzle?.pendingScoringLedger
        do {
            let peeks = game.run.buffs.indices.contains(index)
                && game.run.buffs[index].defID == Buffs.peek
            if peeks {
                // Validate phase/Buffborger/Paywall on a disposable copy. The
                // real inventory remains unchanged while the player chooses.
                var validation = game
                guard try validation.useBuff(at: index) else { return false }
                let id = game.run.buffs[index].id
                clearSelection()
                pendingPeekID = id
                isChoosingClue = true
                message = "Peek: choose a number from your hand"
                return true
            }
            let redrawsHand = game.run.buffs.indices.contains(index)
                && game.run.buffs[index].defID == Buffs.redraw
            let redrawn = redrawsHand ? hand : []
            let redrawnIDs = redrawsHand ? handCards.map(\.id) : []
            guard let consumedBuff else { return false }
            let use: BuffUseOutcome
            if let digit {
                guard try game.useBuff(at: index, digit: digit) else { return false }
                var direct = BuffUseOutcome(); direct.consumedID = consumedBuff.id; use = direct
            } else {
                use = try game.beginBuff(id: consumedBuff.id)
            }
            if savesProgress, use.consumedID != nil { PlayerProfileStore.shared.recordBuffUsed() }
            if use.requiresDecision { return true }
            if [Buffs.inventoryCount, Buffs.proofSheet, Buffs.foldTest].contains(consumedBuff.defID) { requestedCatalogueReading = UUID() }
            if animatesHandArrival { GameAudio.shared.play(.paperTurn) }
            presentScore(.buffActivation(consumedBuff, formerSlot: index,
                                         before: priorLedger, after: puzzle?.pendingScoringLedger,
                                         hidesMarkerSources: markersAreHidden))
            refreshHandCards(replacing: redrawsHand)
            if !redrawn.isEmpty {
                presentReturn(kind: .redraw, digits: redrawn, handCardIDs: redrawnIDs)
            }
            // Redraw and Lucky Dip both reshape the Hand under the selection.
            dropHandSelection()
            return true
        } catch {
            message = describe(error)
            return false
        }
    }

    var requestedCatalogueReading: UUID?
    func dismissCatalogueReading() { requestedCatalogueReading = nil }

    var pendingItemDecision: ItemDecision? { run.pendingItemDecisions.first }
    var buffCapacity: Int { BookmarkMechanics.capacity(run: run) }
    func visibleDigit(at square: Square) -> Digit? { puzzle?.board[square] }

    @discardableResult
    func resolveItemDecision(id: UUID, selected: [String]?) -> Bool {
        guard !wantsMenu, run.outcome == nil else { return false }
        let before = run
        let previousBuffs = Set(before.buffs.map(\.id))
        let choiceSource = before.pendingItemDecisions.first?.sourceID
        let selectedCard = selectedHandIndex.flatMap { handCards.indices.contains($0) ? handCards[$0].id : nil }
        do {
            guard try game.resolveItemDecision(id: id, selected: selected) else { return false }
            if savesProgress {
                for sale in Self.capacitySaleReceipts(before: before, after: run, decisionID: id, selected: selected) {
                    PlayerProfileStore.shared.recordSale(boughtInShopVisitID: sale.boughtInShopVisitID,
                                                         currentShopVisitID: sale.currentShopVisitID)
                }
            }
            refreshHandCards()
            if let selectedCard { selectedHandIndex = handCards.firstIndex(where: { $0.id == selectedCard }) }
            if savesProgress, choiceSource?.hasPrefix("bf_") == true, !previousBuffs.subtracting(Set(run.buffs.map(\.id))).isEmpty {
                PlayerProfileStore.shared.recordBuffUsed()
            }
            if selected != nil, run.pendingItemDecisions.isEmpty,
               let choiceSource, [Buffs.inventoryCount, Buffs.proofSheet, Buffs.foldTest].contains(choiceSource),
               !previousBuffs.subtracting(Set(run.buffs.map(\.id))).isEmpty { requestedCatalogueReading = UUID() }
            if animatesHandArrival, selected != nil { Haptics.pageTurn() }
            presentAutomaticBank(after: before.puzzle?.lastScoringLedger, previousScore: before.puzzle?.score ?? 0)
            presentBossChanges(from: BossFeedbackSnapshot(before.puzzle))
            return true
        } catch {
            message = describe(error)
            return false
        }
    }

    struct CapacitySaleReceipt: Equatable {
        let kind: ItemKind
        let instanceID: UUID
        let boughtInShopVisitID: Int?
        let currentShopVisitID: Int?
    }

    /// The combined Pocket Insert sale removes two exact instances. Capture
    /// their original purchase provenance only after the engine commits both;
    /// a cancellation, failed resolution or replay cannot produce receipts.
    static func capacitySaleReceipts(before: RunState, after: RunState,
                                     decisionID: UUID, selected: [String]?) -> [CapacitySaleReceipt] {
        guard let decision = before.pendingItemDecisions.first,
              decision.id == decisionID, decision.kind == "bookmark.capacitySale",
              let selected, selected.count == 1, decision.accepts(selected),
              let buffID = UUID(uuidString: selected[0]),
              let buff = before.buffs.first(where: { $0.id == buffID }),
              let bookmark = before.bookmarks.first(where: { $0.id == decision.sourceInstanceID }),
              bookmark.defID == Bookmarks.pocketInsert,
              !after.pendingItemDecisions.contains(where: { $0.id == decisionID }),
              !after.buffs.contains(where: { $0.id == buff.id }),
              !after.bookmarks.contains(where: { $0.id == bookmark.id }) else { return [] }
        let visit = before.shop?.visitID
        return [
            CapacitySaleReceipt(kind: .buff, instanceID: buff.id,
                                boughtInShopVisitID: buff.boughtInShopVisitID, currentShopVisitID: visit),
            CapacitySaleReceipt(kind: .bookmark, instanceID: bookmark.id,
                                boughtInShopVisitID: bookmark.boughtInShopVisitID, currentShopVisitID: visit)
        ]
    }

    /// A choice belongs to the exact puzzle and turn rendered by its control.
    /// Delayed taps from a previous page cannot sign a new turn's contract.
    var bossChoiceContext: String? {
        guard let puzzle, puzzle.phase == .playing else { return nil }
        return "\(run.seed):\(run.book.rawValue):\(puzzle.level):\(puzzle.slot.rawValue):\(puzzle.turnNumber)"
    }

    func pledgeBossCard(_ cardID: UUID, context: String) {
        guard acceptsPuzzleInput, context == bossChoiceContext,
              BossEncounterRules.canPledge(cardID: cardID, run: run) else { return }
        finishScorePresentation()
        guard game.pledgeBossCard(cardID: cardID) else { return }
        refreshHandCards()
        clearSelection()
        if animatesHandArrival {
            GameAudio.shared.play(.menuTap)
            Haptics.lift()
        }
    }

    func chooseBossEdition(_ edition: Int, context: String) {
        guard acceptsPuzzleInput, context == bossChoiceContext,
              puzzle?.bossState.encounter.selectedEdition != edition,
              BossEncounterRules.canChooseEdition(run: run) else { return }
        finishScorePresentation()
        guard game.chooseBossEdition(edition) else { return }
        if animatesHandArrival { GameAudio.shared.play(.menuTap) }
    }

    func endTurn() {
        guard acceptsPuzzleInput else { return }
        let bossBefore = BossFeedbackSnapshot(puzzle)
        let previousScore = puzzle?.score ?? 0
        let rebindingCards = puzzle?.boss == .rebinder ? handCards : []
        do {
            let result = try game.endTurn()
            presentScore(.banking(result, previousScore: previousScore, finalScore: puzzle?.score ?? 0,
                                  hidesMarkerSources: markersAreHidden))
            refreshHandCards()
            if !rebindingCards.isEmpty {
                presentReturn(kind: .redraw, digits: rebindingCards.map(\.digit),
                              handCardIDs: rebindingCards.map(\.id))
            }
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
        guard !wantsMenu else { return }
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
        guard !wantsMenu, run.outcome == nil,
              puzzle?.phase == .won || puzzle?.phase == .keepFilling else { return }
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
        guard !wantsMenu, run.outcome == nil, puzzle?.canKeepFilling == true else { return }
        do {
            try game.keepFilling()
            page = .puzzle
        } catch {
            message = describe(error)
        }
    }

    /// Results → shop, the first of the two page turns between Puzzles.
    func openShop() {
        // A duplicate or outgoing callback must not replace paid stock, or
        // discard a puzzle whose score has not been cashed out.
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty,
              puzzle?.phase == .cashedOut, shop == nil else { return }
        game.openShop()
        // The final cash-out completes the Book, so the engine intentionally
        // creates no Shop. Keep its final board and results page in place.
        page = game.run.outcome == nil && game.shop != nil ? .shop : .results
    }

    /// Shop → the next puzzle, the second page turn.
    func continueToNextPuzzle() {
        // In Reduce Motion this callback can run twice before SwiftUI removes
        // the old button. The saved Shop is the permission to advance once.
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty,
              shop != nil, puzzle == nil else { return }
        rewardedRescue.invalidate()
        let reservedBuff = run.buffState.reservationIntent?.sourceBuff
        guard game.advance() else {
            isTrackingAchievementPuzzle = false
            page = .results
            return
        }
        finishShopExit(reservedBuff: reservedBuff)
    }

    /// Boss eligibility may inspect several future boards. Prepare on a copy
    /// while the Shop remains usable; accepting commits only this revision.
    func prepareShopExit(
        using advance: @escaping @Sendable (Game) throws -> Game = { source in
            var next = source
            _ = next.advance()
            return next
        }
    ) async -> PreparedShopExit? {
        guard canPrepareShopExit, !Task.isCancelled else { return nil }
        if let ready = preparedShopExit, ready.revision == puzzlePreparationRevision { return ready }
        let work: PuzzlePreparation
        if let current = shopExitPreparation, current.revision == puzzlePreparationRevision,
           !current.task.isCancelled {
            work = current
        } else {
            let source = game
            let task = Task.detached(priority: .userInitiated) {
                Result<Game, Error> {
                    try Task.checkCancellation()
                    let next = try advance(source)
                    try Task.checkCancellation()
                    Self.warmPersistenceEncoding(next)
                    return next
                }
            }
            work = PuzzlePreparation(revision: puzzlePreparationRevision, requestID: UUID(), task: task)
            shopExitPreparation = work
        }
        let result = await work.task.value
        guard !Task.isCancelled, !work.task.isCancelled, canPrepareShopExit,
              work.revision == puzzlePreparationRevision,
              shopExitPreparation?.requestID == work.requestID else { return nil }
        guard case .success(let next) = result else { return nil }
        let ready = PreparedShopExit(revision: work.revision, requestID: work.requestID, game: next)
        preparedShopExit = ready
        return ready
    }

    @discardableResult
    func leavePreparedShop(_ ready: PreparedShopExit) -> Bool {
        guard canPrepareShopExit, ready.revision == puzzlePreparationRevision,
              preparedShopExit?.requestID == ready.requestID else { return false }
        let reservedBuff = run.buffState.reservationIntent?.sourceBuff
        rewardedRescue.invalidate()
        game = ready.game
        finishShopExit(reservedBuff: reservedBuff)
        return true
    }

    func cancelShopExitPreparation() {
        shopExitPreparation?.task.cancel()
        shopExitPreparation = nil
        preparedShopExit = nil
    }

    private var canPrepareShopExit: Bool {
        animatesHandArrival && !wantsMenu && page == .shop && run.outcome == nil
            && run.pendingItemDecisions.isEmpty && shop != nil && puzzle == nil
    }

    private func finishShopExit(reservedBuff: UUID?) {
        if let reservedBuff, savesProgress, !run.buffs.contains(where: { $0.id == reservedBuff }) {
            PlayerProfileStore.shared.recordBuffUsed()
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
        guard !wantsMenu, page == .briefing, run.outcome == nil, run.pendingItemDecisions.isEmpty,
              puzzle == nil, shop == nil else { return }
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
        cancelShopExitPreparation()
    }

    var hasPreparedPuzzle: Bool {
        canPreparePuzzle && preparedPuzzle?.revision == puzzlePreparationRevision
    }

    var preparedPuzzlePreview: PuzzleState? {
        guard page == .briefing, preparedPuzzle?.revision == puzzlePreparationRevision else { return nil }
        return preparedPuzzle?.puzzle
    }

    private func invalidatePuzzlePreparation() {
        cancelPuzzlePreparation()
        puzzlePreparationRevision &+= 1
    }

    private var canPreparePuzzle: Bool {
        animatesHandArrival && !wantsMenu && page == .briefing
            && game.puzzle == nil && game.shop == nil && game.run.outcome == nil && run.pendingItemDecisions.isEmpty
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
        bossEntranceID = puzzle?.boss == nil ? nil : UUID()
        startClock()
        selectedHandIndex = nil
        selectedSquare = nil
        lastOutcome = nil
        lastSkipReward = nil
        page = .puzzle
        presentBossChanges(from: BossFeedbackSnapshot(nil))
    }

    /// An accepted offer belongs to this model and revision. Delayed UI work
    /// cannot claim it after navigation, inventory changes, or a prepared deal.
    struct SkipClaim: Equatable, Identifiable {
        fileprivate let ownerID: UUID
        fileprivate let revision: UInt64
        let offer: SkipOffer
        var id: UUID { offer.id }
    }
    @ObservationIgnored private let skipOwnerID = UUID()

    var currentSkipClaim: SkipClaim? {
        guard animatesHandArrival, page == .briefing, !wantsMenu,
              let offer = run.currentSkipOffer else { return nil }
        return SkipClaim(ownerID: skipOwnerID, revision: puzzlePreparationRevision, offer: offer)
    }

    @discardableResult
    func takeSkip(ifCurrent claim: SkipClaim, replacingBuffID: UUID? = nil) -> Bool {
        guard currentSkipClaim == claim else { return false }
        do {
            // Mutate a private copy, then assign once. Inventory, history and
            // progression reach game.didSet's atomic save as one snapshot.
            var accepted = game
            _ = try accepted.skipPuzzle(ifCurrent: claim.offer, replacingBuffID: replacingBuffID)
            game = accepted
            rewardedRescue.invalidate()
            lastSkipReward = claim.offer.buff
            if savesProgress { PlayerProfileStore.shared.recordSkipsUsed(game.run.skipsUsed) }
            isTrackingAchievementPuzzle = false
            selectedHandIndex = nil
            selectedSquare = nil
            lastOutcome = nil
            lastPayout = nil
            message = nil
            page = .briefing
            return true
        } catch {
            message = describe(error)
            return false
        }
    }

    /// Used by the simulator route; full inventory still requires a choice.
    @discardableResult
    func skipCurrentPuzzle() -> Bool {
        guard let claim = currentSkipClaim else { return false }
        return takeSkip(ifCurrent: claim)
    }

    func buy(slot: Int) {
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty, shop != nil else { return }
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
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty, shop != nil else { return }
        do {
            try game.reroll()
            if animatesHandArrival { Haptics.pageTurn() }
        }
        catch { message = describe(error) }
    }

    /// §10 — sell a Bookmark or Buff for its deterministic partial refund.
    func sell(kind: ItemKind, index: Int) {
        guard animatesHandArrival, !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty else { return }
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
            if kind == .bookmark, run.bookmarks.indices.contains(index),
               run.bookmarks[index].defID == Bookmarks.pocketInsert,
               run.buffs.count > 2 {
                try game.requestCapacitySale(bookmarkID: run.bookmarks[index].id)
                return
            }
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

    func cancelReservation() {
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty else { return }
        game.cancelReservation()
    }

    func canReopenRecycledChoice(bookmarkID: UUID) -> Bool {
        guard run.pendingItemDecisions.isEmpty else { return false }
        var preview = game
        preview.reopenRecycledChoice(bookmarkID: bookmarkID)
        return preview.run.pendingItemDecisions.contains { $0.sourceInstanceID == bookmarkID }
    }

    func reopenRecycledChoice(bookmarkID: UUID) {
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty else { return }
        game.reopenRecycledChoice(bookmarkID: bookmarkID)
    }

    func sellPrice(_ pricePaid: Int) -> Int { Shop.sellPrice(pricePaid) }

    func reorderBookmark(id: UUID, to index: Int) {
        guard animatesHandArrival, !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty else { return }
        var reordered = game
        guard reordered.reorderBookmark(id: id, to: index) else { return }
        game = reordered
        message = puzzle?.scoringOrderLocked == true
            ? "Bookmark order saved for next Turn"
            : "Bookmark scoring order updated"
    }

    /// The achievement page is a page in the current Book. Keep the origin so
    /// closing it returns to the exact puzzle, results, or shop page the
    /// player was reading rather than inventing a navigation reset.
    func openAchievements() {
        guard !wantsMenu, page != .achievements else { return }
        returnPageAfterAchievements = page
        page = .achievements
    }

    func closeAchievements() {
        guard !wantsMenu, page == .achievements else { return }
        page = returnPageAfterAchievements ?? .puzzle
        returnPageAfterAchievements = nil
    }

    @discardableResult
    func claimSquare(markerIndex: Int, square: Square) -> Bool {
        guard !wantsMenu, run.outcome == nil, run.pendingItemDecisions.isEmpty else { return false }
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
    @discardableResult
    func abandonRun(clearingSave: (() -> Bool)? = nil) -> Bool {
        guard !wantsMenu else { return true }
        // The completed receipt is the recovery source if its permanent
        // unlock could not be written. Keep it until that write succeeds.
        if savesProgress, run.outcome == .bookCompleted, !didRecordTerminalOutcome {
            persist()
            guard didRecordTerminalOutcome else {
                message = "Couldn't save this Book's unlock yet. Keep the final page and try again."
                return false
            }
        }
        // A failed durable deletion leaves this owner and its exact clock,
        // prepared deal and pending rescue intact so the player can retry.
        guard !savesProgress || (clearingSave ?? persistence.clear)() else {
            message = "Couldn't put this Book away. Your progress is still here. Please try again."
            return false
        }
        rewardedRescue.invalidate()
        cancelPuzzlePreparation()
        // Retire this owner before the disappearing puzzle pauses its clock.
        // That late lifecycle callback must not re-create the cleared save or
        // overwrite a replacement Book. Keep the printed time for its exit.
        clockLastSample = nil
        wantsMenu = true
        isClockRunning = false
        savesProgress = false
        return true
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

    func qaLoadScoringFixture(_ fixture: QAScoringFixture) {
        do {
            let prepared = try fixture.makeGame()
            // Preserve the user's stored Book; synthetic scoring fixtures are
            // never achievements, saves or replacements for that Book.
            savesProgress = false
            isTrackingAchievementPuzzle = false
            isTeachingFirstRun = false
            stopClock()
            pendingQAMarker = nil
            cancelPuzzlePreparation()
            finishScorePresentation()
            cancelClueTargeting()
            clearSelection()
            numberReturns = []
            lastOutcome = nil
            lastPayout = nil
            cleared = []
            lastPlacedSquare = nil
            game = prepared
            page = .puzzle
            refreshHandCards(replacing: true)
            message = "QA: \(fixture.title)"
        } catch {
            message = "Could not prepare the scoring fixture: \(error)"
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
        bossEntranceID = UUID()
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

    /// Repeatable screenshot states only. They stay live and playable but
    /// never save their synthetic score/loadout or award profile progress.
    func qaGameplayFixture(_ name: String) {
        let supported: Set<String> = ["fullinventory", "markers", "partialhand", "overflow",
                                      "large-score", "clue", "clue-destination", "litmus", "showcase"]
        guard supported.contains(name) else { return }
        savesProgress = false
        isTrackingAchievementPuzzle = false
        isTeachingFirstRun = false
        finishScorePresentation()
        clearSelection()
        cancelPuzzlePreparation()
        numberReturns = []
        lastOutcome = nil
        message = nil
        if puzzle == nil { beginPuzzle() }
        if name == "showcase" { qaSetBoss(.grayTheGarry) }

        var fixture = game.run
        guard var puzzle = fixture.puzzle else { return }
        fixture.outcome = nil
        fixture.shop = nil
        puzzle.phase = .playing

        if name == "fullinventory" || name == "showcase" {
            fixture.bookmarks = Bookmarks.all.prefix(ItemKind.bookmark.capacity).map {
                OwnedBookmark(defID: $0.id, boughtAtLevel: fixture.level, pricePaid: $0.listedPrice)
            }
            fixture.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 3),
                             OwnedBuff(defID: Buffs.freshInk, pricePaid: 4)]
        }
        if name == "markers" || name == "showcase" {
            let blanks = puzzle.board.blanks
            let markerIDs = ["mk_crimson", "mk_golden", "mk_azure", Markers.onyx, Markers.rose, Markers.jade]
            fixture.markers = markerIDs.enumerated().compactMap { index, id in
                guard blanks.count >= markerIDs.count else { return nil }
                let square = blanks[index * (blanks.count - 1) / (markerIDs.count - 1)]
                return OwnedMarker(defID: id, boughtAtLevel: fixture.level, pricePaid: 0, squares: [square])
            }
            if let given = Square.all.first(where: { puzzle.board.isGiven[$0.index] }) {
                fixture.markers.append(OwnedMarker(defID: Markers.ivory, boughtAtLevel: fixture.level,
                                                    pricePaid: 0, squares: [given]))
            }
        }
        if name == "partialhand" {
            while puzzle.hand.count > 3 { puzzle.pool.put(puzzle.hand.removeLast()) }
        }
        if name == "overflow" {
            puzzle.hand.append(contentsOf: puzzle.pool.draw(&fixture.streams.pool,
                                                            count: max(0, 12 - puzzle.hand.count)))
        }
        if name == "large-score" || name == "showcase" {
            puzzle.score = 122_541
            puzzle.target = 9_533_700
            puzzle.pendingBase = 495
            puzzle.pendingMult = 39.75
            fixture.coins = 957
        }
        if name == "clue" || name == "clue-destination" || name == "showcase" {
            puzzle.cluesRemaining = 3
        }
        if name == "litmus" {
            fixture.buffs = [OwnedBuff(defID: Buffs.litmus, pricePaid: 4)]
        }
        assert(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand) == nil)
        fixture.puzzle = puzzle
        game = Game(run: fixture)
        page = .puzzle
        refreshHandCards(replacing: true)
        startClock()

        if name == "clue" {
            chooseClue()
        } else if name == "clue-destination" || name == "showcase" {
            if let index = hand.indices.first(where: { index in
                !isBlocked(handIndex: index) && puzzle.board.blanks.contains {
                    !puzzle.isBarred($0) && puzzle.board.correctDigit(at: $0) == hand[index]
                }
            }) {
                chooseClue()
                tapHand(index)
            }
        } else if name == "litmus", let index = hand.indices.first(where: { !isBlocked(handIndex: $0) }) {
            _ = useBuff(at: 0, digit: hand[index])
            selectedHandIndex = index
        }
        // Keep screenshots clear of transient action receipts; the underlying
        // Clue/Litmus state remains the same state the real actions produced.
        message = nil
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
        case SkipError.inventoryFull: return "Choose a Buff to replace, or cancel"
        case SkipError.invalidReplacement: return "That Buff is no longer available — choose again"
        case SkipError.cannotSkip, SkipError.staleOffer: return "This skip offer is no longer available"
        case Shop.ShopError.notEnoughCoins: return "Not enough coins"
        case Shop.ShopError.slotsFull: return "No free slot"
        case BuffUseError.unavailable, BuffUseError.noLegalTarget: return "No eligible target right now — Buff kept"
        case BuffUseError.staleContext, BuffUseError.missingCopy: return "That Buff is no longer available"
        case BuffUseError.invalidChoice: return "Choose an available target"
        case BuffUseError.buffDisabled: return "This Boss has disabled Buffs"
        case BuffUseError.clueDisabled: return "The Paywall has disabled this effect"
        case BuffUseError.pendingChoice: return "Finish the current choice first"
        case BuffUseError.insufficientCoins: return "Not enough coins"
        case BookmarkChoiceError.itemUnavailable: return "This Bookmark cannot be removed right now"
        case BookmarkChoiceError.staleChoice: return "This choice is no longer available"
        case Shop.MarkerError.squareTaken: return "Another Marker owns that square"
        default: return "\(error)"
        }
    }
}
