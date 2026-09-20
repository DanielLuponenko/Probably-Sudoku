import XCTest
import SwiftUI
import UIKit
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

/// Each pair demonstrates a real accepted action on a conserved puzzle. The
/// initial board/Hand/target are explicit QA fixtures; earned points, carry,
/// source receipts and restrictions are never fabricated for a screenshot.
@MainActor
final class ExpandedBossCaptureTests: XCTestCase {
    private struct Scenario {
        var before: Game
        var after: Game
        var caption: String
        var operations: [ScoreOperation]
    }

    private struct CaptureRecord: Codable {
        var image: String
        var boss: String
        var stage: String
        var caption: String
        var viewport: String
        var textSize: String
        var turn: Int
        var score: Int
        var pendingPoints: Int
        var target: Int
        var phase: String
        var carry: Int
        var remainingExtraPoints: Int
        var hand: [Int]
        var handIDs: [String]
        var placed: [Int?]
        var bookmarks: [String]
        var buffs: [String]
        var operations: [ScoreOperation]
    }

    private let bosses: [BossModifier] = [.chainStitcher, .orphanLine, .serialPublisher,
        .bindery, .dryPress, .rivalColumn, .publicist, .wordCount, .backPage,
        .embargo, .royaltyContract]

    func testCaptureScoringBossTriggersFromRealConservedActionsAtThreePhoneSizes() async throws {
        var records: [CaptureRecord] = []
        for boss in bosses {
            do {
                let scenario = try makeScenario(boss)
                try assertSavedState(scenario.before)
                try assertSavedState(scenario.after)
                for size in [CGSize(width: 375, height: 667), CGSize(width: 390, height: 844),
                             CGSize(width: 430, height: 932)] {
                    for (stage, game) in [("before", scenario.before), ("after", scenario.after)] {
                        records.append(try await capture(game, stage: stage, size: size, type: .large,
                            caption: scenario.caption, operations: scenario.operations))
                    }
                }
                // Long names plus state-dependent copy get a genuine enlarged
                // text environment, with the same earned gameplay state.
                if [.serialPublisher, .chainStitcher, .royaltyContract].contains(boss) {
                    for size in [CGSize(width: 375, height: 667), CGSize(width: 430, height: 932)] {
                        records.append(try await capture(scenario.after, stage: "after", size: size,
                            type: .accessibility3, caption: scenario.caption, operations: scenario.operations))
                    }
                }
                if boss == .serialPublisher {
                    var completed = scenario.after
                    _ = try completed.endTurn()
                    _ = try completed.endTurn()
                    XCTAssertEqual(completed.puzzle?.phase, .won)
                    XCTAssertEqual(completed.puzzle?.score, 900)
                    XCTAssertEqual(completed.puzzle?.bossState.scoring.serialCarry, 540)
                    try completed.keepFilling()
                    // Play only cards genuinely held after those banks. No
                    // QA placement helper supplies, swaps or invents a card.
                    while let puzzle = completed.puzzle, !puzzle.board.isFull {
                        XCTAssertEqual(puzzle.phase, .keepFilling)
                        let card = try XCTUnwrap(puzzle.hand.first)
                        let square = try XCTUnwrap(puzzle.board.blanks.first { puzzle.board.correctDigit(at: $0) == card })
                        _ = try completed.place(handIndex: 0, at: square)
                    }
                    XCTAssertEqual(completed.puzzle?.phase, .won)
                    XCTAssertEqual(completed.puzzle?.score, 1_440)
                    XCTAssertEqual(completed.puzzle?.bossState.scoring.serialCarry, 0)
                    try assertSavedState(completed)
                    records.append(try await capture(completed, stage: "full-clear", size: CGSize(width: 390, height: 844),
                        type: .large,
                        caption: "Two further ordinary empty banks reach900 and leave540 earned carry. Real held cards fill every remaining square during Keep Filling; Full Clear pays only that540, producing1440 exactly once. New placements stay frozen.",
                        operations: completed.puzzle?.lastScoringLedger?.operations ?? []))
                }
            } catch {
                XCTFail("\(boss.name) capture failed: \(error)")
            }
        }
        XCTAssertEqual(records.count, bosses.count * 6 + 7)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = XCTAttachment(data: try encoder.encode(records), uniformTypeIdentifier: "public.json")
        metadata.name = "expandedboss-scoring-captions"
        metadata.lifetime = .keepAlways
        add(metadata)
    }

    private func makeScenario(_ boss: BossModifier) throws -> Scenario {
        var game: Game
        var receipts: [ScoreOperation] = []
        let before: Game
        let caption: String
        switch boss {
        case .chainStitcher:
            game = try fixture(boss, hand: [.one, .nine, .two, .three, .four, .five, .six])
            _ = try place(0, game: &game)
            before = game
            let result = try place(40, game: &game)
            XCTAssertEqual(result.points, 45)
            XCTAssertEqual(game.puzzle?.bossState.scoring.chainAnchor, Square(40))
            receipts = result.scoreReceipts.flatMap(\.operations)
            XCTAssertTrue(receipts.contains { $0.sourceID == "boss.\(boss.rawValue)" && $0.kind == .multiplyPoints })
            caption = "A real natural1 at r1c1 anchors the chain. A natural9 at r5c5 shares no unit:90 becomes45; the anchor moves to r5c5."
        case .orphanLine:
            game = try fixture(boss, hand: [.nine, .eight, .seven, .six, .one, .two, .three])
            for square in [8, 7, 6] { _ = try place(square, game: &game) }
            before = game
            XCTAssertEqual(game.puzzle?.pendingBase, 240)
            XCTAssertEqual(game.puzzle?.hand.count, 4)
            let bank = try game.endTurn()
            XCTAssertEqual(bank.pointsGained, 160)
            receipts = try XCTUnwrap(bank.scoringLedger).operations
            caption = "Real9,8,7 placements earn240 Points. Four retained cards cost80 before Mult; End Turn banks160 and refills once."
        case .serialPublisher:
            game = try fixture(boss, hand: [.nine, .one, .two, .three, .four, .five, .six],
                bookmarks: [Bookmarks.localGossip, Bookmarks.theSundaySupplement],
                markers: [(Markers.crimson, 8)], target: 900)
            _ = try place(8, game: &game)
            before = game
            let bank = try game.endTurn()
            XCTAssertEqual(bank.pointsGained, 300)
            XCTAssertEqual(game.puzzle?.bossState.scoring.serialCarry, 1_140)
            receipts = try XCTUnwrap(bank.scoringLedger).operations
            caption = "Controlled QA starting target900. Crimson9 plus Local Gossip earns480 Points; Sunday ×3 produces1440. End Turn pays300 and saves1140 carry, without winning."
        case .bindery:
            game = try fixture(boss, hand: [.one, .two, .three, .four, .five, .six, .seven],
                bookmarks: [Bookmarks.opEd, Bookmarks.theSundaySupplement])
            _ = try place(0, game: &game)
            before = game
            XCTAssertEqual(game.puzzle?.pendingMultiplier, 6)
            let order = game.run.bookmarks.map(\.id)
            _ = try game.endTurn()
            let result = try place(1, game: &game)
            XCTAssertEqual(game.puzzle?.pendingMultiplier, 4)
            XCTAssertEqual(game.run.bookmarks.map(\.id), order)
            XCTAssertEqual(game.puzzle?.bossState.scoring.binderyOrder, order)
            receipts = result.scoreReceipts.flatMap(\.operations) + (game.puzzle?.pendingScoringLedger.operations ?? [])
            caption = "Op-Ed then Sunday stays physically pinned. Turn1 reads(1+1)×3=6; after a real bank, Turn2 reads1×3+1=4. Both Turns contain actual placements."
        case .dryPress:
            game = try fixture(boss, hand: [.one, .nine, .two, .three, .four, .five, .six],
                markers: [(Markers.golden, 0), (Markers.crimson, 8)])
            before = game
            let first = try place(0, game: &game)
            let second = try place(8, game: &game)
            XCTAssertEqual(first.points, 110)
            XCTAssertEqual(second.points, 90)
            XCTAssertFalse(try XCTUnwrap(game.puzzle).bossState.scoring.dryPressReady)
            receipts = first.scoreReceipts.flatMap(\.operations) + second.scoreReceipts.flatMap(\.operations)
            caption = "Golden1 earns110 and dries the press. The following marked9 remains legal and earns its natural90; Crimson's immediate ×4 sleeps while plain blanks remain."
        case .rivalColumn:
            game = try fixture(boss, hand: [.nine, .one, .two, .three, .four, .five, .six])
            _ = try place(8, game: &game)
            _ = try game.endTurn()
            _ = try place(0, game: &game)
            before = game
            XCTAssertEqual(game.puzzle?.bossState.scoring.rivalBenchmark, 90)
            let bank = try game.endTurn()
            XCTAssertEqual(bank.pointsGained, 8)
            XCTAssertEqual(game.puzzle?.score, 98)
            XCTAssertEqual(game.puzzle?.bossState.scoring.rivalBenchmark, 10)
            receipts = try XCTUnwrap(bank.scoringLedger).operations
            caption = "First natural9 bank sets benchmark90. A real natural1 queues10 next Turn; its bank pays8 after a2-point fee and stores the untaxed10 as the next benchmark."
        case .publicist:
            game = try fixture(boss, hand: [.nine, .one, .two, .three, .four, .five, .six],
                bookmarks: [Bookmarks.localGossip])
            before = game
            let first = try place(8, game: &game)
            let second = try place(0, game: &game)
            XCTAssertEqual(first.points, 120)
            XCTAssertEqual(second.points, 10)
            XCTAssertEqual(game.puzzle?.bossState.scoring.publicistPaid, Set(game.run.bookmarks.map(\.id)))
            receipts = first.scoreReceipts.flatMap(\.operations) + second.scoreReceipts.flatMap(\.operations)
            caption = "Local Gossip's owned copy pays30 on the first natural9. A second natural1 earns10; that same copy's flat bonus has already paid this Turn."
        case .wordCount:
            game = try fixture(boss, hand: [.nine, .one, .two, .three, .four, .five, .six],
                bookmarks: [Bookmarks.localGossip], markers: [(Markers.crimson, 8)])
            before = game
            let result = try place(8, game: &game)
            XCTAssertEqual(result.points, 240)
            XCTAssertEqual(game.puzzle?.bossState.scoring.wordCountSpent, 150)
            XCTAssertEqual(game.puzzle?.buffState.pointLots.reduce(0) { $0 + $1.remaining }, 240)
            receipts = result.scoreReceipts.flatMap(\.operations)
            caption = "Crimson9 with Local Gossip would earn480. Word Count preserves natural90 and admits150 extra, queuing240 and spending the allowance once."
        case .backPage:
            game = try fixture(boss, hand: [.one, .nine, .two, .three, .four, .five, .six],
                markers: [(Markers.violet, 8)])
            before = game
            let first = try place(0, game: &game)
            let second = try place(8, game: &game)
            XCTAssertEqual(first.points, 90)
            XCTAssertEqual(second.points, 90)
            receipts = first.scoreReceipts.flatMap(\.operations) + second.scoreReceipts.flatMap(\.operations)
            caption = "A real1 earns reversed natural90. A real9 on Violet starts at reversed10, then Violet explicitly restores90. Board and Hand digits are never changed."
        case .embargo:
            game = try fixture(boss, hand: [.nine, .one, .two, .three, .four, .five, .six],
                buffs: [Buffs.freshInk, Buffs.rainCheck])
            before = game
            XCTAssertFalse(BuffRuntime.options(for: Buffs.freshInk, run: game.run).isEmpty)
            let result = try place(8, game: &game)
            XCTAssertTrue(BuffRuntime.options(for: Buffs.freshInk, run: game.run).isEmpty)
            XCTAssertFalse(BuffRuntime.options(for: Buffs.rainCheck, run: game.run).isEmpty)
            XCTAssertEqual(game.run.buffs.map(\.id), before.run.buffs.map(\.id))
            receipts = result.scoreReceipts.flatMap(\.operations)
            caption = "An accepted natural9 closes preparation for this Turn. Fresh Ink is sealed, reactive Rain Check stays available against90 genuinely earned eligible Points, and neither held Buff is consumed."
        case .royaltyContract:
            game = try fixture(boss, hand: [.nine, .one, .two, .three, .four, .five, .six],
                buffs: [Buffs.freshInk, Buffs.peek], target: 1_000)
            before = game
            let source = try XCTUnwrap(game.run.buffs.first)
            XCTAssertEqual(try game.beginBuff(id: source.id).consumedID, source.id)
            XCTAssertEqual(game.puzzle?.target, 1_050)
            XCTAssertEqual(game.puzzle?.bossState.royaltyCount, 1)
            let result = try place(8, game: &game)
            XCTAssertEqual(game.puzzle?.pendingScore, 270)
            receipts = result.scoreReceipts.flatMap(\.operations) + (game.puzzle?.pendingScoringLedger.operations ?? [])
            XCTAssertTrue(receipts.contains { $0.sourceInstanceID == source.id.uuidString })
            caption = "Controlled QA starting target1000. Spending one owned Fresh Ink adds50 to target exactly once. Its real +2 Mult remains active: a subsequent natural9 previews270. Peek remains held."
        default: throw NSError(domain: "ExpandedBossCapture", code: 1)
        }
        return Scenario(before: before, after: game, caption: caption, operations: receipts)
    }

    private func fixture(_ boss: BossModifier, hand: [Digit], bookmarks: [String] = [],
                         markers: [(String, Int)] = [], buffs: [String] = [], target: Int = 10_000) throws -> Game {
        var run = RunState(seed: "expanded-boss-capture-\(boss.rawValue)", book: .probably)
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = boss
        run.bookmarks = bookmarks.enumerated().map {
            OwnedBookmark(defID: $0.element, boughtAtLevel: run.level, pricePaid: 0,
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", $0.offset + 1))!)
        }
        run.buffs = buffs.map { OwnedBuff(defID: $0, pricePaid: 0) }
        run.markers = markers.map { OwnedMarker(defID: $0.0, boughtAtLevel: run.level, pricePaid: 0, squares: [Square($0.1)]) }
        var game = Game(run: run)
        try game.startPuzzle()
        run = game.run
        var puzzle = try XCTUnwrap(game.puzzle)
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        let requiredBlanks: Set<Int> = [0, 1, 6, 7, 8, 40, 41]
        let givens = (0..<81).map { !$0.isMultiple(of: 2) && !requiredBlanks.contains($0) }
        _ = puzzle.removeAllHandCards()
        puzzle.board = Board(GeneratedPuzzle(solution: solution, isGiven: givens))
        puzzle.pool = Pool(blanksOf: puzzle.board)
        for digit in hand { XCTAssertTrue(puzzle.pool.take(digit), "Fixture must conserve every planned card") }
        puzzle.appendHandDigits(hand)
        puzzle.handSize = hand.count
        puzzle.target = target
        puzzle.turnsMax = 10
        puzzle.boss = boss
        puzzle.bossTurn = nil
        puzzle.blockedDigit = nil
        puzzle.obstacleBlockedDigits = []
        BossRuntime.puzzleStarted(run: run, puzzle: &puzzle)
        BossRuntime.turnStarted(puzzle: &puzzle)
        run.puzzle = puzzle
        MarkerRuntime.synchronizeOwnership(run: &run)
        XCTAssertTrue(BossEligibility.isEligible(boss, run: run, board: puzzle.board),
                      "Each captured boss needs a loadout where its rule can actually operate")
        return Game(run: run)
    }

    private func place(_ index: Int, game: inout Game) throws -> PlacementOutcome {
        let puzzle = try XCTUnwrap(game.puzzle)
        let square = Square(index)
        let digit = puzzle.board.correctDigit(at: square) // Test setup only; never a player-facing preview.
        let card = try XCTUnwrap(puzzle.hand.firstIndex(of: digit), "The planned card must already be held")
        return try game.place(handIndex: card, at: square)
    }

    private func assertSavedState(_ game: Game) throws {
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool,
            hand: puzzle.hand + puzzle.markerState.reservedForkCards))
        let bytes = try game.encoded()
        let restored = try Game(decoding: bytes)
        XCTAssertEqual(try restored.encoded(), bytes)
        XCTAssertEqual(restored.puzzle?.bossState.scoring, puzzle.bossState.scoring)
        XCTAssertEqual(restored.puzzle?.lastScoringLedger, puzzle.lastScoringLedger)
        XCTAssertEqual(restored.puzzle?.phase, puzzle.phase)
        XCTAssertEqual(restored.puzzle?.score, puzzle.score)
    }

    private func capture(_ game: Game, stage: String, size: CGSize, type: DynamicTypeSize,
                         caption: String, operations: [ScoreOperation]) async throws -> CaptureRecord {
        let model = GameModel(frozen: game, page: game.puzzle?.phase == .won ? .results : .puzzle)
        let puzzle = try XCTUnwrap(model.puzzle)
        let boss = try XCTUnwrap(puzzle.boss)
        let viewport = "\(Int(size.width))x\(Int(size.height))"
        let textSize = type.isAccessibilitySize ? "AX3" : "large"
        let name = "expandedboss-\(boss.rawValue)-\(stage)-\(viewport)-\(textSize)"
        let saved = try model.game.encoded()
        let ready = expectation(description: name)
        var reported = false
        let flipper = PageFlipper()
        let surface = RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: EdgeInsets(top: size.height < 700 ? 20 : 59, leading: 0,
            bottom: size.height < 700 ? 0 : 34, trailing: 0), onTapBuff: { _ in }) {
            Group {
                if puzzle.phase == .won {
                    ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
                } else {
                    PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: false)
                }
            }
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
        .environment(\.dynamicTypeSize, type)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: surface)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        defer {
            model.setClockRunning(false)
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(try model.game.encoded(), saved, "Rendering may not change the saved boss encounter")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return CaptureRecord(image: name, boss: boss.rawValue, stage: stage, caption: caption,
            viewport: viewport, textSize: textSize, turn: puzzle.turnNumber, score: puzzle.score,
            pendingPoints: puzzle.pendingBase, target: puzzle.target, phase: puzzle.phase.rawValue,
            carry: puzzle.bossState.scoring.serialCarry,
            remainingExtraPoints: max(0, 150 - puzzle.bossState.scoring.wordCountSpent),
            hand: puzzle.hand.map(\.rawValue), handIDs: puzzle.handCards.map { $0.id.uuidString },
            placed: puzzle.board.placed.map { $0?.rawValue }, bookmarks: game.run.bookmarks.map(\.defID),
            buffs: game.run.buffs.map(\.defID), operations: operations)
    }
}
