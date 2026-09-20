import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// These hosts use the production route surface and real pages. No legacy
/// Book wrapper is reconstructed by the test, and no fixture is persisted.
@MainActor
final class RunPageConsistencyTests: XCTestCase {
    func testBriefingResultsAndShopShareFullscreenInventoryAndPinnedDecisions() async throws {
        for device in Device.all {
            let baseline = try await renderRoute(.puzzle, device: device)
            for route in [BookPage.briefing, .results, .shop] {
                let rendered = try await renderRoute(route, device: device)
                let context = "\(device.name) \(route)"
                XCTAssertEqual(rendered.content.minX, baseline.content.minX, accuracy: 1, context)
                XCTAssertEqual(rendered.content.width, baseline.content.width, accuracy: 1, context)
                XCTAssertEqual(rendered.content.minY, baseline.content.minY, accuracy: 1,
                               "\(context): route must use the same top bar and 44-point inventory")
                XCTAssertLessThanOrEqual(rendered.content.maxY,
                                         device.size.height - device.insets.bottom + 1, context)
                XCTAssertEqual(rendered.inventory.width, baseline.inventory.width)
                XCTAssertEqual(rendered.inventory.height, 44)
                XCTAssertLessThan(meanDifference(rendered.inventory, baseline.inventory), 0.003,
                                  "\(context): all five Bookmarks and both Buffs must retain their in-game appearance")
                // Book spines/fore-edges used to consume 31 points plus page
                // margins. The actual route content now reaches the shared
                // 8-point gutter on phones and the centered 900-point tablet measure.
                XCTAssertEqual(rendered.content.width, min(900, device.size.width) - 16,
                               accuracy: 1, "\(context): old Book insets returned")
                assertIvoryEdges(rendered.image, context: context)
            }
        }
    }

    func testPlayedBoardRendersActualBlanksPlacedDigitsAndMarkersWithoutMutation() throws {
        let fixture = try playedBoard()
        let before = try fixture.game.encoded()
        let image = try boardImage(fixture.game, markers: fixture.game.run.markedSquares)
        let unmarked = try boardImage(fixture.game, markers: [:])
        let geometry = GameplayBoardGeometry(side: 360)
        let pixels = try Pixels(image)
        let blankCenter = geometry.cellFrame(fixture.blank).insetBy(dx: 11, dy: 9)
        let placedCenter = geometry.cellFrame(fixture.placed).insetBy(dx: 11, dy: 9)
        XCTAssertLessThan(pixels.darkCount(in: blankCenter), 4,
                          "An unfinished square must remain blank in the Results record")
        XCTAssertGreaterThan(pixels.darkCount(in: placedCenter), 10,
                             "The player's placed digit must be printed in its actual square")
        let markerFrame = geometry.cellFrame(fixture.marked)
        let markerCorner = CGRect(x: markerFrame.maxX - markerFrame.width * 0.38 - 1, y: markerFrame.minY + 1,
                                  width: markerFrame.width * 0.38, height: markerFrame.height * 0.38)
        XCTAssertGreaterThan(meanDifference(try pixels.crop(markerCorner),
                                            try Pixels(unmarked).crop(markerCorner)), 0.01,
                             "The actual earned marker must survive onto the Results board")
        XCTAssertEqual(try fixture.game.encoded(), before,
                       "Rendering a Results record must never solve, score or regenerate its board")
        attach(image, "results-actual-board-with-blanks-and-marker")
    }

    func testFogSnapshotCannotLeakMarkersEvenIfCallerSuppliesTheirDictionary() throws {
        let fixture = try playedBoard()
        var run = fixture.game.run
        run.puzzle?.boss = .fog
        let fog = Game(run: run)
        let supplied = try boardImage(fog, markers: fog.run.markedSquares)
        let concealed = try boardImage(fog, markers: [:])
        XCTAssertEqual(supplied.pngData(), concealed.pngData(),
                       "The snapshot owns Fog filtering; a supplied marker dictionary must not reveal it")
        let board = try XCTUnwrap(fog.puzzle?.board)
        let label = GridCellAccessibility.label(square: fixture.marked, digit: board[fixture.marked],
            provenance: board.filledBy[fixture.marked.index], marker: nil, markersAreHidden: true)
        XCTAssertFalse(label.localizedCaseInsensitiveContains("Crimson"))
        attach(supplied, "results-fog-keeps-markers-hidden")
    }

    private struct Device {
        let name: String
        let size: CGSize
        let insets: EdgeInsets
        static let all = [
            Device(name: "SE", size: CGSize(width: 375, height: 667), insets: EdgeInsets()),
            Device(name: "large-phone", size: CGSize(width: 440, height: 956),
                   insets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0)),
            Device(name: "iPad", size: CGSize(width: 1032, height: 1376),
                   insets: EdgeInsets(top: 24, leading: 0, bottom: 20, trailing: 0))
        ]
    }

    private struct RenderedRoute {
        let image: UIImage
        let content: CGRect
        let inventory: Pixels
    }

    private func renderRoute(_ route: BookPage, device: Device) async throws -> RenderedRoute {
        let model = GameModel(frozen: try routeGame(route), page: route)
        let before = try model.game.encoded()
        let flipper = PageFlipper()
        let ready = expectation(description: "\(device.name)-\(route) real route layout")
        var contentFrame = CGRect.zero
        var reported = false
        let surface = RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Help", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: device.insets, onTapBuff: { _ in }) {
            page(route, model: model)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                    contentFrame = frame
                    if !reported, frame.width > 0, frame.height > 0 {
                        reported = true
                        ready.fulfill()
                    }
                }
        }
        .frame(width: device.size.width, height: device.size.height)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
        .environment(\.levelPalette, .forDisplay(slot: .easy))
        .environment(\.scenePhase, .inactive)
        .environment(\.colorScheme, .light)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: surface)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: device.size)
        window.rootViewController = host
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        window.layoutIfNeeded()
        let initial = screenshot(window)
        let inventoryRect = CGRect(x: contentFrame.minX + 4, y: contentFrame.minY - 50,
                                   width: contentFrame.width - 8, height: 44)
        let inventory = try Pixels(initial).crop(inventoryRect)
        XCTAssertEqual(model.run.bookmarks.count, 5)
        XCTAssertEqual(model.run.buffs.count, 2)
        // Read the card paper beside the supplied illustration, whose white
        // strokes can cross its lower center. This also
        // catches old light Buff tabs, empty slots and a missing seventh slot.
        let strip = InventoryStripGeometry(frame: CGRect(x: 0, y: 0, width: inventory.width,
                                                        height: inventory.height), bookmarkCount: 5)
        for (kind, count) in [(ItemKind.bookmark, 5), (.buff, 2)] {
            for index in 0..<count {
                let slot = strip.itemFrame(kind: kind, index: index)
                let brightness = inventory.brightness(x: Int(slot.minX + 4), y: 32)
                if kind == .buff { XCTAssertLessThan(brightness, 0.3, "\(route) Buff \(index)") }
                else { XCTAssertGreaterThan(brightness, 0.7, "\(route) Bookmark \(index)") }
            }
        }
        if route == .results || route == .shop {
            let title = route == .results ? "cashout" : "continue"
            let decision = try recognizedFrame(title, image: initial)
            XCTAssertGreaterThan(decision.minY, contentFrame.midY)
            XCTAssertLessThanOrEqual(decision.maxY, device.size.height - device.insets.bottom)
            XCTAssertTrue(scrollViews(in: host.view).isEmpty,
                          "\(route): the complete page must fit without a scroll container")
        }
        XCTAssertEqual(try model.game.encoded(), before, "Hosted route rendering cannot mutate the saved game")
        attach(initial, "\(device.name)-\(route)-fullscreen")
        return RenderedRoute(image: initial, content: contentFrame, inventory: inventory)
    }

    @ViewBuilder private func page(_ route: BookPage, model: GameModel) -> some View {
        switch route {
        case .puzzle:
            PuzzlePageView(model: model, puzzle: model.puzzle!, isClockRunning: false)
        case .briefing:
            PuzzleBriefingView(model: model, canStartPresentation: { false }, isPresentationCovered: true)
        case .results:
            ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
        case .shop:
            ShopPageView(model: model, shop: model.shop!, onClaimMarker: { _ in })
        case .achievements:
            EmptyView()
        }
    }

    private func routeGame(_ route: BookPage) throws -> Game {
        var run = RunState(seed: "run-page-consistency")
        run.bookmarks = Bookmarks.all.prefix(5).map { OwnedBookmark(defID: $0.id, boughtAtLevel: 1, pricePaid: 0) }
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 0), OwnedBuff(defID: Buffs.redraw, pricePaid: 0)]
        var game = Game(run: run)
        if route != .briefing { try game.startPuzzle() }
        if route == .results || route == .shop {
            var won = game.run
            let target = won.puzzle?.target ?? 1_000
            won.puzzle?.score = target
            won.puzzle?.phase = .won
            game = Game(run: won)
        }
        if route == .shop { _ = try game.cashOut(); game.openShop() }
        return game
    }

    private func playedBoard() throws -> (game: Game, blank: Square, placed: Square, marked: Square) {
        var game = Game(seed: "results-real-board")
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        let blanks = puzzle.board.blanks
        let placed = blanks[0]
        let digit = puzzle.board.correctDigit(at: placed)
        XCTAssertTrue(puzzle.pool.take(digit))
        puzzle.board.fill(placed, with: digit, by: .player)
        puzzle.phase = .won
        puzzle.score = puzzle.target
        run.puzzle = puzzle
        run.markers = [OwnedMarker(defID: "mk_crimson", boughtAtLevel: 1, pricePaid: 0, squares: [blanks[2]])]
        return (Game(run: run), blanks[1], placed, blanks[2])
    }

    private func boardImage(_ game: Game, markers: [Square: OwnedMarker]) throws -> UIImage {
        let puzzle = try XCTUnwrap(game.puzzle)
        let renderer = ImageRenderer(content: GameplayBoardSnapshot(board: puzzle.board, markers: markers, puzzle: puzzle)
            .frame(width: 360, height: 360)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.levelPalette, .forDisplay(slot: .easy))
            .environment(\.colorScheme, .light))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func screenshot(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func recognizedFrame(_ word: String, image: UIImage) throws -> CGRect {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let row = try XCTUnwrap(request.results?.first {
            $0.topCandidates(1).first?.string.lowercased().filter { $0.isLetter }.contains(word) == true
        }, "Visible decision \(word) missing")
        let box = row.boundingBox
        return CGRect(x: box.minX * image.size.width, y: (1 - box.maxY) * image.size.height,
                      width: box.width * image.size.width, height: box.height * image.size.height)
    }

    private func attach(_ image: UIImage, _ name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertIvoryEdges(_ image: UIImage, context: String) {
        guard let pixels = try? Pixels(image) else { return XCTFail("Missing pixels") }
        for y in stride(from: 12, to: pixels.height - 12, by: 31) {
            for x in [2, pixels.width - 3] {
                XCTAssertGreaterThan(pixels.brightness(x: x, y: y), 0.82,
                                     "\(context): exposed book edge/spine at \(x),\(y)")
            }
        }
    }

    private func meanDifference(_ lhs: Pixels, _ rhs: Pixels) -> Double {
        guard lhs.width == rhs.width, lhs.height == rhs.height else { return 1 }
        return zip(lhs.bytes, rhs.bytes).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) }
            / Double(max(1, lhs.bytes.count)) / 255
    }

    private struct Pixels {
        let width: Int
        let height: Int
        let bytes: [UInt8]
        init(_ image: UIImage) throws {
            let cg = try XCTUnwrap(image.cgImage)
            width = cg.width
            height = cg.height
            var data = [UInt8](repeating: 0, count: width * height * 4)
            let context = try XCTUnwrap(CGContext(data: &data, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
            bytes = data
        }
        private init(width: Int, height: Int, bytes: [UInt8]) {
            self.width = width; self.height = height; self.bytes = bytes
        }
        func brightness(x: Int, y: Int) -> Double {
            guard x >= 0, y >= 0, x < width, y < height else { return 0 }
            let offset = (y * width + x) * 4
            return (Double(bytes[offset]) + Double(bytes[offset + 1]) + Double(bytes[offset + 2])) / 765
        }
        func crop(_ rect: CGRect) throws -> Pixels {
            let x = Int(rect.minX.rounded()), y = Int(rect.minY.rounded())
            let w = Int(rect.width.rounded()), h = Int(rect.height.rounded())
            XCTAssertGreaterThanOrEqual(x, 0); XCTAssertGreaterThanOrEqual(y, 0)
            XCTAssertLessThanOrEqual(x + w, width); XCTAssertLessThanOrEqual(y + h, height)
            guard x >= 0, y >= 0, x + w <= width, y + h <= height else {
                throw NSError(domain: "RunPageConsistency", code: 1)
            }
            return Pixels(width: w, height: h, bytes: (y..<(y + h)).flatMap { row in
                Array(bytes[((row * width + x) * 4)..<((row * width + x + w) * 4)])
            })
        }
        func darkCount(in rect: CGRect) -> Int {
            var count = 0
            for y in max(0, Int(rect.minY))..<min(height, Int(rect.maxY)) {
                for x in max(0, Int(rect.minX))..<min(width, Int(rect.maxX)) {
                    if brightness(x: x, y: y) < 0.35 { count += 1 }
                }
            }
            return count
        }
    }
}
