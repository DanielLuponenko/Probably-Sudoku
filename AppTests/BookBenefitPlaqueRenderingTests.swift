import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookBenefitPlaqueRenderingTests: XCTestCase {
    func testEveryBookPrintsItsConciseAbilityInTheCompactReferencePlaqueAtPhoneWidths() throws {
        for screenWidth in [CGFloat(320), 375, 402, 440] {
            for edition in BookEdition.shelf {
                for obstacle in [Obstacle.none, .finalEdition] {
                    let width = screenWidth * 0.80
                    let height = SelectedBookBenefitPlaque.height(width: width, showsObstacle: obstacle != .none)
                    let plaque = SelectedBookBenefitPlaque(edition: edition, obstacle: obstacle)
                    let renderer = ImageRenderer(content: plaque.frame(width: width, height: height)
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .transaction { $0.disablesAnimations = true })
                    renderer.scale = 3
                    let image = try XCTUnwrap(renderer.uiImage)
                    let printed = try recognizedText(in: image)
                    XCTAssertTrue(printed.contains(normalize(edition.benefit.title)),
                                  "Title clipped in \(edition.id), \(screenWidth), \(obstacle): \(printed)")
                    XCTAssertTrue(printed.contains(normalize(plaque.detail)),
                                  "Ability detail clipped in \(edition.id), \(screenWidth), \(obstacle): \(printed)")
                    if obstacle != .none {
                        XCTAssertTrue(containsVisionTolerant(obstacle.text, in: printed),
                                      "Obstacle rule clipped in \(edition.id), \(screenWidth): \(printed)")
                    }
                    if edition.rule == .genuinely || edition.rule == .overthinking
                        || edition.rule == .smallVictories || edition.rule == .trustMe
                        || edition.rule == .noPressure {
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "benefit-plaque-\(edition.id)-\(Int(screenWidth))-obstacle-\(obstacle.rawValue)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
    }

    func testPlaqueMatchesThePhysicalBookWidthAndKeepsFullRuleAccessibilityForAllBooks() {
        for screen in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let layout = BookstoreSelectionLayout(viewport: screen)
            for edition in BookEdition.shelf {
                for obstacle in [Obstacle.none, .finalEdition] {
                    let plaque = SelectedBookBenefitPlaque(edition: edition, obstacle: obstacle)
                    let height = SelectedBookBenefitPlaque.height(width: layout.plaqueWidth,
                                                                 showsObstacle: obstacle != .none)
                    let frame = layout.plaqueFrame(height: height)
                    XCTAssertEqual(frame.width, layout.bookWidth, accuracy: 0.000001)
                    XCTAssertEqual(frame.midX, screen.width / 2, accuracy: 0.000001)
                    XCTAssertTrue(plaque.accessibilitySummary.contains(edition.benefit.detail))
                    if obstacle != .none {
                        XCTAssertTrue(plaque.accessibilitySummary.contains(obstacle.text))
                    }
                }
            }
        }
        let fifth = SelectedBookBenefitPlaque(edition: BookEdition.shelf[4], obstacle: .none)
        XCTAssertEqual(fifth.detail, "5 numbers per puzzle")
        XCTAssertEqual(BookEdition.shelf[4].benefit.title, "+1 Toss")
        XCTAssertEqual(BookEdition.shelf[4].benefit.before, 4)
        XCTAssertEqual(BookEdition.shelf[4].benefit.after, 5)
        XCTAssertEqual(SelectedBookBenefitPlaque.height(width: 300, showsObstacle: false), 72)
        XCTAssertEqual(SelectedBookBenefitPlaque.height(width: 300, showsObstacle: true), 112)
    }

    func testAccessibilityFiveRendersTheCompleteRuleWithoutAClippedFixedHeight() throws {
        let plaque = SelectedBookBenefitPlaque(edition: BookEdition.shelf[4], obstacle: .finalEdition)
            .frame(width: 300)
            .environment(\.dynamicTypeSize, .accessibility5)
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true }
        let renderer = ImageRenderer(content: plaque)
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertGreaterThanOrEqual(image.size.height, 112,
                                    "Accessibility text must earn intrinsic label height")
        let printed = try recognizedText(in: image)
        XCTAssertTrue(printed.contains(normalize("5 numbers per puzzle")),
                      "Accessibility-sized rule was clipped: \(printed)")
        XCTAssertTrue(containsVisionTolerant(Obstacle.finalEdition.text, in: printed),
                      "Accessibility-sized obstacle rule was clipped: \(printed)")
        let attachment = XCTAttachment(image: image)
        attachment.name = "benefit-plaque-accessibility5"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func recognizedText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        let cgImage = try XCTUnwrap(image.cgImage)
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return normalize((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " "))
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func containsVisionTolerant(_ expected: String, in printed: String) -> Bool {
        let target = normalize(expected)
        // Vision's 320pt/iPad OCR receipts consistently confuse the glyphs in
        // "Tosses"→"losses" and "fewer"→"tewer"; accept those substitutions
        // while still requiring the complete normalized rule in one sequence.
        let fewerVariant = target.replacingOccurrences(of: "fewer", with: "tewer")
        let tossesVariant = target.replacingOccurrences(of: "tosses", with: "losses")
        let bothVariant = fewerVariant.replacingOccurrences(of: "tosses", with: "losses")
        return [target, fewerVariant, tossesVariant, bothVariant].contains { printed.contains($0) }
    }
}
