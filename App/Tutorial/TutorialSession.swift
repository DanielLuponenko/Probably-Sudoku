import Foundation
import Observation
import ProbablySudokuEngine

/// A newly generated, in-memory practice Book. Never accepts a player's Game.
struct TutorialPractice: Sendable {
    fileprivate var game: Game
    fileprivate(set) var square: Square
    fileprivate(set) var handIndex: Int
    fileprivate(set) var digit: Digit

    static let suppliedCoins = 30
    static let bookmarkID = "bm_local_gossip"
    static let multiplierID = "bm_op_ed"
    static let markerID = "mk_golden"
    static let spareBuffID = "bf_overtime"

    static func make() throws -> TutorialPractice {
        var game = Game(seed: "probably-sudoku-onboarding-v1", book: .probably, obstacle: .none)
        try game.startPuzzle()
        guard let puzzle = game.puzzle else { throw PracticeError.unavailable }
        for square in puzzle.board.blanks {
            let seen = Set(Geometry.peers[square.index].compactMap { puzzle.board[Square($0)] })
            let candidates = Digit.all.filter { !seen.contains($0) }
            if candidates.count == 1, let digit = candidates.first,
               let index = puzzle.hand.firstIndex(of: digit) {
                return TutorialPractice(game: game, square: square, handIndex: index, digit: digit)
            }
        }
        guard let digit = puzzle.hand.first,
              let square = puzzle.board.blanks.first(where: { puzzle.board.correctDigit(at: $0) == digit })
        else { throw PracticeError.unavailable }
        return TutorialPractice(game: game, square: square, handIndex: 0, digit: digit)
    }

    /// The second exercise supplies its resources explicitly. Purchases still
    /// go through the live engine's price, capacity, and inventory rules.
    fileprivate mutating func openPracticeShop() {
        var run = game.run
        run.puzzle = nil
        run.coins = Self.suppliedCoins
        run.buffs = [OwnedBuff(defID: Self.spareBuffID, pricePaid: 4)]
        run.shop = ShopState(offers: [
            ShopOffer(slot: 0, defID: Self.bookmarkID, price: 4),
            ShopOffer(slot: 1, defID: Self.multiplierID, price: 5),
            ShopOffer(slot: 2, defID: Self.markerID, price: 5),
            ShopOffer(slot: 3, defID: Buffs.freshInk, price: 4)
        ])
        game = Game(run: run)
    }

    /// Set up an explicitly prepared row, keeping every number conserved.
    /// Only fixture construction fills squares directly; every learner action
    /// uses Game's production methods. This also works in release builds.
    fileprivate mutating func prepareCombination() throws {
        try game.startPuzzle()
        var run = game.run
        guard var puzzle = run.puzzle,
              let square = puzzle.board.blanks.first(where: { puzzle.board.correctDigit(at: $0) == .nine })
        else { throw PracticeError.unavailable }

        for held in puzzle.hand { puzzle.pool.put(held) }
        puzzle.hand = []
        for other in puzzle.board.blanks where other.row == square.row && other != square {
            let number = puzzle.board.correctDigit(at: other)
            guard puzzle.pool.take(number) else { throw PracticeError.unavailable }
            puzzle.board.fill(other, with: number, by: .player)
        }
        guard puzzle.pool.take(.nine) else { throw PracticeError.unavailable }
        puzzle.hand = [.nine]
        puzzle.hand += puzzle.pool.draw(&run.streams.pool, count: puzzle.handSize - 1)
        guard Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand) == nil
        else { throw PracticeError.unavailable }
        run.puzzle = puzzle
        game = Game(run: run)
        self.square = square
        self.handIndex = 0
        self.digit = .nine
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

struct TutorialOwnedItem: Identifiable, Equatable {
    let index: Int
    let defID: String
    let name: String
    let detail: String
    let pricePaid: Int
    let sellPrice: Int
    var id: String { defID }
}

struct TutorialShopOffer: Identifiable, Equatable {
    let slot: Int
    let defID: String
    let name: String
    let detail: String
    let price: Int
    let sold: Bool
    var id: Int { slot }
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
    let queuedBase: Int
    let multiplier: Double
    let bookmarks: [TutorialOwnedItem]
    let markers: [TutorialOwnedItem]
    let buffs: [TutorialOwnedItem]
    let offers: [TutorialShopOffer]
    let markedSquares: [Square]
    let completedUnits: Int
    let payout: RunState.Payout?
    let phase: PuzzlePhase?
}

/// Owns practice only. No saves, achievements, cloud, sound, or advertising.
@MainActor
@Observable
final class TutorialSession {
    enum Step: Int, CaseIterable, Sendable {
        case goal, select, place, bank, banked
        case shop, buyBookmark, buyMultiplier, buyMarker, buyBuff
        case markerPlacement, comboSelect, comboPlace, comboScore, useBuff, buffed
        case sellBookmark, sellBuff, comboBank, won, payout, books, boss, ready

        var requiresInteraction: Bool {
            switch self {
            case .select, .place, .bank, .buyBookmark, .buyMultiplier, .buyMarker, .buyBuff,
                 .markerPlacement, .comboSelect, .comboPlace, .useBuff, .sellBookmark,
                 .sellBuff, .comboBank, .won: true
            default: false
            }
        }

        var showsBoard: Bool {
            rawValue <= Self.banked.rawValue
                || (Self.markerPlacement.rawValue...Self.payout.rawValue).contains(rawValue)
        }

        var showsShop: Bool { (Self.shop.rawValue...Self.buyBuff.rawValue).contains(rawValue) }
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
    private(set) var lastPlacement: PlacementOutcome?
    private(set) var lastTurn: Actions.TurnResult?
    private(set) var lastSaleCoins: Int?
    @ObservationIgnored private var practice: TutorialPractice?
    @ObservationIgnored private var loadingID: UUID?

    var targetOfferSlot: Int? {
        switch step {
        case .buyBookmark: 0
        case .buyMultiplier: 1
        case .buyMarker: 2
        case .buyBuff: 3
        default: nil
        }
    }
    var targetBuffIndex: Int? {
        guard step == .useBuff else { return nil }
        return snapshot?.buffs.first(where: { $0.defID == Buffs.freshInk })?.index
    }
    var targetSaleKind: ItemKind? {
        switch step {
        case .sellBookmark: .bookmark
        case .sellBuff: .buff
        default: nil
        }
    }
    var targetSaleIndex: Int? {
        switch step {
        case .sellBookmark: snapshot?.bookmarks.first(where: { $0.defID == TutorialPractice.bookmarkID })?.index
        case .sellBuff: snapshot?.buffs.first(where: { $0.defID == TutorialPractice.spareBuffID })?.index
        default: nil
        }
    }

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
        guard (step == .select || step == .comboSelect), !isStopped else { return false }
        activityRevision += 1
        guard id == targetCardID else {
            feedback = "Try the outlined \(targetDigit?.rawValue ?? 0). No points lost here."
            return false
        }
        selectedCardID = id
        go(to: step == .select ? .place : .comboPlace)
        return true
    }

    @discardableResult
    func place(at square: Square) -> Bool {
        guard (step == .place || step == .comboPlace), !isStopped, var practice,
              selectedCardID == practice.handIndex else { return false }
        activityRevision += 1
        guard square == practice.square else {
            feedback = "Try the outlined square. Practice mistakes never cost points or numbers."
            return false
        }
        do {
            lastPlacement = try practice.game.place(handIndex: practice.handIndex, at: square)
            self.practice = practice
            selectedCardID = nil
            refreshSnapshot()
            go(to: step == .place ? .bank : .comboScore)
            return true
        } catch { return failedAction("That practice move could not be placed.") }
    }

    @discardableResult
    func bankTurn() -> Bool {
        guard (step == .bank || step == .comboBank), !isStopped, var practice else { return false }
        do {
            let result = try practice.game.endTurn()
            guard step != .comboBank || practice.game.puzzle?.phase == .won else {
                return failedAction("The practice target was not reached.")
            }
            lastTurn = result
            self.practice = practice
            refreshSnapshot()
            go(to: step == .bank ? .banked : .won)
            return true
        } catch { return failedAction("The practice Turn could not finish.") }
    }

    @discardableResult
    func buyOffer(_ slot: Int) -> Bool {
        guard let expected = targetOfferSlot, !isStopped, var practice else { return false }
        activityRevision += 1
        guard slot == expected else {
            feedback = "Buy the outlined item for this lesson. Your practice coins are safe."
            return false
        }
        do {
            try practice.game.buy(slot: slot)
            if step == .buyBuff { try practice.prepareCombination() }
            self.practice = practice
            updateTargets()
            refreshSnapshot()
            go(to: Step(rawValue: step.rawValue + 1)!)
            return true
        } catch { return failedAction("That practice purchase could not finish.") }
    }

    @discardableResult
    func claimMarker(at square: Square) -> Bool {
        guard step == .markerPlacement, !isStopped, var practice else { return false }
        activityRevision += 1
        guard square == targetSquare,
              let index = practice.game.run.markers.firstIndex(where: { $0.defID == TutorialPractice.markerID })
        else {
            feedback = "Mark the outlined blank. A Marker belongs to its square, whatever number you place there."
            return false
        }
        do {
            try practice.game.claimSquare(markerIndex: index, square: square)
            self.practice = practice
            refreshSnapshot()
            go(to: .comboSelect)
            return true
        } catch { return failedAction("That practice square could not be marked.") }
    }

    @discardableResult
    func useBuff(_ index: Int) -> Bool {
        guard step == .useBuff, !isStopped, var practice else { return false }
        activityRevision += 1
        guard index == targetBuffIndex else {
            feedback = "Use Fresh Ink for this lesson. Keep Overtime for the selling practice."
            return false
        }
        do {
            guard try practice.game.useBuff(at: index) else {
                return failedAction("That Buff could not be used.")
            }
            self.practice = practice
            refreshSnapshot()
            go(to: .buffed)
            return true
        } catch { return failedAction("That practice Buff could not be used.") }
    }

    @discardableResult
    func sellItem(kind: ItemKind, index: Int) -> Bool {
        guard let expectedKind = targetSaleKind, !isStopped, var practice else { return false }
        activityRevision += 1
        guard kind == expectedKind, index == targetSaleIndex else {
            feedback = "Sell the outlined item. Markers stay on the board and cannot be sold."
            return false
        }
        do {
            lastSaleCoins = try practice.game.sell(kind: kind, index: index)
            self.practice = practice
            refreshSnapshot()
            go(to: step == .sellBookmark ? .sellBuff : .comboBank)
            return true
        } catch { return failedAction("That practice item could not be sold.") }
    }

    @discardableResult
    func cashOut() -> Bool {
        guard step == .won, !isStopped, var practice else { return false }
        do {
            _ = try practice.game.cashOut()
            self.practice = practice
            refreshSnapshot()
            go(to: .payout)
            return true
        } catch { return failedAction("That practice payout could not be collected.") }
    }

    /// Informational pages can continue; practice actions must be performed on
    /// their controls. Neither this method nor a timer plays for the learner.
    func continueLesson() {
        guard snapshot != nil, !isStopped, !step.requiresInteraction else { return }
        if step == .ready { finish(as: .completed); return }
        if step == .banked, var practice {
            practice.openPracticeShop()
            self.practice = practice
            lastPlacement = nil
            lastTurn = nil
            refreshSnapshot()
        }
        if let next = Step(rawValue: step.rawValue + 1) { go(to: next) }
    }

    /// Kept as an explicit compatibility seam for pacing regression tests.
    /// Waiting, VoiceOver changes, and scene changes never perform an action.
    func advanceWhenIdle(enabled: Bool, delay: Duration? = nil) async {}

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

    private func failedAction(_ message: String) -> Bool {
        feedback = message + " You can exit practice at any time."
        return false
    }

    private func install(_ practice: TutorialPractice) {
        self.practice = practice
        updateTargets()
        refreshSnapshot()
    }

    private func updateTargets() {
        targetSquare = practice?.square
        targetCardID = practice?.handIndex
        targetDigit = practice?.digit
    }

    private func refreshSnapshot() {
        guard let practice else { return }
        let run = practice.game.run
        let puzzle = run.puzzle
        func item(index: Int, def: ItemDef, price: Int) -> TutorialOwnedItem {
            TutorialOwnedItem(index: index, defID: def.id, name: def.name, detail: def.text,
                              pricePaid: price, sellPrice: Shop.sellPrice(price))
        }
        snapshot = TutorialPracticeSnapshot(
            cells: puzzle.map { puzzle in
                Square.all.map { TutorialCell(square: $0, digit: puzzle.board[$0],
                                             isGiven: puzzle.board.isGiven[$0.index]) }
            } ?? [],
            hand: puzzle?.hand.enumerated().map { TutorialHandCard(id: $0.offset, digit: $0.element) } ?? [],
            score: puzzle?.score ?? 0, queued: puzzle?.pendingScore ?? 0,
            target: puzzle?.target ?? run.target, turn: puzzle?.turnNumber ?? 1,
            turns: puzzle?.turnsMax ?? run.effectiveTurns(boss: nil), coins: run.coins,
            queuedBase: puzzle?.pendingBase ?? 0, multiplier: puzzle?.pendingMultiplier ?? 1,
            bookmarks: run.bookmarks.enumerated().map { item(index: $0.offset, def: $0.element.def, price: $0.element.pricePaid) },
            markers: run.markers.enumerated().map { item(index: $0.offset, def: $0.element.def, price: $0.element.pricePaid) },
            buffs: run.buffs.enumerated().map { item(index: $0.offset, def: $0.element.def, price: $0.element.pricePaid) },
            offers: run.shop?.offers.map { TutorialShopOffer(slot: $0.slot, defID: $0.defID,
                name: $0.def.name, detail: $0.def.text, price: $0.price, sold: $0.sold) } ?? [],
            markedSquares: run.markers.flatMap(\.squares),
            completedUnits: lastPlacement?.lineClears.count ?? 0,
            payout: puzzle?.bankedPayout, phase: puzzle?.phase)
    }
}
