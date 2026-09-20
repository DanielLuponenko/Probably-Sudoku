import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ShopOfferCardRenderingTests: XCTestCase {
    func testReservationCancellationReservesItsOwnTouchBandWithoutHidingStock() {
        for height: CGFloat in [500, 550, 660] {
            for scale: CGFloat in [1, 3.12] {
                let layout = ShopPageLayout(available: CGSize(width: 359, height: height),
                                            textScale: scale, hasReservation: true)
                let used = layout.headerHeight + layout.footerHeight + layout.bottomPadding
                    + layout.spacing * 5 + 3 * (layout.labelHeight + layout.labelSpacing + layout.cardHeight)
                XCTAssertEqual(layout.headerHeight, 88, "Shop title/Reroll and Cancel each retain a 44pt band")
                XCTAssertLessThanOrEqual(used, height + 0.01)
                XCTAssertGreaterThanOrEqual(layout.cardHeight, 75)
            }
        }
    }

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

    func testEveryOfferAndContinueFitTheInitialScreenWithoutACatalogueScrollView() async throws {
        let devices: [(String, CGSize, EdgeInsets, DynamicTypeSize, Int)] = [
            ("SE-five", CGSize(width: 375, height: 667), EdgeInsets(), .large, 5),
            ("SE-five-reserved", CGSize(width: 375, height: 667), EdgeInsets(), .large, 5),
            ("SE-six-AX5", CGSize(width: 375, height: 667), EdgeInsets(), .accessibility5, 6),
            ("17-Pro-six", CGSize(width: 402, height: 874),
             EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), .large, 6),
            ("17-Pro-six-AX5", CGSize(width: 402, height: 874),
             EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), .accessibility5, 6),
            ("17-Pro-five-reserved-AX5", CGSize(width: 402, height: 874),
             EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), .accessibility5, 5),
            ("large-five", CGSize(width: 440, height: 956),
             EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0), .large, 5),
            ("iPad-six-AX5", CGSize(width: 1032, height: 1376),
             EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0), .accessibility5, 6)
        ]
        for (name, size, insets, dynamicType, count) in devices {
            let ids = ["bm_the_sunday_supplement", "bm_letters_to_the_editor",
                       "mk_silver", "mk_sapphire", "bf_second_print", Buffs.paperCrane]
            var run = RunState(seed: "single-screen-shop")
            run.coins = 40
            run.shop = ShopState(offers: ids.prefix(count).enumerated().map { index, id in
                ShopOffer(slot: index, defID: id, price: 3 + index)
            })
            if name.contains("reserved") {
                let data = try JSONSerialization.data(withJSONObject: [
                    "sourceBuff": UUID().uuidString, "context": "visual-audit-reservation",
                    "slot": 0, "definition": ids[0], "price": 3
                ])
                run.buffState.reservationIntent = try JSONDecoder().decode(BuffReservationIntent.self, from: data)
            }
            let model = GameModel(frozen: Game(run: run), page: .shop)
            let before = try model.game.encoded()
            let flipper = PageFlipper()
            let surface = RunPageSurface(model: model, flipper: flipper, controls: [
                StripControl(systemImage: "questionmark", label: "Help", action: {}),
                StripControl(systemImage: "gearshape", label: "Settings", action: {})
            ], safeAreaInsets: insets, onTapBuff: { _ in }) {
                ShopPageView(model: model, shop: model.shop!, onClaimMarker: { _ in })
            }
            .environment(flipper)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
            .environment(\.dynamicTypeSize, dynamicType)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light)
            .transaction { $0.disablesAnimations = true }
            let host = UIHostingController(rootView: surface)
            host.safeAreaRegions = []
            let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let previousKey = scene.windows.first { $0.isKeyWindow }
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer {
                flipper.cancel()
                window.isHidden = true
                window.rootViewController = nil
                previousKey?.makeKey()
            }
            try await Task.sleep(for: .milliseconds(100))
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(size: size).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "shop-one-screen-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertTrue(scrollViews(in: host.view).isEmpty,
                          "\(name): the catalogue must fit, rather than clipping or allowing a scroll.")
            let rows = try recognize(image)
            let text = rows.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            for offer in try XCTUnwrap(model.shop).offers {
                XCTAssertTrue(containsPrintedTitle(offer.def.name, in: rows),
                              "\(name) must show the entire name of slot \(offer.slot) before any input: \(text)")
            }
            let continueRow = try XCTUnwrap(rows.first {
                normalize($0.topCandidates(1).first?.string ?? "").contains("continue")
            }, "\(name): Continue must remain visible beside all stock")
            let continueBottom = (1 - continueRow.boundingBox.minY) * size.height
            XCTAssertLessThan(continueBottom, size.height - insets.bottom,
                              "\(name): Continue must remain above the home indicator")
            XCTAssertTrue(text.localizedCaseInsensitiveContains("Reroll"), "\(name): \(text)")
            if name.contains("reserved") {
                XCTAssertTrue(text.localizedCaseInsensitiveContains("Cancel reservation"), "\(name): \(text)")
            }
            XCTAssertEqual(try model.game.encoded(), before,
                           "A fitted catalogue cannot purchase, reroll, regenerate or mutate the save.")
        }
    }

    func testNarrowFittedCardsKeepLongNamesAndCompleteConciseEffects() throws {
        for id in CatalogueDetails.all.map(\.id) {
            let offer = ShopOffer(slot: 0, defID: id, price: 4)
            let card = OfferCard(offer: offer, affordable: true, hasSlot: true, layout: .column,
                                 fittedHeight: 120, textScale: 1.08, inspect: {})
            let image = try render(card, width: 167)
            let rows = try recognize(image)
            let text = rows.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            XCTAssertTrue(containsPrintedTitle(offer.def.name, in: rows), "\(id): \(text)")
            let expected = normalize(ShopOfferSummary.text(for: offer.def))
            let retry = normalize(text).contains(expected) ? text : try recognize(image, languageCorrection: true)
                .compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
            XCTAssertTrue(normalize(text).contains(expected) || normalize(retry).contains(expected),
                          "\(id): a short effect must remain complete on the compact catalogue: \(text)")
            XCTAssertTrue(text.localizedCaseInsensitiveContains("Details"), "\(id): \(text)")
            XCTAssertEqual(image.size.height, 136, accuracy: 0.5)
            let attachment = XCTAttachment(image: image)
            attachment.name = "shop-fitted-long-copy-\(id)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func render<V: View>(_ content: V, width: CGFloat) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width)
            .padding(8).background(Paper.page)
            .environment(\.locale, Locale(identifier: "en_US")))
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage)
    }

    private func recognize(_ image: UIImage, languageCorrection: Bool = false) throws -> [VNRecognizedTextObservation] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = languageCorrection
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

        if lines.contains(where: { $0.copy.contains(expected) }) { return true }
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
        text.lowercased().replacingOccurrences(of: "×", with: "x").filter { $0.isLetter || $0.isNumber }
    }
}
