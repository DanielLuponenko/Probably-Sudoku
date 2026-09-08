import XCTest
import SwiftUI
import UIKit
import Vision
@testable import ProbablySudoku

@MainActor
final class PaperDesignSystemTests: XCTestCase {
    func testPaperActionsGrowForLargeTypeInsteadOfClipping() throws {
        var heights: [CGFloat] = []
        for size in [DynamicTypeSize.large, .accessibility5] {
            let renderer = ImageRenderer(content:
                PaperButton(title: "Continue current Book", subtitle: "Book 11, Level 1", action: {})
                    .frame(width: 280)
                    .environment(\.dynamicTypeSize, size)
                    .background(Paper.page)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            heights.append(image.size.height)
            XCTAssertGreaterThanOrEqual(image.size.height, 52)
            // Accessibility 5 needs three full title lines plus the subtitle.
            // Keep a bounded footprint without penalizing that required wrapping.
            XCTAssertLessThan(image.size.height, 240)
            let copy = try text(in: image)
            XCTAssertTrue(copy.contains("continuecurrentbook"))
            XCTAssertTrue(copy.contains("book11level1"))
            attach(image, name: "paper-action-\(size)")
        }
        XCTAssertGreaterThan(heights[1], heights[0])
    }

    func testReplacementSlipFitsTheDecisionAndKeepsConsequencesVisible() throws {
        for width in [CGFloat(375), 440, 768] {
            let renderer = ImageRenderer(content:
                BookReplacementSlip(savedRunLabel: "Book 11, Level 1, Puzzle 1",
                                    newBookLabel: "Volume 1", onContinueSaved: {},
                                    onStartNew: {}, onCancel: {})
                    .frame(width: width, height: 720)
                    .background(Color.black)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            let copy = try text(in: image)
            for expected in ["unfinishedbook", "book11level1puzzle1", "continuecurrentbook",
                             "startingvolume1replacesthisunfinishedrun", "startvolume1",
                             "backtotheshelf"] {
                XCTAssertTrue(copy.contains(expected), "Missing \(expected): \(copy)")
            }
            XCTAssertFalse(copy.contains("replacecurrentrun"), "No duplicate eyebrow/card UI")
            attach(image, name: "paper-replacement-\(Int(width))")
        }
    }

    func testPrintedIllustrationUsesItsDeclaredOuterSize() throws {
        let renderer = ImageRenderer(content:
            PrintedItemIllustration(size: 40) {
                Image(systemName: "bookmark").font(.system(size: 20))
            }
        )
        let image = try XCTUnwrap(renderer.uiImage)
        XCTAssertEqual(image.size.width, 40, accuracy: 0.5)
        XCTAssertEqual(image.size.height, 40, accuracy: 0.5)
    }

    private func text(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
