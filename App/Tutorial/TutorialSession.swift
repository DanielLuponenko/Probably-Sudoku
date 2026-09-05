import Foundation
import Observation
import ProbablySudokuEngine

/// A newly generated, in-memory practice Book. Never accepts a player's Game.
struct TutorialPractice: Sendable {
    fileprivate var game: Game
    let square: Square
    let handIndex: Int
    let digit: Digit

    static func make() throws -> TutorialPractice {
        var game = Game(seed: "probably-sudoku-onboarding-v1", book: .probably, obstacle: .none)
        try game.startPuzzle()
        guard let puzzle = game.puzzle else { throw PracticeError.unavailable }
        // Prefer a single deducible from the visible givens and held numbers.
        // This inspects only the newly created practice board, never a save.
        for square in puzzle.board.blanks {
            let seen = Set(Geometry.peers[square.index].compactMap { puzzle.board[Square($0)] })
            let candidates = Digit.all.filter { !seen.contains($0) }
            if candidates.count == 1, let digit = candidates.first,
               let index = puzzle.hand.firstIndex(of: digit) {
                return TutorialPractice(game: game, square: square, handIndex: index, digit: digit)
            }
        }
        // A generated Hand may not include a visible single. The practice
        // guide can still show one correct destination for a held number.
        guard let digit = puzzle.hand.first,
              let square = puzzle.board.blanks.first(where: { puzzle.board.correctDigit(at: $0) == digit })
        else { throw PracticeError.unavailable }
        return TutorialPractice(game: game, square: square, handIndex: 0, digit: digit)
    }

    private enum PracticeError: Error { case unavailable }
}

struct TutorialCell: Identifiable, Equatable {
    let square: Square
    let digit: Digit?
    let isGiven: Bool
    var id: Int { square.index }
}

struct TutorialHandCard: Identifiable, Equatable {
    let id: Int
    let digit: Digit
}

struct TutorialPracticeSnapshot: Equatable {
    let cells: [TutorialCell]
    let hand: [TutorialHandCard]
    let score: Int
    let queued: Int
    let target: Int
    let turn: Int
    let turns: Int
    let coins: Int
}

/// Owns practice only. No saves, achievements, cloud, sound, or advertising.
@MainActor
@Observable
final class TutorialSession {
    enum Step: Int, CaseIterable, Sendable {
        case goal, select, place, bank, banked, books, bookmarks, tools, shop, boss, ready

        /// About 97 seconds unattended. VoiceOver and background never advance.
        var idleSeconds: Double {
            switch self {
            case .goal: 8
            case .select: 10
            case .place: 12
            case .bank: 8
            case .banked: 6
            case .books, .bookmarks: 9
            case .tools, .shop, .boss: 10
            case .ready: 5
            }
        }
        var showsBoard: Bool { rawValue <= Step.banked.rawValue }
    }

    private(set) var step: Step = .goal
    private(set) var snapshot: TutorialPracticeSnapshot?
    private(set) var selectedCardID: Int?
    private(set) var targetSquare: Square?
    private(set) var targetCardID: Int?
    private(set) var targetDigit: Digit?
    private(set) var feedback: String?
    private(set) var preparationFailed = false
    private(set) var isLoading = false
    private(set) var isStopped = false
    private(set) var completion: OnboardingStore.Resolution?
    private(set) var activityRevision = 0
    @ObservationIgnored private var practice: TutorialPractice?
    @ObservationIgnored private var loadingID: UUID?

    init(practice: TutorialPractice? = nil) {
        if let practice { install(practice) }
    }

    func prepare() async {
        guard practice == nil, !isLoading, !isStopped, !Task.isCancelled else { return }
        let id = UUID()
        loadingID = id
        isLoading = true
        preparationFailed = false
        defer {
            if loadingID == id { isLoading = false; loadingID = nil }
        }
        do {
            let prepared = try await Task.detached(priority: .userInitiated) {
                try TutorialPractice.make()
            }.value
            guard !Task.isCancelled, loadingID == id, !isStopped else { return }
            install(prepared)
        } catch {
            guard !Task.isCancelled, loadingID == id, !isStopped else { return }
            preparationFailed = true
        }
    }

    @discardableResult
    func selectCard(_ id: Int) -> Bool {
        guard step == .select, !isStopped else { return false }
        activityRevision += 1
        guard id == targetCardID else {
            feedback = "Try the outlined \(targetDigit?.rawValue ?? 0). No points lost here."
            return false
        }
        selectedCardID = id
        go(to: .place)
        return true
    }

    @discardableResult
    func place(at square: Square) -> Bool {
        guard step == .place, !isStopped, var practice,
              selectedCardID == practice.handIndex else { return false }
        activityRevision += 1
        guard square == practice.square else {
            feedback = "Try the outlined square. Practice mistakes never cost points or numbers."
            return false
        }
        do {
            _ = try practice.game.place(handIndex: practice.handIndex, at: square)
            self.practice = practice
            selectedCardID = nil
            refreshSnapshot()
            go(to: .bank)
            return true
        } catch {
            feedback = "That practice move could not be placed. You can skip this lesson at any time."
            return false
        }
    }

    @discardableResult
    func bankTurn() -> Bool {
        guard step == .bank, !isStopped, var practice else { return false }
        do {
            _ = try practice.game.endTurn()
            self.practice = practice
            refreshSnapshot()
            go(to: .banked)
            return true
        } catch {
            feedback = "The practice Turn could not finish. You can still skip the lesson."
            return false
        }
    }

    /// The same action powers the explicit Next/Show me button and idle guide.
    func continueLesson() {
        guard snapshot != nil, !isStopped else { return }
        switch step {
        case .select:
            if let targetCardID { selectCard(targetCardID) }
        case .place:
            if let targetSquare { place(at: targetSquare) }
        case .bank: bankTurn()
        case .ready: finish(as: .completed)
        default:
            if let next = Step(rawValue: step.rawValue + 1) { go(to: next) }
        }
    }

    /// The view cancels/restarts this task on interaction, scene, or VO changes.
    /// The revision check also rejects a stale wake-up after a manual action.
    func advanceWhenIdle(enabled: Bool, delay: Duration? = nil) async {
        guard enabled, snapshot != nil, !isStopped, !Task.isCancelled else { return }
        let revision = activityRevision
        let expectedStep = step
        do { try await Task.sleep(for: delay ?? .seconds(step.idleSeconds)) }
        catch { return }
        guard !Task.isCancelled, !isStopped, step == expectedStep,
              activityRevision == revision else { return }
        continueLesson()
    }

    func skip() { finish(as: .skipped) }

    func stop() {
        isStopped = true
        loadingID = nil
        isLoading = false
        activityRevision += 1
    }

    private func finish(as resolution: OnboardingStore.Resolution) {
        guard !isStopped, completion == nil else { return }
        stop()
        completion = resolution
    }

    private func go(to step: Step) {
        self.step = step
        feedback = nil
        activityRevision += 1
    }

    private func install(_ practice: TutorialPractice) {
        self.practice = practice
        targetSquare = practice.square
        targetCardID = practice.handIndex
        targetDigit = practice.digit
        refreshSnapshot()
    }

    private func refreshSnapshot() {
        guard let practice, let puzzle = practice.game.puzzle else { return }
        snapshot = TutorialPracticeSnapshot(
            cells: Square.all.map { TutorialCell(square: $0, digit: puzzle.board[$0],
                                                 isGiven: puzzle.board.isGiven[$0.index]) },
            hand: puzzle.hand.enumerated().map { TutorialHandCard(id: $0.offset, digit: $0.element) },
            score: puzzle.score, queued: puzzle.pendingScore,
            target: puzzle.target, turn: puzzle.turnNumber, turns: puzzle.turnsMax,
            coins: practice.game.run.coins)
    }
}
