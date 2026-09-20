import XCTest
import SwiftUI
import UIKit
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

/// An opt-in, recordable showcase of production views and committed engine
/// actions. Run only this test while recording the isolated test simulator.
/// It never opens RunStore or saves its fixture, and changes no game code.
@MainActor
final class BossAnimationShowcaseTests: XCTestCase {
    private struct ActionRecord: Codable {
        var time: Double
        var description: String
    }
    private struct Segment: Codable {
        var bossID: String
        var name: String
        var rule: String
        var start: Double
        var end: Double
        var actions: [ActionRecord]
        var limitation: String
        var width: Double
        var height: Double
        var initialTurn: Int
        var finalTurn: Int
        var finalScore: Int
        var finalPendingPoints: Int
    }

    func testRecordEveryBossWithProductionMotionAndRealActions() async throws {
        guard ProcessInfo.processInfo.environment["NC_RECORD_ALL_BOSS_ANIMATIONS"] == "1" else {
            throw XCTSkip("Opt-in recording: set NC_RECORD_ALL_BOSS_ANIMATIONS=1")
        }
        try await record(bosses: BossModifier.allCases)
    }

    func testRecordActiveRosterWithRealActions() async throws {
        guard ProcessInfo.processInfo.environment["NC_RECORD_BOSS_CLARITY"] == "1" else {
            throw XCTSkip("Opt-in recording: set NC_RECORD_BOSS_CLARITY=1")
        }
        try await record(bosses: BossModifier.activeBosses)
    }

    func testRecordClarifiedSupportingBosses() async throws {
        guard ProcessInfo.processInfo.environment["NC_RECORD_BOSS_CLARITY"] == "1" else {
            throw XCTSkip("Opt-in recording: set NC_RECORD_BOSS_CLARITY=1")
        }
        try await record(bosses: [.censor, .collator, .pageCutter, .returnSlip,
            .orphanLine, .serialPublisher, .dryPress, .reviewBoard, .rivalColumn,
            .wordCount, .backPage])
    }

    func testRecordRemainingBossesFromChainStitcher() async throws {
        guard ProcessInfo.processInfo.environment["NC_RECORD_BOSS_ANIMATIONS"] == "1" else {
            throw XCTSkip("Opt-in recording: set NC_RECORD_BOSS_ANIMATIONS=1")
        }
        let start = try XCTUnwrap(BossModifier.allCases.firstIndex(of: .chainStitcher))
        try await record(bosses: Array(BossModifier.allCases[start...]))
    }

    private func record(bosses: [BossModifier]) async throws {
        // This longer, opt-in render test deliberately yields the main actor
        // between actions so SwiftUI, the active clock and score receipts run.
        continueAfterFailure = false
        let defaults = UserDefaults.standard
        let keys = [AppPreferences.Key.ambientMotion, AppPreferences.Key.reducedMotion]
        let oldValues = keys.map { defaults.object(forKey: $0) }
        defaults.set(true, forKey: AppPreferences.Key.ambientMotion)
        defaults.set(false, forKey: AppPreferences.Key.reducedMotion)
        defer {
            for (key, value) in zip(keys, oldValues) {
                if let value { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let bounds = scene.screen.bounds
        let safeInsets = previousKey?.safeAreaInsets ?? UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)
        let window = UIWindow(windowScene: scene)
        window.frame = bounds
        window.windowLevel = .normal + 1
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        var segments: [Segment] = []
        // Leave a clear synchronization gap after XCTest takes foreground.
        try await pause(2)
        for boss in bosses {
            let game = try fixture(boss)
            let model = GameModel(resuming: game, savesProgress: false)
            // Serial uses a disclosed low QA target to show earned carry in a
            // short clip. Tik Tak resumes a disclosed 32-second checkpoint.
            // Neither has a bespoke encounter-entry object to fabricate.
            if ![.serialPublisher, .tikTak, .collateral, .splitEdition, .lastEdition].contains(boss) {
                model.qaSetBoss(boss)
            }
            let flipper = PageFlipper()
            let host = UIHostingController(rootView: LiveBossSurface(model: model, flipper: flipper,
                insets: EdgeInsets(top: safeInsets.top, leading: safeInsets.left,
                    bottom: safeInsets.bottom, trailing: safeInsets.right)))
            host.safeAreaRegions = []
            host.view.backgroundColor = .clear
            let start = Date().timeIntervalSince1970
            let initialTurn = try XCTUnwrap(model.puzzle).turnNumber
            window.rootViewController = host
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            print("BOSS_SHOWCASE_START \(boss.rawValue) \(start)")
            try await pause(1.6)
            var actions: [ActionRecord] = []
            func record(_ description: String) {
                actions.append(ActionRecord(time: Date().timeIntervalSince1970, description: description))
            }
            let limitation = try await demonstrate(boss, model: model, record: record)
            // Let the complete production score sequence settle, including its
            // final bank receipt rather than cutting the clip at the action.
            try await pause(4.8)
            model.setClockRunning(false)
            let puzzle = try XCTUnwrap(model.puzzle)
            XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool,
                hand: puzzle.hand + puzzle.markerState.reservedForkCards), boss.name)
            XCTAssertTrue(model.animatesHandArrival)
            let format = UIGraphicsImageRendererFormat()
            format.scale = scene.screen.scale
            let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let poster = XCTAttachment(image: image)
            poster.name = "boss-animation-poster-\(boss.rawValue)"
            poster.lifetime = .keepAlways
            add(poster)
            let segment = Segment(bossID: boss.rawValue, name: boss.name, rule: boss.text,
                start: start, end: Date().timeIntervalSince1970, actions: actions,
                limitation: limitation, width: bounds.width, height: bounds.height,
                initialTurn: initialTurn, finalTurn: puzzle.turnNumber,
                finalScore: puzzle.score, finalPendingPoints: puzzle.pendingBase)
            segments.append(segment)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            print("BOSS_SHOWCASE_SEGMENT " + String(decoding: try encoder.encode(segment), as: UTF8.self))
            model.finishScorePresentation()
            flipper.cancel()
        }
        XCTAssertEqual(segments.map(\.bossID), bosses.map(\.rawValue))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = XCTAttachment(data: try encoder.encode(segments), uniformTypeIdentifier: "public.json")
        metadata.name = "boss-animation-showcase-timeline"
        metadata.lifetime = .keepAlways
        add(metadata)
        print("BOSS_SHOWCASE_COMPLETE \(Date().timeIntervalSince1970)")
    }

    private func demonstrate(_ boss: BossModifier, model: GameModel,
                             record: (String) -> Void) async throws -> String {
        switch boss {
        case .collateral:
            let card = try XCTUnwrap(model.handCards.first)
            record("Select the exact held tile and pledge it for the advertised Turn Mult.")
            model.tapHand(0)
            try await pause(1.0)
            model.pledgeBossCard(card.id, context: try XCTUnwrap(model.bossChoiceContext))
            XCTAssertEqual(model.puzzle?.bossState.encounter.pledgedCard?.id, card.id)
            try await pause(1.5)
            record("Make a real scored placement with the pledged Mult, then bank and return the same tile.")
            try playSquare(8, model: model)
            try await pause(2)
            model.endTurn()
            XCTAssertTrue(model.handCards.contains { $0.id == card.id })
        case .splitEdition:
            record("Choose edition B before playing; the destination locks on the first accepted fill.")
            model.chooseBossEdition(1, context: try XCTUnwrap(model.bossChoiceContext))
            try await pause(1.1)
            for square in [8, 0] { try playSquare(square, model: model); try await pause(0.9) }
            model.endTurn()
            try await pause(2.2)
            record("Choose edition A on the next Turn and print into its separate target.")
            model.chooseBossEdition(0, context: try XCTUnwrap(model.bossChoiceContext))
            for square in [1, 2, 3, 4] { try playSquare(square, model: model); try await pause(0.7) }
            model.endTurn()
            return "Two disclosed 300-point QA targets show allocation in a short recording; real final-stage targets are tested separately. All fills and banks use production actions."
        case .lastEdition:
            record("Prepare Fresh Ink, then make two accepted placements before using the only bank.")
            XCTAssertTrue(model.useBuff(at: 0))
            try await pause(1.0)
            try playSquare(8, model: model)
            try await pause(1.2)
            try playSquare(7, model: model)
            try await pause(1.4)
            XCTAssertEqual(model.puzzle?.phase, .playing, "Passing the score does not bypass the only bank")
            record("Print the only edition; the real bank settles the score and resolves the encounter.")
            model.endTurn()
            XCTAssertEqual(model.puzzle?.bossState.encounter.banksUsed, 1)
            return "Disclosed 400-point QA target demonstrates the press and single-bank victory. Real final-stage difficulty is measured separately."
        case .censor:
            let digit = try XCTUnwrap(model.puzzle?.censoredDigit)
            if let index = model.hand.firstIndex(of: digit),
               let square = model.puzzle?.board.blanks.first(where: { model.puzzle?.board.correctDigit(at: $0) == digit }) {
                record("Play the actually censored \(digit.rawValue); the production receipt stamps its Points to zero.")
                try play(index, square: square, model: model)
            } else {
                record("The rolled censored digit is underlined on the real board; this Hand has no matching copy.")
                return "The actual random censored digit is not held, so this clip shows the standing cue without inventing a card or score receipt."
            }
        case .critic, .returnSlip:
            record("Place a held number on a deliberately incorrect blank; the engine applies the actual penalty.")
            try wrong(model)
            try await pause(2.2)
            record(boss == .returnSlip ? "Bank once; the exact returned copy's seal releases at the Turn boundary." : "Bank once after the doubled wrong-placement penalty.")
            model.endTurn()
        case .mirror:
            record("Fill R1 C1 using the held1, genuinely complete the row, column and box, and show the denied Line Clear receipt.")
            try playSquare(0, model: model)
        case .collector:
            record("QA marks the target met solely to expose the real Results payout. The engine computes cancelled interest from50 held coins.")
            model.qaMeetTarget()
            model.showResults()
            XCTAssertGreaterThan(model.payoutPreview?.suppressedInterest ?? 0, 0)
            return "Target completion is an explicit QA setup, not earned play in this short clip. The displayed interest cancellation and animation are the production payout view."
        case .sashimi:
            record("Place the held1; then bank the actual Bookmark multiplier and show the Budget Cut receipt.")
            try playSquare(0, model: model)
            try await pause(2.4)
            model.endTurn()
        case .overPusher, .grayTheGarry, .garryTheGray, .handyDandy, .unluckyLucky:
            record("End the real Turn; previous blockers or item restrictions settle and the next deterministic selection enters.")
            model.endTurn()
        case .tikTak:
            record("Resume a saved32-second QA checkpoint and let the actual active-play clock cross30 seconds and pulse.")
            try await pause(3.2)
            XCTAssertLessThanOrEqual(model.secondsLeft ?? 100, 30)
            return "The clip begins at a disclosed32-second saved checkpoint. It does not compress or claim to show the complete four-minute clock."
        case .galleyQueue:
            record("Play the oldest held4; the existing1 and9 become the front pair with moving brass brackets.")
            try playSquare(3, model: model)
        case .bookends:
            record("Play held9; both distinct1 copies stay eligible and7 becomes the upper bookend.")
            try playSquare(8, model: model)
        case .reprintBan:
            record("Play one5; the other exact5 copy acquires its repeat-waiting treatment.")
            try playSquare(4, model: model)
        case .rebinder:
            record("Place held7, then bank; the exact remaining cards fly back before a new conserved Hand arrives.")
            try playSquare(6, model: model)
            try await pause(2.4)
            model.endTurn()
        case .lateCourier:
            record("Place1 on Sapphire; a real owed-draw ticket appears instead of an immediate replacement card.")
            try playSquare(0, model: model)
            try await pause(1.8)
            record("Place2 on Sapphire, earning the second delivery request.")
            try playSquare(1, model: model)
            try await pause(2)
            record("Bank; both saved tickets deliver real Pool draws into the Hand.")
            model.endTurn()
        case .collator:
            record("Play1 and then2 from the open packet; the original waiting cards unband after two correct fills.")
            try playSquare(0, model: model)
            try await pause(1.8)
            try playSquare(1, model: model)
        case .pageCutter:
            for index in 0..<4 {
                record("Correct fill\(index + 1) of4; the fourth cuts and automatically banks exactly once.")
                try playSquare(index, model: model)
                if index < 3 { try await pause(1.2) }
            }
            XCTAssertEqual(model.puzzle?.turnNumber, 2)
        case .chainStitcher:
            record("Play1 at R1 C1 to anchor the chain.")
            try playSquare(0, model: model)
            try await pause(1.8)
            record("Play9 at R5 C5 outside the anchor's units; the actual half-Points receipt threads itself.")
            try playSquare(40, model: model)
        case .orphanLine:
            for index in [8, 7, 6] {
                try playSquare(index, model: model)
                try await pause(0.7)
            }
            record("Bank real9,8,7 Points with four leftover cards; the80-Point debit tears the score receipt.")
            model.endTurn()
        case .serialPublisher:
            record("Play Crimson9 with Local Gossip and Sunday; actual1440 pending score exceeds the QA900 target's300 bank cap.")
            try playSquare(8, model: model)
            try await pause(3.3)
            record("Bank300 and save1140 carry; the production settlement receipt bands the held amount.")
            model.endTurn()
            XCTAssertEqual(model.puzzle?.bossState.scoring.serialCarry, 1_140)
            return "Explicit QA starting target900 makes the carry readable in a short clip. All1440 Points and1140 saved carry come from real card/item actions."
        case .bindery:
            record("Play1 to pin Op-Ed then Sunday; the needle follows actual owned Bookmark scoring sources.")
            try playSquare(0, model: model)
            try await pause(2.5)
            record("Bank into Turn2; play2 and show the same pinned copies reading in reverse order.")
            model.endTurn()
            try await pause(2.8)
            try playSquare(1, model: model)
        case .embargo:
            record("Place9; the actual preparation Buff acquires a seal while reactive Rain Check remains available.")
            try playSquare(8, model: model)
        case .dryPress:
            record("Play Golden1; the tiny real ink pad dries after that marked fill.")
            try playSquare(0, model: model)
            try await pause(2)
            record("Play a plain2; the pad visibly re-inks from the accepted unmarked fill.")
            try playSquare(1, model: model)
        case .reviewBoard:
            record("Fill R1 C1 with held1; a real row, column and box complete and receive three approval stamps.")
            try playSquare(0, model: model)
            XCTAssertEqual(model.puzzle?.bossState.reviewApproved.count, 3)
        case .rivalColumn:
            record("Play9 and bank90 to establish the true benchmark.")
            try playSquare(8, model: model)
            try await pause(1.5)
            model.endTurn()
            try await pause(2.4)
            record("Play1 and bank below the benchmark; the actual fee-adjusted settlement is underlined.")
            try playSquare(0, model: model)
            try await pause(1.5)
            model.endTurn()
        case .royaltyContract:
            record("Spend the owned Fresh Ink Buff; the exact5% target increase tucks into the target number.")
            XCTAssertTrue(model.useBuff(at: 0))
            XCTAssertEqual(model.puzzle?.bossState.royaltyCount, 1)
            try await pause(2)
            record("Place9 with the real active Fresh Ink multiplier.")
            try playSquare(8, model: model)
        case .publicist:
            record("Place9; Local Gossip's exact owned copy receives its paid stamp.")
            try playSquare(8, model: model)
            try await pause(2)
            record("Place1; the already-paid copy stays stamped and does not pay again.")
            try playSquare(0, model: model)
        case .wordCount:
            record("Place Crimson9 with Local Gossip; the measuring-edge receipt shows the real150-extra-Points cap.")
            try playSquare(8, model: model)
        case .backPage:
            record("Place1; only the actual score ticket flips to its reversed natural90 value.")
            try playSquare(0, model: model)
        case .editor, .deadline, .paywall, .erratum, .buffborger, .heavyLifter:
            record("Show the production encounter entry on the affected control or target, then make a legal placement.")
            try playAnyLegal(model)
            return "This boss has a restrained one-time object entrance and a persistent restriction, not a continuous character animation."
        case .fog:
            record("Two production mist layers drift below crisp digits; a real legal placement leaves hidden Markers undisclosed.")
            try playAnyLegal(model)
        case .accountant:
            record("Make a legal placement; the actual coin debit prints next to the existing coin total.")
            try playAnyLegal(model)
        }
        return "Deterministic QA board and owned loadout; this is a live production-view recording, not a normal encounter-selection or full-boss-completion claim."
    }

    private func fixture(_ boss: BossModifier) throws -> Game {
        var hand: [Digit] = [.one, .two, .three, .four, .five, .six, .seven]
        var bookmarks: [String] = []
        var markers: [(String, [Int])] = [(Markers.copper, [40]), (Markers.sapphire, [50])]
        var buffs = [Buffs.freshInk, Buffs.peek]
        var blanks: Set<Int>?
        switch boss {
        case .collateral: hand = [.one, .nine, .two, .three, .four, .five, .six]
        case .splitEdition:
            hand = [.nine, .one, .two, .three, .four, .five, .six]
            bookmarks = [Bookmarks.opEd]; markers = []
        case .lastEdition:
            hand = [.nine, .eight, .seven, .six, .five, .four, .three, .two, .one, .eight, .eight]
            bookmarks = [Bookmarks.opEd]; markers = []
        case .galleyQueue: hand = [.four, .one, .nine, .two, .seven, .three, .six]
        case .bookends: hand = [.three, .one, .nine, .one, .six, .seven, .four]
        case .reprintBan: hand = [.five, .five, .two, .three, .seven, .eight, .nine]
        case .rebinder: hand = [.seven, .one, .two, .three, .four, .five, .six]
        case .lateCourier: markers = [(Markers.sapphire, [0, 1])]
        case .chainStitcher: hand = [.one, .nine, .two, .three, .four, .five, .six]
        case .returnSlip: hand = [.one, .one, .nine, .two, .three, .four, .five]
        case .orphanLine: hand = [.nine, .eight, .seven, .six, .one, .two, .three]
        case .serialPublisher:
            hand = [.nine, .one, .two, .three, .four, .five, .six]
            bookmarks = [Bookmarks.localGossip, Bookmarks.theSundaySupplement]
            markers = [(Markers.crimson, [8])]
        case .bindery, .sashimi: bookmarks = [Bookmarks.opEd, Bookmarks.theSundaySupplement]
        case .embargo:
            hand = [.nine, .one, .two, .three, .four, .five, .six]
            buffs = [Buffs.freshInk, Buffs.rainCheck]
        case .dryPress: markers = [(Markers.golden, [0]), (Markers.crimson, [8])]
        case .reviewBoard, .mirror:
            blanks = Set([0, 40, 41, 42, 50, 51, 52, 60, 61, 62])
            hand = [.one, .nine, .one, .two, .four, .five, .six]
            markers = []
        case .rivalColumn, .royaltyContract:
            hand = [.nine, .one, .two, .three, .four, .five, .six]
            markers = []
        case .publicist, .wordCount:
            hand = [.nine, .one, .two, .three, .four, .five, .six]
            bookmarks = [Bookmarks.localGossip]
            markers = boss == .wordCount ? [(Markers.crimson, [8])] : []
        case .unluckyLucky: bookmarks = [Bookmarks.localGossip, Bookmarks.opEd, Bookmarks.theSundaySupplement]
        default: break
        }
        var run = RunState(seed: "boss-live-showcase-\(boss.rawValue)", book: .probably)
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = boss
        run.coins = 50
        run.bookmarks = bookmarks.map { OwnedBookmark(defID: $0, boughtAtLevel: run.level, pricePaid: 0) }
        run.buffs = buffs.map { OwnedBuff(defID: $0, pricePaid: 0) }
        run.markers = markers.map { OwnedMarker(defID: $0.0, boughtAtLevel: run.level,
            pricePaid: 0, squares: $0.1.map(Square.init)) }
        var game = Game(run: run)
        try game.startPuzzle()
        run = game.run
        var puzzle = try XCTUnwrap(game.puzzle)
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        let requiredBlanks: Set<Int> = boss == .chainStitcher ? [40] : []
        let givens = (0..<81).map { index in
            blanks.map { !$0.contains(index) }
                ?? (index >= 9 && index.isMultiple(of: 2) && !requiredBlanks.contains(index))
        }
        _ = puzzle.removeAllHandCards()
        puzzle.board = Board(GeneratedPuzzle(solution: solution, isGiven: givens))
        puzzle.pool = Pool(blanksOf: puzzle.board)
        for digit in hand { XCTAssertTrue(puzzle.pool.take(digit), "Fixture conserves held\(digit.rawValue)") }
        puzzle.appendHandDigits(hand)
        puzzle.handSize = hand.count
        puzzle.boss = boss
        puzzle.bossTurn = nil
        puzzle.blockedDigit = nil
        puzzle.obstacleBlockedDigits = []
        if boss == .serialPublisher { puzzle.target = 900 }
        if boss == .splitEdition { puzzle.target = 600 }
        if boss == .lastEdition { puzzle.target = 400 }
        if boss == .tikTak { puzzle.clockSecondsRemaining = 32 }
        BossRuntime.puzzleStarted(run: run, puzzle: &puzzle)
        BossRuntime.turnStarted(puzzle: &puzzle)
        for index in requiredBlanks { XCTAssertTrue(puzzle.board.isBlank(Square(index))) }
        run.puzzle = puzzle
        MarkerRuntime.synchronizeOwnership(run: &run)
        return Game(run: run)
    }

    private func playSquare(_ index: Int, model: GameModel) throws {
        let square = Square(index)
        let puzzle = try XCTUnwrap(model.puzzle)
        let digit = puzzle.board.correctDigit(at: square) // Test input authoring only.
        let card = try XCTUnwrap(model.hand.indices.first { model.hand[$0] == digit && !model.isBlocked(handIndex: $0) })
        try play(card, square: square, model: model)
    }

    private func play(_ card: Int, square: Square, model: GameModel) throws {
        let before = try XCTUnwrap(model.puzzle)
        XCTAssertTrue(before.board.isBlank(square))
        model.tapHand(card)
        model.tapSquare(square)
        XCTAssertFalse(try XCTUnwrap(model.puzzle).board.isBlank(square), model.message ?? "Placement rejected")
    }

    private func playAnyLegal(_ model: GameModel) throws {
        let puzzle = try XCTUnwrap(model.puzzle)
        for card in model.hand.indices where !model.isBlocked(handIndex: card) {
            if let square = puzzle.board.blanks.first(where: {
                !model.isBarred($0) && puzzle.board.correctDigit(at: $0) == model.hand[card]
            }) {
                try play(card, square: square, model: model)
                return
            }
        }
        XCTFail("Fixture needs one genuinely held legal placement")
    }

    private func wrong(_ model: GameModel) throws {
        let puzzle = try XCTUnwrap(model.puzzle)
        let card = try XCTUnwrap(model.hand.indices.first { !model.isBlocked(handIndex: $0) })
        let square = try XCTUnwrap(puzzle.board.blanks.first {
            !model.isBarred($0) && puzzle.board.correctDigit(at: $0) != model.hand[card]
        })
        model.tapHand(card)
        model.tapSquare(square)
        XCTAssertTrue(try XCTUnwrap(model.puzzle).board.isBlank(square))
        XCTAssertEqual(model.lastOutcome?.correct, false)
    }

    private func pause(_ seconds: Double) async throws {
        try await Task.sleep(for: .seconds(seconds))
    }
}

/// The puzzle is read in body on every model change. Capturing a PuzzleState
/// once outside this view would make the engine advance behind a stale board.
private struct LiveBossSurface: View {
    @Bindable var model: GameModel
    let flipper: PageFlipper
    let insets: EdgeInsets

    var body: some View {
        RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: insets, onTapBuff: { _ in }) {
            if model.page == .results {
                ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
            } else if let puzzle = model.puzzle {
                PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: true)
            }
        }
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
        .environment(\.levelPalette, .forDisplay(slot: .boss))
        .environment(\.scenePhase, .active)
        .environment(\.bossMotionIsActive, true)
        .environment(\.bossEntranceIsDeferred, false)
        .environment(\.gameReduceMotion, false)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, Locale(identifier: "en_US"))
        .ignoresSafeArea()
    }
}
