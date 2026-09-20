import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BossFailureExplanationTests: XCTestCase {
    func testCombinedTargetDoesNotClaimSplitEditionWasCompleted() throws {
        var puzzle = try puzzle(.splitEdition)
        let targets = BossEncounterRules.editionTargets(puzzle: puzzle)
        puzzle.score = puzzle.target
        puzzle.bossState.encounter.editionScores = [puzzle.target, 0]

        XCTAssertFalse(BossEncounterRules.targetSatisfied(puzzle: puzzle))
        XCTAssertEqual(BossFailureExplanation.text(for: puzzle), "Edition B is unfinished.")

        puzzle.bossState.encounter.editionScores = [0, puzzle.target]
        XCTAssertEqual(BossFailureExplanation.text(for: puzzle), "Edition A is unfinished.")
        puzzle.bossState.encounter.editionScores = [0, 0]
        XCTAssertEqual(BossFailureExplanation.text(for: puzzle), "Both editions are unfinished.")
        puzzle.bossState.encounter.editionScores = targets
        XCTAssertNil(BossFailureExplanation.text(for: puzzle))
    }

    func testReviewBoardExplainsOutstandingApprovalEvenAboveTarget() throws {
        var puzzle = try puzzle(.reviewBoard)
        puzzle.score = puzzle.target * 2
        puzzle.bossState.reviewApproved = [.row, .box]
        XCTAssertFalse(BossEncounterRules.targetSatisfied(puzzle: puzzle))
        XCTAssertEqual(BossFailureExplanation.text(for: puzzle), "Still needs approval: column.")
        puzzle.bossState.reviewApproved.insert(.col)
        XCTAssertNil(BossFailureExplanation.text(for: puzzle))
    }

    func testSplitFailurePrintsBothLedgersAndItsReasonAtPhoneAndAccessibilitySizes() throws {
        var puzzle = try puzzle(.splitEdition)
        puzzle.score = puzzle.target
        puzzle.bossState.encounter.editionScores = [puzzle.target, 0]
        puzzle.phase = .failed
        for size in [DynamicTypeSize.large, .accessibility3] {
            let content = FailurePageContents(score: puzzle.score, target: puzzle.target,
                offersRescue: false, adState: .idle, canWatchAd: false, isBusy: false,
                compact: true, board: puzzle.board, puzzle: puzzle, boardSide: 280)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.dynamicTypeSize, size)
                .environment(\.locale, Locale(identifier: "en_US"))
                .frame(width: 328)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = "split-edition-failed-\(size == .large ? "phone" : "large-text")"
            attachment.lifetime = .keepAlways
            add(attachment)
            if size == .large {
                XCTAssertLessThanOrEqual(image.size.height, 600, "The compact result must fit without hiding its decision")
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage)).perform([request])
            let words = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
            for expected in ["edition a", "edition b", "edition b is unfinished", "new book"] {
                XCTAssertTrue(words.contains(expected), "Missing \(expected): \(words)")
            }
            XCTAssertTrue(words.contains(puzzle.target.formatted()), "The total in A must remain readable")
            XCTAssertTrue(words.contains(BossEncounterRules.editionTargets(puzzle: puzzle)[1].formatted()),
                          "Both edition targets must remain readable")
        }
    }

    func testSplitFailureFitsHostedProductionResultAtBothPhoneSizes() async throws {
        var failed = try puzzle(.splitEdition)
        failed.score = failed.target
        failed.bossState.encounter.editionScores = [failed.target, 0]
        failed.phase = .failed
        var run = RunState(seed: "boss-failure-hosted")
        run.level = failed.level
        run.slot = .boss
        run.pendingBoss = nil
        run.puzzle = failed
        run.outcome = .failed
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        let saved = try model.game.encoded()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)

        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)] {
            let oldWindow = scene.windows.first { $0.isKeyWindow }
            let flipper = PageFlipper()
            let surface = RunPageSurface(model: model, flipper: flipper,
                controls: [StripControl(systemImage: "questionmark", label: "Help", action: {}),
                           StripControl(systemImage: "gearshape", label: "Settings", action: {})],
                safeAreaInsets: EdgeInsets(top: size.height > 700 ? 62 : 20, leading: 0,
                                          bottom: size.height > 700 ? 34 : 0, trailing: 0),
                onTapBuff: { _ in }) {
                    ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
                }
                .environment(flipper)
                .environment(\.gameReduceMotion, true)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
                .environment(\.levelPalette, .forDisplay(slot: .boss))
                .environment(\.scenePhase, .inactive)
                .environment(\.bossMotionIsActive, false)
                .environment(\.dynamicTypeSize, .large)
                .environment(\.locale, Locale(identifier: "en_US"))
                .frame(width: size.width, height: size.height)
            let host = UIHostingController(rootView: surface)
            host.safeAreaRegions = []
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer {
                window.isHidden = true
                window.rootViewController = nil
                oldWindow?.makeKey()
                flipper.cancel()
            }
            try await Task.sleep(for: .milliseconds(180))
            window.layoutIfNeeded()

            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "split-edition-failed-hosted-\(Int(size.width))x\(Int(size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage)).perform([request])
            let words = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased()
            for expected in ["book over", "edition a", "edition b", "edition b is unfinished", "new book"] {
                XCTAssertTrue(words.contains(expected), "\(size): Hidden \(expected): \(words)")
            }
            XCTAssertTrue(words.contains(failed.target.formatted()), "The completed A total must be visible")
            XCTAssertTrue(words.contains(BossEncounterRules.editionTargets(puzzle: failed)[1].formatted()),
                          "The unfinished B target must be visible")
            for scroll in visibleScrollViews(in: host.view) {
                XCTAssertLessThanOrEqual(scroll.contentSize.height + scroll.adjustedContentInset.top
                    + scroll.adjustedContentInset.bottom, scroll.bounds.height + 1,
                    "\(size): The normal-size failure page must not require vertical scrolling")
            }
            XCTAssertEqual(try model.game.encoded(), saved, "Presenting a failed Book cannot mutate its saved result")
        }
    }

    private func visibleScrollViews(in view: UIView) -> [UIScrollView] {
        guard !view.isHidden, view.alpha > 0.01, view.window != nil else { return [] }
        return (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { visibleScrollViews(in: $0) }
    }

    private func puzzle(_ boss: BossModifier) throws -> PuzzleState {
        var run = RunState(seed: "boss-failure-qualification")
        run.level = 9
        run.slot = .boss
        run.pendingBoss = boss
        var game = Game(run: run)
        try game.startPuzzle()
        return try XCTUnwrap(game.puzzle)
    }
}
