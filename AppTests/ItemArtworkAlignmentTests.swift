import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Measures the supplied artwork's visible pixels, then renders the actual
/// inventory cards and run pages. A centered image frame alone is insufficient:
/// the former opaque sheet crops contained their own off-center card backing.
@MainActor
final class ItemArtworkAlignmentTests: XCTestCase {
    func testEveryBookmarkGlyphHasTransparentSurroundingsAndCenteredVisibleArtwork() throws {
        XCTAssertEqual(Bookmarks.all.count, 50)
        try assertNormalizedGlyphs(Bookmarks.all)
    }

    func testEveryBuffGlyphHasTransparentSurroundingsAndCenteredVisibleArtwork() throws {
        XCTAssertEqual(Buffs.all.count, 40)
        try assertNormalizedGlyphs(Buffs.all)
    }

    func testInventoryArtworkIsActuallyCenteredWithinItsPrintedCard() throws {
        let ids = [Bookmarks.morningEdition, Bookmarks.localGossip,
                   Bookmarks.puzzleCorner, Buffs.freshInk, Buffs.peek]
        for id in ids {
            let def = try XCTUnwrap(Catalog.item(id))
            for width: CGFloat in [40, 44, 52] {
                let image = try render(inventoryCard(def, width: width), size: CGSize(width: width, height: 44), scale: 4)
                let pixels = try Raster(image)
                let isBuff = def.kind == .buff
                // Exclude the printed card's outer stroke, gilt and shadow.
                // Only actual glyph ink can satisfy this color test inside it.
                let bounds = try XCTUnwrap(pixels.bounds(in: CGRect(x: 6 * 4, y: 6 * 4,
                    width: (width - 12) * 4, height: 32 * 4)) { r, g, b, a in
                    a > 240 && (isBuff ? min(r, g, b) > 145 : max(r, g, b) < 125)
                }, "\(id): the rendered inventory card must contain visible artwork")
                XCTAssertEqual(bounds.midX / 4, width / 2, accuracy: 0.6, "\(id), width \(width): horizontal ink center")
                XCTAssertEqual(bounds.midY / 4, 22, accuracy: 0.6, "\(id), width \(width): vertical ink center")
            }
        }
    }

    func testCaptureEveryBookmarkAndBuffOnItsRealInventoryMaterial() throws {
        for (name, definitions) in [("bookmarks", Bookmarks.all), ("buffs", Buffs.all)] {
            let columns = Array(repeating: GridItem(.fixed(150), spacing: 10), count: 5)
            let sheet = VStack(alignment: .leading, spacing: 16) {
                Text(name == "bookmarks" ? "50 Bookmarks · inventory artwork" : "40 Buffs · inventory artwork")
                    .font(.system(size: 24, weight: .semibold))
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(definitions, id: \.id) { def in
                        VStack(spacing: 7) {
                            self.inventoryCard(def, width: 56)
                            Text(def.name)
                                .font(.system(size: 12, weight: .medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .frame(height: 30)
                        }
                        .frame(width: 150, height: 88)
                    }
                }
            }
            .padding(20)
            .foregroundStyle(GameplaySurface.ink)
            .background { GameplaySurfaceBackground() }
            let size = CGSize(width: 830, height: name == "bookmarks" ? 1080 : 880)
            attach(try render(sheet, size: size, scale: 2), name: "artwork-alignment-all-\(name)")
        }
    }

    func testCapturePuzzleAndShopWithTheSameCenteredInventoryAtBothPhoneSizes() async throws {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)] {
            for isShop in [false, true] {
                var run = RunState(seed: "inventory-artwork-alignment")
                run.coins = 50
                run.bookmarks = [Bookmarks.morningEdition, Bookmarks.localGossip, Bookmarks.puzzleCorner,
                                 Bookmarks.carbonPaper, Bookmarks.readersCircle].map {
                    OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5)
                }
                run.buffs = [Buffs.peek, Buffs.freshInk].map { OwnedBuff(defID: $0, pricePaid: 4) }
                var game = Game(run: run)
                if isShop {
                    run.shop = ShopState(offers: [Bookmarks.carbonPaper, Bookmarks.readersCircle,
                        "mk_ladder", "mk_eraser", Buffs.freshInk].enumerated().map {
                        ShopOffer(slot: $0.offset, defID: $0.element,
                                  price: Catalog.item($0.element)!.listedPrice)
                    })
                    game = Game(run: run)
                } else {
                    try game.startPuzzle()
                }
                let model = GameModel(frozen: game, page: isShop ? .shop : .puzzle)
                let saved = try model.game.encoded()
                let flipper = PageFlipper()
                let surface = RunPageSurface(model: model, flipper: flipper, controls: [
                    StripControl(systemImage: "questionmark", label: "Run information", action: {}),
                    StripControl(systemImage: "gearshape", label: "Settings", action: {})
                ], safeAreaInsets: EdgeInsets(top: size.height < 700 ? 20 : 62, leading: 0,
                                              bottom: size.height < 700 ? 0 : 34, trailing: 0),
                    onTapBuff: { _ in }) {
                    Group {
                        if let shop = model.shop, isShop {
                            ShopPageView(model: model, shop: shop, onClaimMarker: { _ in })
                        } else if let puzzle = model.puzzle {
                            PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: false)
                        }
                    }
                }
                .frame(width: size.width, height: size.height)
                .environment(flipper)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
                .environment(\.levelPalette, .forDisplay(slot: .easy))
                .environment(\.scenePhase, .inactive)
                .environment(\.bossMotionIsActive, false)
                .environment(\.gameReduceMotion, true)
                .environment(\.dynamicTypeSize, .large)
                .environment(\.colorScheme, .light)
                .environment(\.locale, Locale(identifier: "en_US"))
                .transaction { $0.disablesAnimations = true }
                let image = try await captureHosted(surface, size: size)
                attach(image, name: "artwork-alignment-\(isShop ? "shop" : "puzzle")-\(Int(size.width))x\(Int(size.height))")
                XCTAssertEqual(try model.game.encoded(), saved,
                               "Centering and rendering inventory artwork cannot mutate the saved game")
                flipper.cancel()
            }
        }
    }

    private func assertNormalizedGlyphs(_ definitions: [ItemDef]) throws {
        for def in definitions {
            let image = try XCTUnwrap(CatalogueArtwork.image(id: def.id, glyphOnly: true), def.id)
            let pixels = try Raster(image)
            XCTAssertEqual(pixels.width, 128, def.id)
            XCTAssertEqual(pixels.height, 128, def.id)
            let corners = [(0, 0), (127, 0), (0, 127), (127, 127)]
            for (x, y) in corners {
                XCTAssertEqual(pixels.channel(x: x, y: y, 3), 0, "\(def.id): glyph must not carry a second paper/dark card")
            }
            let bounds = try XCTUnwrap(pixels.bounds { _, _, _, alpha in alpha > 16 }, def.id)
            XCTAssertEqual(bounds.midX, 64, accuracy: 1, "\(def.id): visible artwork horizontal center")
            XCTAssertEqual(bounds.midY, 64, accuracy: 1, "\(def.id): visible artwork vertical center")
            XCTAssertGreaterThanOrEqual(max(bounds.width, bounds.height), 110, "\(def.id): glyph must remain legible")
            XCTAssertLessThanOrEqual(max(bounds.width, bounds.height), 116, "\(def.id): equal breathing room around the artwork")
            XCTAssertGreaterThan(pixels.count { _, _, _, alpha in alpha > 128 }, 100,
                                 "\(def.id): extraction must not erase the symbol")
        }
    }

    private func inventoryCard(_ def: ItemDef, width: CGFloat) -> some View {
        InventoryBookmark(def: def,
            colour: def.kind == .buff ? GameplaySurface.ink : GameplaySurface.ivory,
            ink: def.kind == .buff ? GameplaySurface.ivory : GameplaySurface.ink,
            flagged: def.kind == .buff, slot: 0, pulling: false, asleep: false,
            fired: false, explaining: .constant(false), isGameplay: true)
            .frame(width: width, height: 44)
            .environment(\.gameReduceMotion, true)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.cosmeticTheme, .standard)
    }

    private func render<V: View>(_ view: V, size: CGSize, scale: CGFloat) throws -> UIImage {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light))
        renderer.scale = scale
        return try XCTUnwrap(renderer.uiImage)
    }

    private func captureHosted<V: View>(_ view: V, size: CGSize) async throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(250))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private struct Raster {
        let width: Int
        let height: Int
        let bytes: [UInt8]

        init(_ image: UIImage) throws {
            let cgImage = try XCTUnwrap(image.cgImage)
            width = cgImage.width
            height = cgImage.height
            var bytes = [UInt8](repeating: 0, count: width * height * 4)
            let context = try XCTUnwrap(CGContext(data: &bytes, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.bytes = bytes
        }

        func channel(x: Int, y: Int, _ channel: Int) -> UInt8 { bytes[(y * width + x) * 4 + channel] }

        func bounds(in region: CGRect? = nil, matching predicate: (UInt8, UInt8, UInt8, UInt8) -> Bool) -> CGRect? {
            let region = region ?? CGRect(x: 0, y: 0, width: width, height: height)
            var left = width, right = -1, top = height, bottom = -1
            for y in max(0, Int(region.minY))..<min(height, Int(region.maxY)) {
                for x in max(0, Int(region.minX))..<min(width, Int(region.maxX)) {
                    let offset = (y * width + x) * 4
                    if predicate(bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]) {
                        left = min(left, x); right = max(right, x)
                        top = min(top, y); bottom = max(bottom, y)
                    }
                }
            }
            return right >= left ? CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1) : nil
        }

        func count(matching predicate: (UInt8, UInt8, UInt8, UInt8) -> Bool) -> Int {
            stride(from: 0, to: bytes.count, by: 4).reduce(0) { count, offset in
                count + (predicate(bytes[offset], bytes[offset + 1], bytes[offset + 2], bytes[offset + 3]) ? 1 : 0)
            }
        }
    }
}
