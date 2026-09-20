import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class SavedBookSummaryTests: XCTestCase {
    func testMissingAndFailedRunsNeverOfferContinue() {
        XCTAssertNil(SavedBookSummary(game: nil))
        var run = Game(seed: "failed-home").run
        run.outcome = .failed
        XCTAssertNil(SavedBookSummary(game: Game(run: run)))
    }

    func testResumeSummaryReflectsActualSavedLocationAndDoesNotChangeGame() throws {
        var game = Game(seed: "home-continue", book: .slightlyHarder)
        try game.startPuzzle()
        let before = game.run
        let summary = try XCTUnwrap(SavedBookSummary(game: game))
        XCTAssertFalse(summary.isCompleted)
        XCTAssertEqual(summary.actionTitle, "Continue")
        XCTAssertEqual(summary.location, "Book 2 · Chapter 1 of 9")
        XCTAssertTrue(summary.detail.contains("Puzzle 1"))
        XCTAssertTrue(summary.detail.contains("Turn 1/\(try XCTUnwrap(game.puzzle).turnsMax)"))
        XCTAssertTrue(summary.detail.contains("\(game.run.coins) coins"))
        XCTAssertEqual(summary.bookTitle, BookEdition.second.title)
        XCTAssertNil(RunStore.conflict(local: game, remote: Game(run: before)))
    }

    func testFinalReceiptIsNotPresentedAsAnUnfinishedBook() throws {
        var run = Game(seed: "complete-home").run
        run.outcome = .bookCompleted
        let summary = try XCTUnwrap(SavedBookSummary(game: Game(run: run)))
        XCTAssertTrue(summary.isCompleted)
        XCTAssertEqual(summary.actionTitle, "View final page")
        XCTAssertEqual(summary.location, "Book 1 completed")
        XCTAssertFalse(summary.detail.contains("Turn"))
    }

    func testHomeActionsKeepRunDetailsReadableAtPhoneWidthsAndLargestText() throws {
        let summary = try XCTUnwrap(SavedBookSummary(game: Game(seed: "home-card")))
        var actions = 0
        for width in [CGFloat(280), 346] {
            var normalHeight: CGFloat = 0
            for size in [DynamicTypeSize.large, .accessibility5] {
                let renderer = ImageRenderer(content:
                    BookstoreHomeActions(saved: summary, onContinue: { actions += 1 },
                                         onPlay: { actions += 1 })
                        .frame(width: width)
                        .environment(\.dynamicTypeSize, size)
                        .background(Color.black))
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
                let copy = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                    .joined().lowercased().filter { $0.isLetter || $0.isNumber }
                for phrase in ["continue", "book1", "chapter1", "puzzle1", "chooseanotherbook"] {
                    XCTAssertTrue(copy.contains(phrase), "Missing \(phrase) at \(width)/\(size): \(copy)")
                }
                if size == .large { normalHeight = image.size.height }
                else { XCTAssertGreaterThan(image.size.height, normalHeight * 1.5) }
                XCTAssertEqual(image.size.width, width, accuracy: 0.5)
                let attachment = XCTAttachment(image: image)
                attachment.name = "home-continue-\(width)-\(size)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        XCTAssertEqual(actions, 0)
    }
}
