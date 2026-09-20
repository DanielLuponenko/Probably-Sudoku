import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Review captures use the real full-screen gameplay surface. The shared QA
/// board/loadout makes the visual treatments directly comparable;
/// these are not a claim that final bosses occur in Chapter 1 during a run.
/// Frozen models never write saves or award player/profile progress.
@MainActor
final class BossGalleryCaptureTests: XCTestCase {
    func testCaptureEveryBossOnTheSamePlayableBoardWithoutChangingTheRun() async throws {
        let baseline = try makeBaseline()
        let boardBefore = try boardData(baseline)
        var records: [GalleryRecord] = []

        for (index, boss) in BossModifier.allCases.enumerated() {
            var game = baseline
            game.qaSetBoss(boss)
            XCTAssertEqual(try boardData(game), boardBefore,
                           "Changing a QA boss must not generate a replacement board")
            try assertVisibleEffectIsPresent(game, boss: boss)
            let name = String(format: "boss-gallery-%02d-%@-turn1", index + 1, boss.rawValue)
            records.append(try await capture(game, name: name,
                                             setup: "Shared partially played QA board, first turn; every digit has a printed copy"))
        }

        // The Shredder carries its first three fouls into the following turn.
        // Exercise an actual End Turn, rather than painting six arbitrary cells.
        var shredder = baseline
        shredder.qaSetBoss(.overPusher)
        let firstFouls = Set(try XCTUnwrap(shredder.puzzle?.bossTurn?.fouled).keys)
        _ = try shredder.endTurn()
        let secondFouls = Set(try XCTUnwrap(shredder.puzzle?.bossTurn?.fouled).keys)
        XCTAssertTrue(firstFouls.isSubset(of: secondFouls))
        XCTAssertEqual(secondFouls.count, 6)
        records.append(try await capture(shredder, name: "boss-gallery-20-overPusher-turn2",
                                         setup: "After a real End Turn; three carried fouls plus three new fouls"))

        // A saved clock value is a legitimate rendering state; keep it frozen
        // so the review image cannot spend real time or fail a player's run.
        var timed = baseline
        timed.qaSetBoss(.tikTak)
        var urgentRun = timed.run
        urgentRun.puzzle?.clockSecondsRemaining = 25
        records.append(try await capture(Game(run: urgentRun), name: "boss-gallery-21-tikTak-urgent",
                                         setup: "Saved active-play clock at 25 seconds; ticking paused for capture"))

        XCTAssertEqual(records.prefix(BossModifier.allCases.count).map(\.bossID), BossModifier.allCases.map(\.rawValue))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = XCTAttachment(data: try encoder.encode(records), uniformTypeIdentifier: "public.json")
        metadata.name = "boss-gallery-captions"
        metadata.lifetime = .keepAlways
        add(metadata)
    }

    private func makeBaseline() throws -> Game {
        var run = RunState(seed: "boss-gallery-shared-board-2026-09")
        run.slot = .boss
        run.pendingBoss = .collector
        run.coins = 12
        let bookmarks = Array(Bookmarks.all.prefix(4).map(\.id)) + [Bookmarks.puzzleCorner]
        run.bookmarks = bookmarks.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0) }
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 0),
                     OwnedBuff(defID: "bf_insurance", pricePaid: 0)]
        var game = Game(run: run)
        try game.startPuzzle()
        // A legal Censor roll can select a digit absent from the printed
        // givens. Place a conserved copy of each missing digit on the shared
        // baseline so this visual review actually shows its underline.
        // All bosses retain the same board; no hidden solution is exposed by
        // a view and no engine rule or Censor roll is overwritten.
        for digit in Digit.all {
            let puzzle = try XCTUnwrap(game.puzzle)
            if !Square.all.contains(where: { puzzle.board[$0] == digit }) {
                let square = try XCTUnwrap(puzzle.board.blanks.first {
                    puzzle.board.correctDigit(at: $0) == digit
                })
                XCTAssertTrue(game.qaPlace(digit: digit, at: square))
            }
        }
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        XCTAssertGreaterThan(blanks.count, 20)
        var marked = game.run
        marked.markers = zip(["mk_copper", "mk_sapphire", "mk_crimson"],
                             [blanks[0], blanks[blanks.count / 2], blanks[blanks.count - 1]])
            .map { OwnedMarker(defID: $0.0, boughtAtLevel: 1, pricePaid: 0, squares: [$0.1]) }
        return Game(run: marked)
    }

    private func assertVisibleEffectIsPresent(_ game: Game, boss: BossModifier) throws {
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(puzzle.boss, boss)
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand))
        switch boss {
        case .censor:
            let digit = try XCTUnwrap(puzzle.censoredDigit)
            XCTAssertTrue(Square.all.contains { puzzle.board[$0] == digit })
        case .editor: XCTAssertEqual(puzzle.hand.count, 6)
        case .deadline: XCTAssertEqual(puzzle.turnsMax, 8)
        case .fog:
            XCTAssertEqual(game.run.markers.count, 3)
            XCTAssertTrue(GameModel(frozen: game, page: .puzzle).visibleMarkers.isEmpty)
        case .paywall: XCTAssertEqual(puzzle.cluesRemaining, 0)
        case .erratum: XCTAssertEqual(puzzle.tossesRemaining, 0)
        case .unluckyLucky: XCTAssertNotNil(puzzle.disabledBookmark)
        case .buffborger: XCTAssertEqual(game.run.buffs.count, 2)
        case .overPusher: XCTAssertEqual(puzzle.bossTurn?.fouled.count, 3)
        case .tikTak: XCTAssertEqual(puzzle.clockSecondsRemaining, 240)
        case .handyDandy: XCTAssertEqual(puzzle.bossTurn?.blockedHandIndices.count, 2)
        case .grayTheGarry, .garryTheGray:
            let blocked = try XCTUnwrap(puzzle.bossTurn?.greyed)
            XCTAssertFalse(blocked.isEmpty)
            XCTAssertTrue(blocked.allSatisfy { puzzle.board.isBlank($0) })
        default: break
        }
    }

    private func capture(_ game: Game, name: String, setup: String) async throws -> GalleryRecord {
        let model = GameModel(frozen: game, page: .puzzle)
        let puzzle = try XCTUnwrap(model.puzzle)
        let boss = try XCTUnwrap(puzzle.boss)
        let before = try model.game.encoded()
        let flipper = PageFlipper()
        let ready = expectation(description: name)
        var reported = false
        let size = CGSize(width: 402, height: 874)
        let surface = RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), onTapBuff: { _ in }) {
            PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: false)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { measured in
                    if !reported, measured.width > 0, measured.height > 0 {
                        reported = true
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
        let host = UIHostingController(rootView: surface)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        defer {
            model.setClockRunning(false)
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        window.layoutIfNeeded()
        // Allow hosted preference propagation and the settled brick lifecycle
        // to finish; no engine actions or live clock run during this wait.
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        XCTAssertEqual(image.size, size)
        XCTAssertEqual(try model.game.encoded(), before, "Capturing \(boss.name) must be read-only")
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return GalleryRecord(image: name, bossID: boss.rawValue, name: boss.name, rule: boss.text,
                             setup: setup, turn: puzzle.turnNumber, handCount: puzzle.hand.count,
                             target: puzzle.target, turns: puzzle.turnsMax,
                             barredHandIndices: puzzle.bossTurn?.blockedHandIndices.sorted() ?? [],
                             blockedSquares: (puzzle.bossTurn?.greyed ?? []).map(\.index).sorted(),
                             fouledSquares: (puzzle.bossTurn?.fouled.keys.map { $0.index } ?? []).sorted(),
                             sleepingBookmark: puzzle.disabledBookmark,
                             visibleMarkerCount: model.visibleMarkers.count,
                             discussion: discussion(for: boss))
    }

    private func boardData(_ game: Game) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(XCTUnwrap(game.puzzle?.board))
    }

    private func discussion(for boss: BossModifier) -> String {
        switch boss {
        case .censor: return "Red underlines identify the actual zero-scoring digit. Discuss a physical censor stamp when its score is denied."
        case .editor: return "The missing hand option is the main effect. Discuss a torn empty hand slot rather than adding obstacles to the board."
        case .deadline: return "Eight-turn budget and clock motif. Discuss a paper deadline stamp on turn changes."
        case .fog: return "Mist hides marker locations. Discuss softer moving wisps while keeping every number readable and marker positions secret."
        case .critic: return "Red-pencil accents. Discuss an emphatic double strike only after a wrong placement."
        case .mirror: return "Reflective edge motif. Discuss a mirrored or struck-through line-clear receipt when the bonus is denied."
        case .paywall: return "Clue access is disabled. Discuss a tactile locked seal over the clue source; the board remains playable."
        case .erratum: return "Toss is unavailable. Discuss a correction strip across its button."
        case .collector: return "Interest is removed at payout. Discuss a receipt stamp on the Results interest line."
        case .heavyLifter: return "Fourfold target. Discuss a heavy press impression behind the target, without reducing board contrast."
        case .unluckyLucky: return "One actual triggered Bookmark sleeps. Discuss folding its corner and a small sleeping mark on that exact item."
        case .buffborger: return "Both owned Buffs are unusable. Discuss removable paper seals on those two slots."
        case .sashimi: return "Multipliers are halved. Discuss a clean scissor cut through the multiplier during scoring."
        case .overPusher: return "Ink fouls mark real blocked blanks. Discuss individual wet splats that dry and clear when their two-turn lifetime ends."
        case .accountant: return "Every placement costs a coin. Discuss a small debit receipt moving from that placement to the coin total."
        case .tikTak: return "Real countdown, plus urgent state below 30 seconds. Discuss clock-hand motion and a restrained urgent pulse."
        case .handyDandy: return "Two exact hand copies are crossed out. Discuss physical tags on those cards, keeping the remaining hand readable."
        case .grayTheGarry: return "Physical bricks occupy only the barred row's blank cells. Review stagger, landing weight and fading dust."
        case .garryTheGray: return "Physical bricks occupy only the barred box's blank cells. Review stagger, landing weight and fading dust."
        default: return boss.text + " Review the affected object and its committed-action feedback."
        }
    }
}

private struct GalleryRecord: Codable {
    let image: String
    let bossID: String
    let name: String
    let rule: String
    let setup: String
    let turn: Int
    let handCount: Int
    let target: Int
    let turns: Int
    let barredHandIndices: [Int]
    let blockedSquares: [Int]
    let fouledSquares: [Int]
    let sleepingBookmark: Int?
    let visibleMarkerCount: Int
    let discussion: String
}
