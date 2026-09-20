import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ExpandedCataloguePresentationTests: XCTestCase {
    func testEveryCatalogueItemHasBothSuppliedArtworkCrops() throws {
        XCTAssertEqual(CatalogueDetails.all.count, 140)
        XCTAssertEqual(Set(CatalogueDetails.all.map(\.id)).count, 140)
        for item in CatalogueDetails.all {
            for glyph in [false, true] {
                let image = try XCTUnwrap(CatalogueArtwork.image(id: item.id, glyphOnly: glyph), item.id)
                let pixels = try XCTUnwrap(image.cgImage, item.id)
                XCTAssertGreaterThan(pixels.width, 40, item.id)
                XCTAssertGreaterThan(pixels.height, 40, item.id)
                let asset = "Catalogue-" + item.sheet.replacingOccurrences(of: ".png", with: "")
                let sheet = try XCTUnwrap(UIImage(named: asset)?.cgImage, asset)
                let crop = CatalogueArtwork.crop(category: item.category,
                    number: try XCTUnwrap(Int(item.code.dropFirst())), glyphOnly: glyph)
                XCTAssertTrue(CGRect(x: 0, y: 0, width: 1122, height: 1402).contains(crop), item.id)
                XCTAssertGreaterThan(sheet.width, 1000, asset)
            }
        }
        // A contact sheet makes mismatched crops reviewable, rather than
        // accepting a fallback SF Symbol as evidence that supplied art exists.
        let grid = LazyVGrid(columns: Array(repeating: GridItem(.fixed(62)), count: 10), spacing: 7) {
            ForEach(CatalogueDetails.all) { item in
                VStack(spacing: 2) {
                    ItemArtwork(id: item.id, size: 48)
                    Text(item.code).font(.system(size: 9)).foregroundStyle(.black)
                }
            }
        }.padding(10).background(GameplaySurface.ivory)
        try capture(try rendered(grid, size: CGSize(width: 703, height: 960)), name: "all-140-item-artwork")
    }

    func testDefaultAndPocketInsertInventoryRowsFitEveryPhoneWidth() throws {
        for width: CGFloat in [320, 375, 402] {
            for capacity in [2, 3] {
                var run = RunState(seed: "expanded-inventory-\(capacity)")
                let ids = capacity == 3
                    ? [Bookmarks.pocketInsert, Bookmarks.helpWanted, Bookmarks.weatherForecast, "bm_op_ed", "bm_stop_the_presses"]
                    : [Bookmarks.helpWanted, Bookmarks.weatherForecast, "bm_op_ed", "bm_stop_the_presses", Bookmarks.rollingPresses]
                run.bookmarks = ids.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5) }
                run.buffs = [Buffs.freshInk, Buffs.litmus, Buffs.rebind].prefix(capacity).map {
                    OwnedBuff(defID: $0, pricePaid: 5)
                }
                let model = GameModel(frozen: Game(run: run), page: .briefing)
                XCTAssertEqual(model.buffCapacity, capacity)
                let stripBounds = CGRect(x: 12, y: 12, width: width - 24, height: 44)
                let strip = InventoryStripGeometry(frame: stripBounds, bookmarkCount: 5, buffCapacity: capacity)
                let frames = (0..<5).map { strip.itemFrame(kind: .bookmark, index: $0) }
                    + (0..<capacity).map { strip.itemFrame(kind: .buff, index: $0) }
                for frame in frames {
                    XCTAssertTrue(stripBounds.insetBy(dx: -0.01, dy: -0.01).contains(frame))
                    XCTAssertGreaterThanOrEqual(frame.width, 28, "The actual 28-point supplied glyph must fit")
                }
                for pair in zip(frames, frames.dropFirst()) { XCTAssertLessThan(pair.0.maxX, pair.1.minX) }
                let image = try rendered(BookmarkRow(model: model, isGameplay: true, onTapBuff: { _ in })
                    .padding(12).background(GameplaySurface.ivory), size: CGSize(width: width, height: 68))
                try capture(image, name: "inventory-\(Int(width))-\(capacity)-buffs")
                // Probe the real rendered dark Buff bodies above their glyphs.
                // This detects a missing third card or an overflowing last card.
                let bands = try darkBands(in: image, logicalRow: 19)
                XCTAssertEqual(bands.count, capacity, "\(width)-point actual row: \(bands)")
                for (index, band) in bands.enumerated() {
                    let expected = strip.itemFrame(kind: .buff, index: index)
                    XCTAssertEqual(band.midX, expected.midX, accuracy: 2)
                    XCTAssertGreaterThanOrEqual(band.width, expected.width - 3)
                }
            }
        }
    }

    func testSavedDigitSquareAndLongChoicesRemainReadableOnPhonesAndLargeText() async throws {
        let game = try QAScoringFixture.modifierPreview.makeGame()
        let model = GameModel(frozen: game, page: .puzzle)
        let squares = Array(try XCTUnwrap(game.puzzle).board.blanks.prefix(5))
        let cases: [(String, ItemDecision, [String])] = [
            ("digits", ItemDecision(id: UUID(), sourceID: Markers.fork, contextKey: game.run.itemContextKey,
                kind: "marker.fork", title: "Fork Marker", detail: "Choose one card. The other returns to the Pool.",
                options: [ItemChoiceOption(id: "fork-0", title: "Take 4", digit: .four),
                          ItemChoiceOption(id: "fork-1", title: "Take 7", digit: .seven)],
                allowsCancel: false, consumedOnReveal: true), ["Fork", "Continue"]),
            ("squares", ItemDecision(id: UUID(), sourceID: Markers.crosscheck, contextKey: game.run.itemContextKey,
                kind: "marker.crosscheck", title: "Crosscheck Marker", detail: "Choose a square to inspect visible-rule candidates.",
                options: squares.map { ItemChoiceOption(id: "square-\($0.index)",
                    title: "Row \($0.row + 1), column \($0.col + 1)", square: $0) }), ["Crosscheck", "Cancel", "Confirm"]),
            ("long", ItemDecision(id: UUID(), sourceID: Markers.pledge, contextKey: game.run.itemContextKey,
                kind: "marker.pledge", title: "Pledge Marker", detail: Catalog.item(Markers.pledge)!.text,
                options: [ItemChoiceOption(id: "pay", title: "Pay 2 coins", detail: "Gain 100 placement Points. Your original card is placed only after you confirm this choice."),
                          ItemChoiceOption(id: "decline", title: "Place normally", detail: "Keep your coins. Complete the original placement without buying the extra Points.")]),
             ["Pledge", "Place without bonus", "Confirm", "Pay 2 coins", "Place normally"])
        ]
        let before = try model.game.encoded()
        for phone in [Phone(width: 375, height: 667, top: 20, bottom: 0),
                      Phone(width: 402, height: 874, top: 62, bottom: 34)] {
            for type in [DynamicTypeSize.large, .accessibility5] {
                for (name, decision, required) in cases {
                    try await inspect(decision: decision, model: model, phone: phone,
                                      type: type, name: name, required: required)
                }
            }
        }
        XCTAssertEqual(try model.game.encoded(), before, "Viewing saved choices cannot commit gameplay")
    }

    private struct Phone {
        let width: CGFloat, height: CGFloat, top: CGFloat, bottom: CGFloat
        var size: CGSize { CGSize(width: width, height: height) }
        var safeBounds: CGRect { CGRect(x: 0, y: top, width: width, height: height - top - bottom) }
    }

    private func inspect(decision: ItemDecision, model: GameModel, phone: Phone,
                         type: DynamicTypeSize, name: String, required: [String]) async throws {
        let host = UIHostingController(rootView: ItemDecisionSlip(model: model, decision: decision)
            .padding(.top, phone.top).padding(.bottom, phone.bottom)
            .environment(\.dynamicTypeSize, type).environment(\.cosmeticTheme, .standard)
            .environment(\.locale, Locale(identifier: "en_US"))
            .environment(\.colorScheme, .light).transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = host
        defer { window.isHidden = true; window.rootViewController = nil; oldKey?.makeKey() }
        window.makeKeyAndVisible()
        await settle(window)
        let scroll = scrollViews(in: host.view).max { $0.contentSize.height < $1.contentSize.height }
        let maximum = scroll.map { max(0, $0.contentSize.height - $0.bounds.height + $0.adjustedContentInset.bottom) } ?? 0
        let offsets = Array(stride(from: CGFloat.zero, to: maximum,
                                  by: max(44, (scroll?.bounds.height ?? phone.height) * 0.45))) + [maximum]
        var printed = ""
        for (index, offset) in offsets.enumerated() {
            scroll?.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
            await settle(window)
            let format = UIGraphicsImageRendererFormat(); format.scale = 2
            let image = UIGraphicsImageRenderer(size: phone.size, format: format).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try capture(image, name: "choice-\(name)-\(Int(phone.width))-\(type)-\(index)")
            let request = VNRecognizeTextRequest(); request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            var footerVisible = false
            for row in request.results ?? [] {
                guard let text = row.topCandidates(1).first?.string else { continue }
                let bounds = CGRect(x: row.boundingBox.minX * phone.width,
                    y: (1 - row.boundingBox.maxY) * phone.height,
                    width: row.boundingBox.width * phone.width, height: row.boundingBox.height * phone.height)
                if phone.safeBounds.insetBy(dx: -1, dy: -1).contains(bounds) { printed += " " + text }
                if normalized(text) == (decision.consumedOnReveal ? "continue" : "confirm") {
                    footerVisible = phone.safeBounds.insetBy(dx: -1, dy: -1).contains(bounds)
                }
            }
            XCTAssertTrue(footerVisible, "\(name) \(phone.width) \(type): confirmation must stay onscreen at every scroll offset")
        }
        for text in required {
            XCTAssertTrue(normalized(printed).contains(normalized(text)),
                          "\(name) \(phone.width) \(type): missing complete \(text), saw \(printed)")
        }
    }

    private func rendered<Content: View>(_ view: Content, size: CGSize) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.dynamicTypeSize, .large).environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light).transaction { $0.disablesAnimations = true })
        renderer.scale = 2
        return try XCTUnwrap(renderer.uiImage)
    }

    private func capture(_ image: UIImage, name: String) throws {
        let attachment = XCTAttachment(image: image); attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let directory = repo.appendingPathComponent("docs/qa/expanded-catalogue", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(name + ".png"), options: .atomic)
    }

    private func darkBands(in image: UIImage, logicalRow: CGFloat) throws -> [CGRect] {
        let cg = try XCTUnwrap(image.cgImage)
        let width = cg.width, height = cg.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        try data.withUnsafeMutableBytes { storage in
            let context = try XCTUnwrap(CGContext(data: storage.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let row = min(height - 1, max(0, Int(logicalRow * image.scale)))
        var ranges: [CGRect] = [], start: Int?
        for x in 0...width {
            let offset = (row * width + min(x, width - 1)) * 4
            let dark = x < width && data[offset] < 65 && data[offset + 1] < 75 && data[offset + 2] < 70
            if dark, start == nil { start = x }
            if !dark, let first = start {
                if x - first > Int(12 * image.scale) {
                    ranges.append(CGRect(x: CGFloat(first) / image.scale, y: logicalRow,
                        width: CGFloat(x - first) / image.scale, height: 1))
                }
                start = nil
            }
        }
        return ranges
    }

    private func normalized(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
    private func settle(_ window: UIWindow) async {
        window.layoutIfNeeded(); try? await Task.sleep(for: .milliseconds(100)); window.layoutIfNeeded()
    }
    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
}
