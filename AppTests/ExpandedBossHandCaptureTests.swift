import XCTest
import SwiftUI
import UIKit
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

/// Settled before/after captures of actual engine actions, not animation or
/// device-performance evidence. Metadata preserves the complete public board,
/// exact Hand identities and mechanical state that produced each image.
@MainActor
final class ExpandedBossHandCaptureTests: XCTestCase {
    private struct Stage {
        var game: Game
        var label: String
        var caption: String
    }
    private struct CaptureRecord: Codable {
        var image: String
        var boss: String
        var stage: String
        var caption: String
        var viewport: String
        var turn: Int
        var turnsMax: Int
        var phase: String
        var score: Int
        var pendingPoints: Int
        var target: Int
        var hand: [Int]
        var handIDs: [String]
        var placed: [Int?]
        var given: [Bool]
        var blockedCardIDs: [String]
        var state: ExpandedBossState
        var ledger: ScoreLedger?
    }
    private let bosses: [BossModifier] = [.galleyQueue, .bookends, .reprintBan, .rebinder,
        .lateCourier, .collator, .pageCutter, .returnSlip, .reviewBoard]

    func testCaptureHandBossTriggersFromConservedActionsAt390By844() async throws {
        var records: [CaptureRecord] = []
        for boss in bosses {
            let stages = try scenario(boss)
            XCTAssertGreaterThanOrEqual(stages.count, 2)
            for stage in stages {
                try assertConservationAndRestore(stage.game)
                records.append(try await capture(stage))
            }
        }
        XCTAssertEqual(records.count, 20)
        XCTAssertEqual(Set(records.map(\.boss)), Set(bosses.map(\.rawValue)))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let attachment = XCTAttachment(data: try encoder.encode(records), uniformTypeIdentifier: "public.json")
        attachment.name = "expandedboss-hand-captions"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scenario(_ boss: BossModifier) throws -> [Stage] {
        var game: Game
        switch boss {
        case .galleyQueue:
            game = try fixture(boss, hand: [.four, .one, .nine, .two, .seven, .three, .six])
            let before = game, original = game.puzzle!.handCards
            _ = try place(3, in: &game)
            let eligible = game.puzzle!.handCards.enumerated().filter { !game.puzzle!.isBlocked(handIndex: $0.offset) }.map { $0.element.id }
            XCTAssertEqual(eligible, [original[1].id, original[2].id])
            return [.init(game: before, label: "before", caption: "The actual two oldest cards are 4 and 1."),
                    .init(game: game, label: "after", caption: "Played the oldest 4 in R1 C4; existing 1 and 9 become the front pair, without a redraw.")]
        case .bookends:
            game = try fixture(boss, hand: [.three, .one, .nine, .one, .six, .seven, .four])
            let before = game
            _ = try place(8, in: &game)
            let eligible = game.puzzle!.hand.indices.filter { !game.puzzle!.isBlocked(handIndex: $0) }.map { game.puzzle!.hand[$0] }
            XCTAssertEqual(eligible, [.one, .one, .seven])
            return [.init(game: before, label: "before", caption: "Both distinct 1 copies and the 9 are legal extremes."),
                    .init(game: game, label: "after", caption: "Played 9 in R1 C9; both 1 copies stay legal and 7 becomes the high extreme.")]
        case .reprintBan:
            game = try fixture(boss, hand: [.five, .five, .two, .three, .seven, .eight, .nine])
            let before = game
            _ = try place(4, in: &game)
            XCTAssertEqual(game.puzzle!.bossState.usedDigits, [.five])
            XCTAssertTrue(game.puzzle!.isBlocked(handIndex: 0))
            return [.init(game: before, label: "before", caption: "No digit has yet been filled this Turn; both 5 copies are available."),
                    .init(game: game, label: "after", caption: "A correct 5 in R1 C5 marks 5 used; its other copy waits while visible unused values remain.")]
        case .rebinder:
            game = try fixture(boss, hand: [.seven, .one, .two, .three, .four, .five, .six])
            _ = try place(6, in: &game)
            let before = game, oldIDs = Set(game.puzzle!.handCardIDs)
            let turn = try game.endTurn()
            XCTAssertEqual(turn.pointsGained, 70)
            XCTAssertEqual(game.puzzle!.hand.count, 7)
            XCTAssertTrue(oldIDs.isDisjoint(with: game.puzzle!.handCardIDs))
            return [.init(game: before, label: "before", caption: "A legal 7 earned 70 Points; six exact leftover cards await End Turn."),
                    .init(game: game, label: "after", caption: "End Turn banked 70, returned those six cards to the Pool and drew a conserved fresh Hand with new identities.")]
        case .lateCourier:
            game = try fixture(boss, hand: [.one, .two, .three, .four, .five, .six, .seven],
                               markers: [(Markers.sapphire, [0, 1])])
            let before = game
            _ = try place(0, in: &game); _ = try place(1, in: &game)
            XCTAssertEqual(game.puzzle!.bossState.deferredDraws.reduce(0) { $0 + $1.count }, 2)
            XCTAssertEqual(game.puzzle!.hand.count, 5)
            let waiting = game
            let turn = try game.endTurn()
            XCTAssertEqual(turn.numbersDrawn, 2)
            XCTAssertEqual(game.puzzle!.hand.count, 7)
            XCTAssertTrue(game.puzzle!.bossState.deferredDraws.isEmpty)
            return [.init(game: before, label: "before", caption: "Two real Sapphire claims can earn automatic draws; neither has triggered."),
                    .init(game: waiting, label: "deferred", caption: "Correct 1 and 2 placements earned two saved delivery requests. Five cards remain in Hand; no replacement digit was removed from the Pool yet."),
                    .init(game: game, label: "delivered", caption: "After banking 30, both owed Pool draws arrived. They filled the two empty slots, so ordinary refill drew zero extra cards.")]
        case .collator:
            game = try fixture(boss, hand: [.one, .two, .three, .four, .five, .six, .seven])
            let before = game
            _ = try place(0, in: &game); _ = try place(1, in: &game)
            XCTAssertEqual(game.puzzle!.bossState.correctFills, 2)
            XCTAssertTrue(game.puzzle!.bossState.waitingIDs.isEmpty)
            return [.init(game: before, label: "before", caption: "The four oldest cards form the open packet; the remaining three exact copies wait."),
                    .init(game: game, label: "after", caption: "Two correct fills open the original waiting packet, with no added cards and no Turn advance.")]
        case .pageCutter:
            game = try fixture(boss, hand: [.one, .two, .three, .four, .five, .six, .seven])
            for index in 0..<3 { _ = try place(index, in: &game) }
            let before = game
            let fourth = try place(3, in: &game)
            XCTAssertEqual(before.puzzle!.bossState.correctFills, 3)
            XCTAssertNotNil(fourth.automaticTurn)
            XCTAssertEqual(game.puzzle!.turnNumber, 2)
            XCTAssertEqual(game.puzzle!.score, 100)
            XCTAssertEqual(game.puzzle!.bossState.correctFills, 0)
            return [.init(game: before, label: "before", caption: "Three actual fills earned 60 Points. The fourth fill will bank this Turn; the initial +4 Turn allowance is already applied."),
                    .init(game: game, label: "after", caption: "Correct 4 in R1 C4 finished the batch. One bank awarded 100 total Points, refilled once and reset the fill counter.")]
        case .returnSlip:
            game = try fixture(boss, hand: [.nine, .one, .one, .two, .three, .four, .five])
            _ = try place(8, in: &game)
            let before = game, cardID = game.puzzle!.handCardIDs[0]
            let wrong = try game.place(handIndex: 0, at: Square(1))
            XCTAssertFalse(wrong.correct); XCTAssertEqual(wrong.penalty, 50)
            XCTAssertEqual(game.puzzle!.bossState.sealedIDs, [cardID])
            XCTAssertEqual(game.puzzle!.handCardIDs.filter { $0 == cardID }.count, 1)
            let sealed = game
            _ = try game.endTurn()
            XCTAssertTrue(game.puzzle!.bossState.sealedIDs.isEmpty)
            XCTAssertTrue(game.puzzle!.handCardIDs.contains(cardID))
            return [.init(game: before, label: "before", caption: "A correct 9 earned 90 Points; two separate 1 copies remain in Hand."),
                    .init(game: sealed, label: "sealed", caption: "A wrong 1 at R1 C2 paid the real 50-Point penalty and returned that exact card sealed. Its duplicate remains open; the wrong square is blank."),
                    .init(game: game, label: "unsealed", caption: "End Turn banked the remaining 40 Points. The same returned card unsealed without changing its identity or digit.")]
        case .reviewBoard:
            let blanks = Set([0, 40, 41, 42, 50, 51, 52, 60, 61, 62])
            game = try fixture(boss, hand: [.one, .nine, .one, .two, .four, .five, .six],
                               blanks: blanks, target: 50)
            _ = try place(40, in: &game)
            _ = try game.endTurn()
            XCTAssertGreaterThanOrEqual(game.puzzle!.score, 50)
            XCTAssertEqual(game.puzzle!.phase, .playing)
            XCTAssertEqual(game.puzzle!.bossState.reviewApproved, [.col])
            let before = game, score = game.puzzle!.score
            let clue = try game.useClue(at: Square(0))
            XCTAssertEqual(Set(clue.lineClears.map(\.rawValue)), ["row", "col", "box"])
            _ = try game.endTurn()
            XCTAssertEqual(game.puzzle!.phase, .won)
            XCTAssertEqual(game.puzzle!.score, score, "Clue approvals do not invent score")
            return [.init(game: before, label: "before", caption: "The target is already banked and column 5 is actually complete, but row and box approval are still missing."),
                    .init(game: game, label: "after", caption: "A real Clue filled R1 C1 and completed its row, column and box. Banking awarded no Clue points; the already-earned target now passes review.")]
        default: throw NSError(domain: "ExpandedBossHandCapture", code: 1)
        }
    }

    private func fixture(_ boss: BossModifier, hand: [Digit], markers: [(String, [Int])] = [],
                         blanks: Set<Int>? = nil, target: Int = 100_000) throws -> Game {
        var run = RunState(seed: "boss-hand-captures-20260920", book: .noPressure)
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss; run.pendingBoss = boss; run.coins = 12
        run.markers = markers.map { OwnedMarker(defID: $0.0, boughtAtLevel: run.level,
                                               pricePaid: 0, squares: $0.1.map(Square.init)) }
        var game = Game(run: run); try game.startPuzzle(); run = game.run
        var p = try XCTUnwrap(game.puzzle)
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        // A known valid Sudoku givens fixture, not a player-facing solution.
        // The first row stays blank for explicit Hand-trigger actions.
        let givens = (0..<81).map { index in
            blanks.map { !$0.contains(index) } ?? (index >= 9 && index.isMultiple(of: 2))
        }
        _ = p.removeAllHandCards()
        p.board = Board(GeneratedPuzzle(solution: solution, isGiven: givens))
        p.pool = Pool(blanksOf: p.board)
        for digit in hand { XCTAssertTrue(p.pool.take(digit), "Every requested Hand copy must exist in this board's Pool") }
        p.appendHandDigits(hand)
        p.handSize = hand.count; p.target = target; p.cluesRemaining = 3
        p.boss = boss; p.bossTurn = nil; p.blockedDigit = nil; p.obstacleBlockedDigits = []
        BossRuntime.puzzleStarted(run: run, puzzle: &p)
        BossRuntime.turnStarted(puzzle: &p)
        run.puzzle = p
        MarkerRuntime.synchronizeOwnership(run: &run)
        XCTAssertTrue(BossEligibility.isEligible(boss, run: run, board: p.board))
        return Game(run: run)
    }

    private func place(_ index: Int, in game: inout Game) throws -> PlacementOutcome {
        let p = try XCTUnwrap(game.puzzle), square = Square(index)
        let digit = p.board.correctDigit(at: square) // Fixture authoring only.
        let cardIndex = try XCTUnwrap(p.hand.firstIndex(of: digit))
        return try game.place(handIndex: cardIndex, at: square)
    }

    private func assertConservationAndRestore(_ game: Game) throws {
        let p = try XCTUnwrap(game.puzzle)
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool,
                                       hand: p.hand + p.markerState.reservedForkCards))
        let bytes = try game.encoded(), restored = try Game(decoding: bytes)
        XCTAssertEqual(try restored.encoded(), bytes)
        XCTAssertEqual(restored.puzzle!.handCards, p.handCards)
    }

    private func capture(_ stage: Stage) async throws -> CaptureRecord {
        let model = GameModel(frozen: stage.game, page: .puzzle)
        let p = try XCTUnwrap(model.puzzle), boss = try XCTUnwrap(p.boss)
        let name = "expandedboss-hand-\(boss.rawValue)-\(stage.label)-390x844"
        let saved = try model.game.encoded(), size = CGSize(width: 390, height: 844)
        let ready = expectation(description: name)
        var reported = false
        let flipper = PageFlipper()
        let surface = RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0), onTapBuff: { _ in }) {
            PuzzlePageView(model: model, puzzle: p, isClockRunning: false)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { measured in
                    if !reported, measured.width > 0, measured.height > 0 {
                        reported = true
                        XCTAssertLessThanOrEqual(measured.width, size.width)
                        XCTAssertLessThanOrEqual(measured.height, size.height)
                        ready.fulfill()
                    }
                }
        }
        .frame(width: size.width, height: size.height)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
        .environment(\.levelPalette, .forDisplay(slot: .boss))
        .environment(\.scenePhase, .inactive)
        .environment(\.bossMotionIsActive, false)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: surface); host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size); window.rootViewController = host
        defer {
            model.setClockRunning(false); flipper.cancel()
            window.isHidden = true; window.rootViewController = nil; previous?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(try model.game.encoded(), saved)
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        return CaptureRecord(image: name, boss: boss.rawValue, stage: stage.label, caption: stage.caption,
            viewport: "390x844", turn: p.turnNumber, turnsMax: p.turnsMax, phase: p.phase.rawValue,
            score: p.score, pendingPoints: p.pendingBase, target: p.target,
            hand: p.hand.map(\.rawValue), handIDs: p.handCards.map { $0.id.uuidString },
            placed: p.board.placed.map { $0?.rawValue }, given: p.board.isGiven,
            blockedCardIDs: p.handCards.enumerated().filter { p.isBlocked(handIndex: $0.offset) }.map { $0.element.id.uuidString },
            state: p.bossState, ledger: p.lastScoringLedger)
    }
}
