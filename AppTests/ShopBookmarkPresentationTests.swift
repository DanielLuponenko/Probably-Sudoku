import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ShopBookmarkPresentationTests: XCTestCase {
    func testSellControlUsesPaidPriceAndRejectsAReplacementInItsSlot() throws {
        var run = RunState(seed: "bookmark-sale-control")
        let selected = OwnedBookmark(defID: Bookmarks.syndication, boughtAtLevel: 2, pricePaid: 7)
        run.bookmarks = [selected]
        let sale = InventorySale(bookmark: selected, index: 0)

        XCTAssertTrue(sale.matches(run))
        XCTAssertEqual(sale.refund, 3)
        XCTAssertEqual(sale.actionTitle, "Sell for 3 coins")
        let balance = run.coins
        XCTAssertEqual(try Shop.sell(&run, kind: sale.kind, index: sale.index), sale.refund)
        XCTAssertEqual(run.coins, balance + 3)
        XCTAssertFalse(sale.matches(run), "A second activation must not sell an empty slot.")

        run.bookmarks = [OwnedBookmark(defID: Bookmarks.syndication, boughtAtLevel: 2, pricePaid: 4)]
        XCTAssertFalse(sale.matches(run), "A differently priced copy is not the selected purchase.")
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.syndication, boughtAtLevel: 3, pricePaid: 7)]
        XCTAssertFalse(sale.matches(run), "A newly bought replacement is not the selected purchase.")
    }

    func testShiftedBuffSlotCannotSellItsNeighborAndMinimumRefundIsVisible() {
        var run = RunState(seed: "buff-sale-control")
        let selected = OwnedBuff(defID: Buffs.redraw, pricePaid: 0)
        run.buffs = [selected, OwnedBuff(defID: Buffs.paperCrane, pricePaid: 3)]
        let sale = InventorySale(buff: selected, index: 0)
        XCTAssertTrue(sale.matches(run))
        XCTAssertEqual(sale.actionTitle, "Sell for 1 coin")
        run.buffs.removeFirst()
        XCTAssertFalse(sale.matches(run), "Removing the selected Buff cannot retarget its stale sell action.")
    }

    func testLongOfferCopyHasAVisibleDetailsAffordanceAtPhoneCardWidths() throws {
        for (defID, layout, widths) in [
            (Bookmarks.syndication, OfferCard.Layout.column, [CGFloat(150), 186]),
            (Buffs.redraw, .wide, [CGFloat(145), 186]),
            (Buffs.paperCrane, .wide, [CGFloat(145), 186])
        ] {
            let def = try XCTUnwrap(Catalog.item(defID))
            for width in widths {
                let image = try render(OfferDescription(text: def.text, layout: layout),
                                       width: width, name: "offer-\(defID)-\(Int(width))")
                let text = try recognize(image)
                XCTAssertTrue(text.contains("details"),
                              "Abbreviated offer copy must visibly lead to its full description: \(text)")
                XCTAssertLessThanOrEqual(image.size.height, layout == .column ? 66 : 52,
                                        "Long copy must keep the non-scrolling catalogue's text budget.")
            }
        }
    }

    func testShortOfferCopyStaysCompleteWithoutAnUnnecessaryDetailsLabel() throws {
        let image = try render(OfferDescription(text: "+2 Turns this Puzzle", layout: .column),
                               width: 186, name: "short-offer")
        let text = try recognize(image)
        XCTAssertTrue(text.contains("2turnsthispuzzle"))
        XCTAssertFalse(text.contains("details"))
    }

    func testOwnedBookmarkDetailsShowTheCompleteCopyAndSaleRefund() throws {
        let def = try XCTUnwrap(Catalog.item(Bookmarks.syndication))
        let owned = OwnedBookmark(defID: def.id, boughtAtLevel: 2, pricePaid: 7)
        let image = try render(ItemDetailCard(def: def, sale: InventorySale(bookmark: owned, index: 0),
                                              onSell: {}),
                               width: 260, name: "bookmark-details-sale")
        let text = try recognize(image)
        XCTAssertTrue(text.contains("resetsonlyatanewbook"), "The sale action cannot clip the final sentence.")
        XCTAssertTrue(text.contains("sellfor3coins"), "The visible sale action must show the actual refund.")
    }

    func testOfferDetailsUseReadablePaperNavigationEvenWhenTheGameIsDark() async throws {
        let offer = try JSONDecoder().decode(ShopOffer.self, from: Data(
            #"{"slot":0,"defID":"bm_syndication","price":8,"sold":false}"#.utf8))
        let model = GameModel(frozen: Game(seed: "offer-navigation"), page: .shop)
        let host = UIHostingController(rootView: OfferSlip(model: model, offer: offer, markerBought: { _ in })
            .environment(\.colorScheme, .dark))
        host.overrideUserInterfaceStyle = .dark
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 520)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        let navigationBar = try XCTUnwrap(descendants(of: UINavigationBar.self, in: host.view).first)
        XCTAssertEqual(navigationBar.barStyle, .default,
                       "The paper navigation bar needs dark title ink even when the game uses a dark scheme.")
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        attach(image, name: "item-details-dark-game")
        XCTAssertTrue(try recognize(image).contains("itemdetails"))
    }

    private func render<V: View>(_ content: V, width: CGFloat, name: String) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width).padding(8)
            .background(Paper.page)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true })
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage)
        attach(image, name: name)
        return image
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func recognize(_ image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ").lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func descendants<T: UIView>(of type: T.Type, in view: UIView) -> [T] {
        (view as? T).map { [$0] } ?? view.subviews.flatMap { descendants(of: type, in: $0) }
    }
}
