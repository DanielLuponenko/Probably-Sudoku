import XCTest
import SwiftUI
import UIKit
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

/// Supplemental recording: the random Censor roll remains authoritative.
/// Only the QA Hand is arranged, by transferring conserved Pool copies.
@MainActor
final class BossAnimationCensorCaptureTests: XCTestCase {
    private struct ActionRecord: Codable {
        let time: Double
        let description: String
    }
    private struct Segment: Codable {
        let bossID: String
        let name: String
        let rule: String
        let start: Double
        let end: Double
        let actions: [ActionRecord]
        let limitation: String
        let width: Double
        let height: Double
        let initialTurn: Int
        let finalTurn: Int
        let finalScore: Int
        let finalPendingPoints: Int
        let actualCensoredDigit: Int
        let receiptZeroDemonstrated: Bool
        let handCopyWasTransferredFromPool: Bool
    }

    func testRecordCensorZeroScoreReceiptFromActualRolledDigit() async throws {
        guard ProcessInfo.processInfo.environment["NC_RECORD_BOSS_ANIMATIONS"] == "1" else {
            throw XCTSkip("Opt-in recording: set NC_RECORD_BOSS_ANIMATIONS=1")
        }
        continueAfterFailure = false
        var run = RunState(seed: "censor-live-receipt-20260920", book: .probably)
        run.slot = .boss
        run.pendingBoss = .censor
        run.coins = 12
        var game = Game(run: run)
        try game.startPuzzle()
        let original = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(original.boss, .censor)
        let actualDigit = try XCTUnwrap(original.censoredDigit)
        let bossStreamBefore = try JSONEncoder().encode(game.run.streams.boss)
        let originalHandCount = original.hand.count
        let transferred = !original.hand.contains(actualDigit)
        if transferred {
            // Return one held card before taking the exact rolled digit from
            // the Pool. This does not reroll the boss, create a card, enlarge
            // the Hand, or mark the board as already played.
            var stagedRun = game.run
            var staged = try XCTUnwrap(stagedRun.puzzle)
            let returned = staged.removeHandCard(at: staged.hand.count - 1)
            staged.pool.put(returned.digit)
            stagedRun.puzzle = staged
            game = Game(run: stagedRun)
            XCTAssertTrue(game.qaTakeFromPool(actualDigit))
        }
        XCTAssertEqual(game.puzzle?.censoredDigit, actualDigit)
        XCTAssertEqual(try JSONEncoder().encode(game.run.streams.boss), bossStreamBefore)
        XCTAssertEqual(game.puzzle?.hand.count, originalHandCount)
        let model = GameModel(resuming: game, savesProgress: false)
        let p = try XCTUnwrap(model.puzzle)
        let square = try XCTUnwrap(p.board.blanks.first { p.board.correctDigit(at: $0) == actualDigit })
        let card = try XCTUnwrap(model.hand.firstIndex(of: actualDigit))
        let exactCardID = model.handCards[card].id
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let bounds = scene.screen.bounds
        let insets = previous?.safeAreaInsets ?? UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)
        let flipper = PageFlipper()
        let window = UIWindow(windowScene: scene)
        window.frame = bounds
        window.windowLevel = .normal + 1
        let host = UIHostingController(rootView: CensorRecordingSurface(model: model, flipper: flipper,
            insets: EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)))
        host.safeAreaRegions = []
        defer {
            model.setClockRunning(false)
            model.finishScorePresentation()
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
        try await Task.sleep(for: .seconds(2))
        let start = Date().timeIntervalSince1970
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        print("BOSS_SHOWCASE_START censor \(start)")
        try await Task.sleep(for: .seconds(1.6))
        let actionTime = Date().timeIntervalSince1970
        model.tapHand(card)
        model.tapSquare(square)
        let outcome = try XCTUnwrap(model.lastOutcome)
        XCTAssertTrue(outcome.correct)
        XCTAssertEqual(outcome.points, 0)
        XCTAssertTrue(outcome.scoreReceipts.flatMap(\.operations).contains {
            $0.sourceID == "boss.censor" && $0.kind == .zero
        })
        XCTAssertFalse(model.handCards.contains { $0.id == exactCardID })
        XCTAssertEqual(model.puzzle?.board[square], actualDigit)
        var sawZeroReceipt = false
        for _ in 0..<100 {
            if let operation = model.scoreBeat?.operation,
               operation.sourceID == "boss.censor", operation.kind == .zero {
                if !sawZeroReceipt {
                    // Capture the real hosted score ticket while its production
                    // playback beat is visible, rather than reconstructing it.
                    try await Task.sleep(for: .milliseconds(100))
                    window.layoutIfNeeded()
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = scene.screen.scale
                    let image = UIGraphicsImageRenderer(size: bounds.size, format: format).image { _ in
                        window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                    }
                    let attachment = XCTAttachment(image: image)
                    attachment.name = "boss-animation-poster-censor"
                    attachment.lifetime = .keepAlways
                    add(attachment)
                }
                sawZeroReceipt = true
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTAssertTrue(sawZeroReceipt, "Production playback must actually present the Censor zero receipt")
        let final = try XCTUnwrap(model.puzzle)
        XCTAssertNil(Conservation.check(board: final.board, pool: final.pool,
            hand: final.hand + final.markerState.reservedForkCards))
        XCTAssertEqual(final.censoredDigit, actualDigit)
        XCTAssertEqual(try JSONEncoder().encode(model.run.streams.boss), bossStreamBefore)
        let segment = Segment(bossID: "censor", name: BossModifier.censor.name,
            rule: BossModifier.censor.text, start: start, end: Date().timeIntervalSince1970,
            actions: [ActionRecord(time: actionTime,
                description: "Play the actual rolled \(actualDigit.rawValue) from held copy \(exactCardID.uuidString) at R\(square.row + 1) C\(square.col + 1). Its real scoring operation stamps Points to 0.")],
            limitation: "Before filming, QA returns one nonmatching Hand card and transfers the actual censored digit from the Pool if needed. The boss roll, boss RNG, Hand count and number conservation stay unchanged. Score and receipt are earned by the recorded placement.",
            width: bounds.width, height: bounds.height, initialTurn: p.turnNumber,
            finalTurn: final.turnNumber, finalScore: final.score, finalPendingPoints: final.pendingBase,
            actualCensoredDigit: actualDigit.rawValue, receiptZeroDemonstrated: sawZeroReceipt,
            handCopyWasTransferredFromPool: transferred)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        print("BOSS_SHOWCASE_SEGMENT " + String(decoding: try encoder.encode(segment), as: UTF8.self))
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let metadata = XCTAttachment(data: try encoder.encode([segment]), uniformTypeIdentifier: "public.json")
        metadata.name = "boss-animation-censor-timeline"
        metadata.lifetime = .keepAlways
        add(metadata)
        print("BOSS_SHOWCASE_COMPLETE \(Date().timeIntervalSince1970)")
    }
}

private struct CensorRecordingSurface: View {
    @Bindable var model: GameModel
    let flipper: PageFlipper
    let insets: EdgeInsets

    var body: some View {
        RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: insets, onTapBuff: { _ in }) {
            if let puzzle = model.puzzle {
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
