import XCTest
import SwiftUI
import UIKit
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

/// A visual contract backed by actual, conserved engine actions. These fixtures
/// never open RunStore and cannot replace the player's current Book.
@MainActor
final class BossVisualClarityTests: XCTestCase {
    private let bosses: [BossModifier] = [.galleyQueue, .bookends, .reprintBan, .chainStitcher]

    func testQueueFrontFollowsExactArrivalCopiesAfterPlayAndArrangement() throws {
        var game = try fixture(.galleyQueue)
        let original = try XCTUnwrap(game.puzzle).handCards
        XCTAssertEqual(playableIDs(game), Set(original.prefix(2).map(\.id)))
        _ = try place(3, in: &game)
        XCTAssertEqual(playableIDs(game), Set([original[1].id, original[2].id]))
        let model = GameModel(frozen: game, page: .puzzle)
        let saved = try model.game.encoded()
        for arrangement in [GameModel.HandArrangement.ascending, .descending, .random, .dealt] {
            model.arrangeHand(arrangement)
            let p = try XCTUnwrap(model.puzzle)
            let shownFront = model.displayedHandCards.filter { card in
                BossHandTreatment.resolve(index: model.canonicalHandIndex(for: card.id), puzzle: p) == .queueFront
            }.map(\.id)
            XCTAssertEqual(Set(shownFront), Set([original[1].id, original[2].id]))
            XCTAssertEqual(try model.game.encoded(), saved, "Sorting a visual queue must not reorder engine arrivals")
        }
        try assertConservedAndRestorable(game)
    }

    func testBookendsLightEverySeparateCopyOfTheCurrentExtremes() throws {
        var game = try fixture(.bookends)
        let original = try XCTUnwrap(game.puzzle).handCards
        XCTAssertNotEqual(original[1].id, original[3].id)
        XCTAssertEqual(playableIDs(game), Set([original[1].id, original[2].id, original[3].id]))
        _ = try place(8, in: &game)
        XCTAssertEqual(playableIDs(game), Set([original[1].id, original[3].id, original[5].id]))
        let p = try XCTUnwrap(game.puzzle)
        for index in p.hand.indices {
            XCTAssertEqual(BossHandTreatment.resolve(index: index, puzzle: p),
                           p.hand[index] == .one ? .lowBookend : p.hand[index] == .seven ? .highBookend : .middle)
        }
        try assertConservedAndRestorable(game)
    }

    func testIndependentlyBarredCardsNeverAdvertiseAPlayableQueueOrBookend() throws {
        for (boss, barredDigit) in [(BossModifier.galleyQueue, Digit.four), (.bookends, .one)] {
            var p = try XCTUnwrap(fixture(boss).puzzle)
            p.blockedDigit = barredDigit
            for index in p.hand.indices where p.hand[index] == barredDigit {
                XCTAssertTrue(p.isIndependentlyBlocked(handIndex: index))
                XCTAssertEqual(BossHandTreatment.resolve(index: index, puzzle: p), .none)
            }
        }
    }

    func testRepeatStampAppearsOnTheOtherCopyAndReleasesWhenNoUnusedCardRemains() throws {
        var game = try fixture(.reprintBan)
        let original = try XCTUnwrap(game.puzzle).handCards
        XCTAssertNotEqual(original[0].id, original[1].id)
        XCTAssertEqual(playableIDs(game).count, 7)
        _ = try place(4, in: &game)
        let stamped = try XCTUnwrap(game.puzzle)
        XCTAssertFalse(stamped.handCardIDs.contains(original[0].id))
        XCTAssertEqual(stamped.handCardIDs.first, original[1].id)
        XCTAssertEqual(BossHandTreatment.resolve(index: 0, puzzle: stamped), .repeatWaiting)
        XCTAssertFalse(stamped.isTossBlocked(handIndex: 0), "A waiting repeat is still tossable")
        for square in [1, 2, 6, 7, 8] { _ = try place(square, in: &game) }
        let released = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(released.handCardIDs, [original[1].id])
        XCTAssertFalse(released.isBlocked(handIndex: 0))
        XCTAssertNotEqual(BossHandTreatment.resolve(index: 0, puzzle: released), .repeatWaiting)
        XCTAssertEqual(released.turnNumber, 1, "Releasing the last repeat cannot secretly advance the Turn")
        try assertConservedAndRestorable(game)
    }

    func testChainProjectionBeginsOnlyAfterNaturalFillAndFollowsPublicUnits() throws {
        var game = try fixture(.chainStitcher)
        let initial = BossChainProjection(puzzle: game.puzzle)
        XCTAssertNil(initial.anchor)
        XCTAssertTrue(initial.fullPointSquares.isEmpty)
        XCTAssertTrue(initial.halfPointSquares.isEmpty)
        _ = try place(0, in: &game)
        let p = try XCTUnwrap(game.puzzle)
        let projected = BossChainProjection(puzzle: p)
        XCTAssertEqual(projected.anchor, Square(0))
        let connected = Set(p.board.blanks.filter { $0.row == 0 || $0.col == 0 || $0.box == 0 })
        XCTAssertEqual(projected.fullPointSquares, connected)
        XCTAssertEqual(projected.halfPointSquares, Set(p.board.blanks).subtracting(connected))
        XCTAssertTrue(projected.fullPointSquares.isDisjoint(with: projected.halfPointSquares))
        XCTAssertEqual(projected.fullPointSquares.union(projected.halfPointSquares), Set(p.board.blanks))
        let linked = try place(1, in: &game)
        XCTAssertEqual(linked.points, 20)
        XCTAssertEqual(BossChainProjection(puzzle: game.puzzle).anchor, Square(1))
        let unlinked = try place(40, in: &game)
        XCTAssertEqual(unlinked.points, 45)
        XCTAssertEqual(BossChainProjection(puzzle: game.puzzle).anchor, Square(40))
        _ = try game.endTurn()
        XCTAssertNil(BossChainProjection(puzzle: game.puzzle).anchor)
        try assertConservedAndRestorable(game)
    }

    func testChainCluesAndInactivePhasesCannotAdvertiseAnUnearnedScoringZone() throws {
        var game = try fixture(.chainStitcher)
        _ = try game.useClue(at: Square(0))
        XCTAssertNil(BossChainProjection(puzzle: game.puzzle).anchor)
        _ = try place(1, in: &game)
        _ = try game.useClue(at: Square(2))
        XCTAssertEqual(BossChainProjection(puzzle: game.puzzle).anchor, Square(1), "Clues must not move the natural-fill anchor")
        var p = try XCTUnwrap(game.puzzle)
        p.phase = .keepFilling
        XCTAssertNil(BossChainProjection(puzzle: p).anchor)
        XCTAssertTrue(BossChainProjection(puzzle: p).fullPointSquares.isEmpty)
        p.phase = .playing
        p.boss = .fog
        XCTAssertNil(BossChainProjection(puzzle: p).anchor)
        XCTAssertTrue(BossChainProjection(puzzle: p).halfPointSquares.isEmpty)
        try assertConservedAndRestorable(game)
    }

    func testChainProjectionCannotRevealTheHiddenSolution() throws {
        var game = try fixture(.chainStitcher)
        _ = try place(0, in: &game)
        let original = try XCTUnwrap(game.puzzle)
        var alternate = original
        // Change every concealed answer while preserving every public square.
        // This is intentionally not another solvable fixture: the projection
        // has no reason to read or validate concealed answers at all.
        var answers = original.board.solution
        for square in original.board.blanks {
            answers[square.index] = Digit(rawValue: answers[square.index].rawValue % 9 + 1)!
        }
        alternate.board = Board(GeneratedPuzzle(solution: answers, isGiven: original.board.isGiven))
        for square in Square.all {
            if let digit = original.board[square], let provenance = original.board.filledBy[square.index] {
                alternate.board.fill(square, with: digit, by: provenance)
            }
        }
        XCTAssertEqual(alternate.board.placed, original.board.placed)
        XCTAssertEqual(BossChainProjection(puzzle: alternate), BossChainProjection(puzzle: original))
    }

    func testChainProjectionExcludesUnavailableSquaresAndDoesNotPromiseCorrectness() throws {
        var game = try fixture(.chainStitcher)
        _ = try place(0, in: &game)
        var p = try XCTUnwrap(game.puzzle)
        let connected = Square(1), disconnected = Square(40)
        var bars = BossTurnState()
        bars.greyed = [connected, disconnected]
        p.bossTurn = bars
        let projection = BossChainProjection(puzzle: p)
        for square in [connected, disconnected] {
            XCTAssertFalse(projection.fullPointSquares.contains(square))
            XCTAssertFalse(projection.halfPointSquares.contains(square))
            XCTAssertNil(projection.accessibilityHint(for: square))
        }
        p.bossTurn = nil
        let open = BossChainProjection(puzzle: p)
        XCTAssertTrue(try XCTUnwrap(open.accessibilityHint(for: connected)).contains("if correct"))
        XCTAssertTrue(try XCTUnwrap(open.accessibilityHint(for: disconnected)).contains("if correct"))
    }

    func testCaptureProductionBossStatesAtBothPhoneSizesWithoutChangingGame() async throws {
        for boss in bosses {
            var game = try fixture(boss)
            var stages = [("before", game)]
            switch boss {
            case .galleyQueue: _ = try place(3, in: &game)
            case .bookends: _ = try place(8, in: &game)
            case .reprintBan: _ = try place(4, in: &game)
            case .chainStitcher:
                _ = try place(0, in: &game)
                stages.append(("anchored", game))
                _ = try place(1, in: &game)
                stages.append(("linked", game))
                _ = try place(40, in: &game)
            default: XCTFail("Unexpected fixture")
            }
            stages.append(("after", game))
            for (stage, savedGame) in stages {
                for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)] {
                    let model = GameModel(frozen: savedGame, page: .puzzle)
                    let saved = try model.game.encoded()
                    let selected = try XCTUnwrap(model.puzzle?.hand.indices.first { !model.isBlocked(handIndex: $0) })
                    model.tapHand(selected)
                    let flipper = PageFlipper()
                    let view = ClarityBossSurface(model: model, flipper: flipper, size: size, reducedMotion: true)
                    let image = try await capture(view, size: size)
                    attach(image, "boss-clarity-\(boss.rawValue)-\(stage)-\(Int(size.width))x\(Int(size.height))")
                    XCTAssertEqual(try model.game.encoded(), saved, "A visual explanation must never play or modify a card")
                    XCTAssertEqual(model.selectedHandIndex, selected, "Rendering cannot cancel the player's chosen card")
                    try assertConservedAndRestorable(model.game)
                    flipper.cancel()
                }
            }
        }
    }

    func testStatusDiagramsShowRealPendingBankConsequencesAndNeverCommitTheirPreview() async throws {
        for boss in [BossModifier.serialPublisher, .rivalColumn, .wordCount, .pageCutter, .orphanLine] {
            var game = try fixture(boss)
            switch boss {
            case .serialPublisher, .wordCount:
                _ = try place(8, in: &game)
            case .rivalColumn:
                _ = try place(8, in: &game)
                _ = try game.endTurn()
                _ = try place(0, in: &game)
            case .pageCutter:
                for index in [0, 1, 2] { _ = try place(index, in: &game) }
            case .orphanLine:
                for index in [8, 7, 6] { _ = try place(index, in: &game) }
            default: XCTFail("Unexpected status fixture")
            }
            let p = try XCTUnwrap(game.puzzle), saved = try game.encoded()
            XCTAssertTrue(BossStatusDiagram.supports(boss))
            let ledger = p.pendingScoringLedger
            switch boss {
            case .serialPublisher:
                let bank = try XCTUnwrap(ledger.bossSettlement)
                XCTAssertEqual(bank.paid, 300)
                XCTAssertEqual(bank.carryAfter, 1_140)
            case .rivalColumn:
                let bank = try XCTUnwrap(ledger.bossSettlement)
                XCTAssertEqual(bank.benchmark, 90)
                XCTAssertEqual(bank.gross, 10)
                XCTAssertEqual(bank.paid, 8)
            case .wordCount:
                XCTAssertEqual(p.bossState.scoring.wordCountSpent, 150)
            case .pageCutter:
                XCTAssertEqual(p.bossState.correctFills, 3)
                XCTAssertEqual(p.turnNumber, 1)
            case .orphanLine:
                XCTAssertEqual(BossScoring.orphanDebit(p), 80)
                XCTAssertEqual(p.hand.count, 4)
            default: break
            }
            // Comparing the committed bank with the same preview the diagram
            // reads catches duplicated carry, fees, or side effects on redraw.
            var committed = game
            let bank = try committed.endTurn()
            XCTAssertEqual(bank.pointsGained, ledger.total)
            XCTAssertEqual(try game.encoded(), saved)
            for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)] {
                let model = GameModel(frozen: game, page: .puzzle), flipper = PageFlipper()
                let surface = ClarityBossSurface(model: model, flipper: flipper, size: size, reducedMotion: true)
                attach(try await capture(surface, size: size),
                       "boss-clarity-\(boss.rawValue)-pending-\(Int(size.width))x\(Int(size.height))")
                XCTAssertEqual(try model.game.encoded(), saved)
                XCTAssertEqual(model.puzzle?.pendingScoringLedger, ledger)
                flipper.cancel()
            }
            try assertConservedAndRestorable(game)
        }
    }

    /// Start simctl recordVideo before this opt-in test. Printed epoch segment
    /// boundaries use the same schema as the existing 39-boss animation gallery.
    func testRecordFourBossClarityAnimations() async throws {
        guard ProcessInfo.processInfo.environment["NC_RECORD_BOSS_CLARITY"] == "1" else {
            throw XCTSkip("Set NC_RECORD_BOSS_CLARITY=1 for the four-boss production animation recording")
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.screen.bounds
        window.windowLevel = .normal + 1
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        let defaults = UserDefaults.standard
        let keys = [AppPreferences.Key.ambientMotion, AppPreferences.Key.reducedMotion]
        let oldValues = keys.map { defaults.object(forKey: $0) }
        defaults.set(true, forKey: keys[0]); defaults.set(false, forKey: keys[1])
        defer {
            for (key, value) in zip(keys, oldValues) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        var segments: [RecordingSegment] = []
        try await Task.sleep(for: .seconds(2))
        for boss in bosses {
            let model = GameModel(resuming: try fixture(boss), savesProgress: false)
            let flipper = PageFlipper()
            let host = UIHostingController(rootView: ClarityBossSurface(model: model, flipper: flipper,
                size: window.bounds.size, reducedMotion: false))
            host.safeAreaRegions = []
            let start = Date().timeIntervalSince1970
            window.rootViewController = host
            window.makeKeyAndVisible(); window.layoutIfNeeded()
            print("BOSS_SHOWCASE_START \(boss.rawValue) \(start)")
            try await Task.sleep(for: .seconds(2.2))
            var actions: [RecordingAction] = []
            let squares: [Int]
            switch boss {
            case .galleyQueue: squares = [3]
            case .bookends: squares = [8]
            case .reprintBan: squares = [4]
            case .chainStitcher: squares = [0, 1, 40]
            default: squares = []
            }
            for index in squares {
                let p = try XCTUnwrap(model.puzzle), square = Square(index)
                let digit = p.board.correctDigit(at: square) // Test authoring, never used by a visual.
                let card = try XCTUnwrap(p.hand.indices.first { p.hand[$0] == digit && !model.isBlocked(handIndex: $0) })
                actions.append(.init(time: Date().timeIntervalSince1970,
                    description: "Play held \(digit.rawValue) at R\(square.row + 1) C\(square.col + 1); show the real updated boss state."))
                model.tapHand(card); model.tapSquare(square)
                XCTAssertEqual(model.lastOutcome?.correct, true)
                try await Task.sleep(for: .seconds(3.1))
            }
            attach(windowImage(window), "boss-clarity-animation-poster-\(boss.rawValue)")
            if boss == .chainStitcher || boss == .reprintBan {
                actions.append(.init(time: Date().timeIntervalSince1970,
                    description: "End the real Turn; the chain anchor or repeat restrictions clear at the committed boundary."))
                model.endTurn()
                try await Task.sleep(for: .seconds(3.3))
            }
            try await Task.sleep(for: .seconds(2))
            model.setClockRunning(false)
            let p = try XCTUnwrap(model.puzzle)
            try assertConservedAndRestorable(model.game)
            let segment = RecordingSegment(bossID: boss.rawValue, name: boss.name, rule: boss.text,
                start: start, end: Date().timeIntervalSince1970, actions: actions,
                limitation: "Deterministic QA board and conserved held cards. All visual transitions and score receipts follow accepted production actions; this is not a full boss completion.",
                width: window.bounds.width, height: window.bounds.height, initialTurn: 1,
                finalTurn: p.turnNumber, finalScore: p.score, finalPendingPoints: p.pendingBase)
            segments.append(segment)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            print("BOSS_SHOWCASE_SEGMENT " + String(decoding: try encoder.encode(segment), as: UTF8.self))
            model.finishScorePresentation(); flipper.cancel()
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = XCTAttachment(data: try encoder.encode(segments), uniformTypeIdentifier: "public.json")
        metadata.name = "boss-clarity-animation-timeline"; metadata.lifetime = .keepAlways; add(metadata)
        print("BOSS_SHOWCASE_COMPLETE \(Date().timeIntervalSince1970)")
    }

    private func fixture(_ boss: BossModifier) throws -> Game {
        let hand: [Digit]
        switch boss {
        case .galleyQueue: hand = [.four, .one, .nine, .two, .seven, .three, .six]
        case .bookends: hand = [.three, .one, .nine, .one, .six, .seven, .four]
        case .reprintBan: hand = [.five, .five, .two, .three, .seven, .eight, .nine]
        case .orphanLine: hand = [.nine, .eight, .seven, .six, .one, .two, .three]
        case .serialPublisher, .rivalColumn, .wordCount: hand = [.nine, .one, .two, .three, .four, .five, .six]
        default: hand = [.one, .nine, .two, .three, .four, .five, .six]
        }
        var run = RunState(seed: "boss-visual-clarity-\(boss.rawValue)", book: .probably)
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss; run.pendingBoss = boss; run.coins = 12
        run.buffs = [Buffs.freshInk, Buffs.peek].map { OwnedBuff(defID: $0, pricePaid: 0) }
        if boss == .serialPublisher || boss == .wordCount {
            let bookmarkIDs = boss == .serialPublisher
                ? [Bookmarks.localGossip, Bookmarks.theSundaySupplement] : [Bookmarks.localGossip]
            run.bookmarks = bookmarkIDs.map { OwnedBookmark(defID: $0, boughtAtLevel: run.level, pricePaid: 0) }
            run.markers = [OwnedMarker(defID: Markers.crimson, boughtAtLevel: run.level, pricePaid: 0, squares: [Square(8)])]
        }
        var game = Game(run: run); try game.startPuzzle(); run = game.run
        var p = try XCTUnwrap(game.puzzle)
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        let givens = (0..<81).map { $0 >= 9 && $0.isMultiple(of: 2) && $0 != 40 }
        _ = p.removeAllHandCards()
        p.board = Board(GeneratedPuzzle(solution: solution, isGiven: givens))
        p.pool = Pool(blanksOf: p.board)
        for digit in hand { XCTAssertTrue(p.pool.take(digit)) }
        p.appendHandDigits(hand)
        p.handSize = hand.count; p.target = boss == .serialPublisher ? 900 : 2_000; p.cluesRemaining = 3
        p.boss = boss; p.bossTurn = nil; p.blockedDigit = nil; p.obstacleBlockedDigits = []
        BossRuntime.puzzleStarted(run: run, puzzle: &p)
        BossRuntime.turnStarted(puzzle: &p)
        run.puzzle = p
        MarkerRuntime.synchronizeOwnership(run: &run)
        return Game(run: run)
    }

    private func playableIDs(_ game: Game) -> Set<UUID> {
        guard let p = game.puzzle else { return [] }
        return Set(p.hand.indices.filter { !p.isBlocked(handIndex: $0) }.map { p.handCards[$0].id })
    }

    private func place(_ index: Int, in game: inout Game) throws -> PlacementOutcome {
        let p = try XCTUnwrap(game.puzzle), square = Square(index)
        let digit = p.board.correctDigit(at: square) // Explicit fixture input only.
        let card = try XCTUnwrap(p.hand.indices.first { p.hand[$0] == digit && !p.isBlocked(handIndex: $0) })
        let result = try game.place(handIndex: card, at: square)
        XCTAssertTrue(result.correct)
        return result
    }

    private func assertConservedAndRestorable(_ game: Game) throws {
        let p = try XCTUnwrap(game.puzzle)
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool, hand: p.hand + p.markerState.reservedForkCards))
        let data = try game.encoded(), restored = try Game(decoding: data)
        XCTAssertEqual(try restored.encoded(), data)
    }

    private func capture<V: View>(_ view: V, size: CGSize) async throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size); window.rootViewController = host
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(300))
        window.layoutIfNeeded()
        return windowImage(window)
    }

    private func windowImage(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func attach(_ image: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private struct RecordingAction: Codable {
        let time: Double
        let description: String
    }
    private struct RecordingSegment: Codable {
        let bossID: String
        let name: String
        let rule: String
        let start: Double
        let end: Double
        let actions: [RecordingAction]
        let limitation: String
        let width: Double
        let height: Double
        let initialTurn: Int
        let finalTurn: Int
        let finalScore: Int
        let finalPendingPoints: Int
    }
}

private struct ClarityBossSurface: View {
    @Bindable var model: GameModel
    let flipper: PageFlipper
    let size: CGSize
    let reducedMotion: Bool

    var body: some View {
        RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: EdgeInsets(top: size.height < 700 ? 20 : 62, leading: 0,
            bottom: size.height < 700 ? 0 : 34, trailing: 0), onTapBuff: { _ in }) {
                if let p = model.puzzle { PuzzlePageView(model: model, puzzle: p, isClockRunning: false) }
            }
            .frame(width: size.width, height: size.height)
            .environment(flipper)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
            .environment(\.levelPalette, .forDisplay(slot: .boss))
            .environment(\.scenePhase, reducedMotion ? .inactive : .active)
            .environment(\.bossMotionIsActive, !reducedMotion)
            .environment(\.bossEntranceIsDeferred, false)
            .environment(\.gameReduceMotion, reducedMotion)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US"))
            .ignoresSafeArea()
    }
}
