#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ScorePlaybackLifecycleTests: XCTestCase {
    func testBuffReceiptWaitsForVisibleBoardAndCoveringPlaybackCancelsWithoutChangingScore() async throws {
        let model = GameModel(resuming: try QAScoringFixture.modifierPreview.makeGame(), savesProgress: false)
        model.place(handIndex: 0, at: Square(3))
        model.finishScorePresentation()
        XCTAssertEqual(model.liveScoreCalculation.total, 960)
        let visibility = Visibility()
        let ready = expectation(description: "The covered production puzzle is mounted")
        var reported = false
        let surface = PlaybackHost(model: model, visibility: visibility)
            .onPreferenceChange(NumberReturnMotionFrames.self) { frames in
                if !reported, frames[NumberReturnMotionAnchor.grid] != nil {
                    reported = true
                    ready.fulfill()
                }
            }
        let controller = UIHostingController(rootView: surface)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 778)
        window.rootViewController = controller
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        try await Task.sleep(for: .milliseconds(150))

        XCTAssertTrue(model.useBuff(at: 0))
        let performance = try XCTUnwrap(model.scorePerformance)
        let first = try XCTUnwrap(performance.feedbackBeats.first)
        XCTAssertEqual(first.sourceID, Buffs.freshInk)
        XCTAssertEqual(model.scoreBeat?.id, first.id)
        XCTAssertEqual(model.liveScoreCalculation.total, 1_920)
        XCTAssertTrue(model.run.buffs.isEmpty)
        let saved = try model.game.encoded()
        // Longer than a visible modifier beat: a closing slip must not spend
        // the player's opportunity to see the consumed Buff's feedback.
        for _ in 0..<3 {
            try await Task.sleep(for: .milliseconds(400))
            XCTAssertEqual(model.scorePerformance?.id, performance.id)
            XCTAssertEqual(model.scoreBeat?.id, first.id)
            XCTAssertEqual(model.liveScoreCalculation.total, 1_920)
        }

        // Change an observed input on the same live SwiftUI hierarchy. This
        // exercises ScorePlaybackID's visibility restart, not a remount.
        visibility.isVisible = true
        window.layoutIfNeeded()
        for _ in 0..<12 where model.scoreBeat?.id == first.id {
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertNotNil(model.scoreBeat, "The visible source sequence should still be playing")
        XCTAssertNotEqual(model.scoreBeat?.id, first.id, "Uncovering must start the held feedback")
        XCTAssertEqual(model.scorePerformance?.id, performance.id)
        XCTAssertEqual(model.liveScoreCalculation.total, 1_920)

        visibility.isVisible = false
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(model.scorePerformance)
        XCTAssertNil(model.scoreBeat)
        model.advanceScore(try XCTUnwrap(performance.feedbackBeats.last), performanceID: performance.id)
        for _ in 0..<2 {
            try await Task.sleep(for: .milliseconds(400))
            XCTAssertNil(model.scorePerformance, "A cancelled playback task cannot reappear")
            XCTAssertNil(model.scoreBeat)
            XCTAssertEqual(model.liveScoreCalculation.total, 1_920)
        }
        XCTAssertEqual(try model.game.encoded(), saved,
                       "Showing, covering, and delayed callbacks cannot change the committed Buff or score")
    }

    @MainActor @Observable
    final class Visibility {
        var isVisible = false
    }

    private struct PlaybackHost: View {
        @Bindable var model: GameModel
        @Bindable var visibility: Visibility
        var body: some View {
            GameplayShell(model: model, controls: [], onTapBuff: { _ in }) {
                PuzzlePageView(model: model, puzzle: model.puzzle!, isClockRunning: visibility.isVisible)
            }
            .frame(width: 402, height: 778)
            .background { GameplaySurfaceBackground() }
            .environment(\.scenePhase, .active)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.levelPalette, .forDisplay(slot: .easy))
            .environment(\.dynamicTypeSize, .large)
        }
    }
}
#endif
