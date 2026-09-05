import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Native, code-rendered evidence for every cover. Attachments are retained in
/// the xcresult so visual review can catch clipped text or reused cover art.
@MainActor
final class BookEditionRenderTests: XCTestCase {
    func testAllTwelveLiveBookCoversRenderAtPhoneSize() throws {
        XCTAssertEqual(BookEdition.shelf.count, 12)
        let bookWidth: CGFloat = 300
        let canvas = CGSize(width: bookWidth * 1.20, height: bookWidth * 1.445)

        for edition in BookEdition.shelf {
            let renderer = ImageRenderer(content:
                LiveBook(
                    edition: edition,
                    ribbons: LiveBook.RibbonStrip(
                        levels: Obstacle.allCases,
                        selected: .none,
                        isUnlocked: { _ in true },
                        onPick: { _ in },
                        onShowInfo: { _ in }
                    )
                )
                .frame(width: bookWidth)
                .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.colorScheme, .light)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage, "Volume \(edition.rule.volume) failed to render")
            XCTAssertEqual(image.size.width, canvas.width, accuracy: 0.5)
            XCTAssertEqual(image.size.height, canvas.height, accuracy: 0.5)

            let attachment = XCTAttachment(image: image)
            attachment.name = String(format: "book-cover-volume-%02d-%@", edition.rule.volume, edition.id)
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testAuthoredTitleLinesAndFlourishesFitInsideThePrintedCoverRule() throws {
        // CoverFace receives the width remaining after LiveBook's turn-in.
        // Match the actual system-black / Marker Felt sizes and tracking,
        // rather than assuming a short string or relying on automatic wrapping.
        let faceWidth: CGFloat = 300 * (1 - 0.085 - 0.032)
        let availableWidth = faceWidth * (1 - 2 * 0.035)
        for edition in BookEdition.shelf {
            let design = edition.design
            let titleFont = UIFont.systemFont(ofSize: faceWidth * 0.175 * design.titleScale, weight: .black)
            for line in design.titleLines {
                let width = (line as NSString).size(withAttributes: [
                    .font: titleFont,
                    .kern: -faceWidth * 0.004
                ]).width
                XCTAssertLessThanOrEqual(width, availableWidth,
                                         "Volume \(edition.rule.volume) title line '\(line)' crosses the printed rule")
            }

            let flourishFont = try XCTUnwrap(UIFont(name: "MarkerFelt-Wide",
                                                   size: faceWidth * 0.20 * design.flourishScale))
            let flourishSize = (design.flourish as NSString).size(withAttributes: [.font: flourishFont])
            let angle = CGFloat.pi / 60 // LiveBook rotates the flourish by -3 degrees.
            let rotatedWidth = flourishSize.width * cos(angle) + flourishSize.height * sin(angle)
            XCTAssertLessThanOrEqual(rotatedWidth, availableWidth,
                                     "Volume \(edition.rule.volume) flourish '\(design.flourish)' crosses the printed rule")
        }
    }
}
