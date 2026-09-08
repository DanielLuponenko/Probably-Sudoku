import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ShopOfferCardRenderingTests: XCTestCase {
    func testFullPaperInspectionButtonsPreserveColumnAndWideCardFootprints() throws {
        let offers: [(String, OfferCard.Layout, CGFloat, CGFloat)] = [
            ("bm_local_gossip", .column, 160, 150),
            ("mk_copper", .column, 160, 150),
            ("bf_redraw", .wide, 350, 120)
        ]
        for (id, layout, width, height) in offers {
            let definition = try XCTUnwrap(Catalog.item(id))
            for sold in [false, true] {
                let json = "{\"slot\":0,\"defID\":\"\(id)\",\"price\":4,\"sold\":\(sold)}"
                let offer = try JSONDecoder().decode(ShopOffer.self, from: Data(json.utf8))
                let card = OfferCard(offer: offer, affordable: true, hasSlot: true,
                                     layout: layout, inspect: {})
                let image = try render(card, width: width)
                // 120/150 are minimums, not hard heights: a wide title,
                // rarity and description can naturally need more. Compare
                // against the exact former label geometry, not a guessed
                // constant or a looser tolerance around the new result.
                let face = try render(card.ticketFace, width: width)
                XCTAssertEqual(image.size.width, width + 16, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(face.size.height, height + 16)
                XCTAssertEqual(image.size.height, face.size.height, accuracy: 0.5,
                               "Moving the ticket inside its Button must not change its footprint")
                let attachment = XCTAttachment(image: image)
                attachment.name = "full-card-inspection-\(id)-sold-\(sold)"
                attachment.lifetime = .keepAlways
                add(attachment)
                if !sold {
                    let rows = try recognize(image)
                    let copy = rows.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                    XCTAssertTrue(containsPrintedTitle(definition.name, in: rows), copy)
                }
            }
        }
    }

    private func render<V: View>(_ content: V, width: CGFloat) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width)
            .padding(8).background(Paper.page)
            .environment(\.locale, Locale(identifier: "en_US")))
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage)
    }

    private func recognize(_ image: UIImage) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return request.results ?? []
    }

    /// Vision reads across columns, so a right-hand price can appear between
    /// "Local" and "Gossip" in its flattened string. Require the complete title
    /// either on one line or on adjacent lines sharing the same left edge.
    /// This still rejects missing, clipped or reordered title words.
    private func containsPrintedTitle(_ title: String, in rows: [VNRecognizedTextObservation]) -> Bool {
        let expected = normalize(title)
        let lines = rows.compactMap { row -> (copy: String, bounds: CGRect)? in
            guard let copy = row.topCandidates(1).first?.string else { return nil }
            return (normalize(copy), row.boundingBox)
        }.sorted { $0.bounds.maxY > $1.bounds.maxY }

        for start in lines where expected.hasPrefix(start.copy) {
            if start.copy == expected { return true }
            var joined = start.copy
            var previous = start.bounds
            for next in lines where next.bounds.maxY < start.bounds.maxY {
                guard abs(next.bounds.minX - start.bounds.minX) <= 0.025 else { continue }
                let gap = previous.minY - next.bounds.maxY
                guard gap <= max(previous.height, next.bounds.height) else { break }
                joined += next.copy
                if joined == expected { return true }
                guard expected.hasPrefix(joined) else { break }
                previous = next.bounds
            }
        }
        return false
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
