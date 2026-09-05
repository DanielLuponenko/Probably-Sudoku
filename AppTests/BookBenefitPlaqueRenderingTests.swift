import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookBenefitPlaqueRenderingTests: XCTestCase {
    func testEveryBookPrintsItsCompleteAbilityInTheReferencePlaqueAtPhoneWidths() throws {
        for screenWidth in [CGFloat(375), 402, 440] {
            for edition in BookEdition.shelf {
                for obstacle in [Obstacle.none, .finalEdition] {
                    let width = screenWidth * 0.96
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
                    // Read only the trailing badge of the FULL rendered row,
                    // not another occurrence of these numbers in its title.
                    let badge = try recognizedBadgeText(in: image)
                    XCTAssertEqual(badge.filter(\.isNumber), "\(edition.benefit.before)\(edition.benefit.after)",
                                   "Badge lost a value in \(edition.id), \(screenWidth), \(obstacle): \(badge)")
                    XCTAssertFalse(badge.contains("…") || badge.contains("..."),
                                   "Badge must never replace a value with an ellipsis")
                    if edition.rule == .genuinely || edition.rule == .overthinking || edition.rule == .smallVictories {
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "benefit-plaque-\(edition.id)-\(Int(screenWidth))-obstacle-\(obstacle.rawValue)"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                    }
                }
            }
        }
    }

    func testPlaqueKeepsEqualScreenGuttersAndFullRuleAccessibilityForAllBooks() {
        for screen in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874), CGSize(width: 440, height: 956)] {
            let layout = BookstoreSelectionLayout(viewport: screen)
            for edition in BookEdition.shelf {
                for obstacle in [Obstacle.none, .finalEdition] {
                    let plaque = SelectedBookBenefitPlaque(edition: edition, obstacle: obstacle)
                    let height = SelectedBookBenefitPlaque.height(width: screen.width * 0.96,
                                                                 showsObstacle: obstacle != .none)
                    let frame = layout.plaqueFrame(height: height)
                    XCTAssertEqual(frame.minX, screen.width - frame.maxX, accuracy: 0.000001)
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

    private func recognizedBadgeText(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US"]
        // The badge occupies the trailing quarter of the benefit row. Keep
        // the obstacle footer outside this normalized bottom-left ROI.
        request.regionOfInterest = CGRect(x: 0.70, y: 0.32, width: 0.28, height: 0.60)
        let cgImage = try XCTUnwrap(image.cgImage)
        try VNImageRequestHandler(cgImage: cgImage).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
