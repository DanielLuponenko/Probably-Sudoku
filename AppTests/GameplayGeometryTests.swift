import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class GameplayGeometryTests: XCTestCase {
    func testHandOverflowArrowsTrackHiddenEdgesAndIgnoreElasticOverscroll() {
        func edges(_ x: CGFloat, _ width: CGFloat, viewport: CGFloat = 300) -> HandOverflowEdges {
            HandOverflowEdges(content: CGRect(x: x, y: 0, width: width, height: 52),
                              viewportWidth: viewport)
        }
        XCTAssertEqual(edges(0, 300), HandOverflowEdges())
        XCTAssertEqual(edges(-8, 295), HandOverflowEdges(), "A short Hand bouncing does not hide more cards")
        XCTAssertFalse(edges(0, 560).leading)
        XCTAssertTrue(edges(0, 560).trailing)
        XCTAssertTrue(edges(-100, 560).leading)
        XCTAssertTrue(edges(-100, 560).trailing)
        XCTAssertTrue(edges(-260, 560).leading)
        XCTAssertFalse(edges(-260, 560).trailing)
        XCTAssertFalse(edges(20, 560).leading, "Left-edge bounce must not advertise nonexistent cards")
        XCTAssertFalse(edges(-280, 560).trailing, "Right-edge bounce must not advertise nonexistent cards")
    }

    func testLitmusVerdictsUseDifferentVisibleShapesWithTheSameInkColor() throws {
        func alphaMask(_ match: Bool) throws -> [UInt8] {
            let renderer = ImageRenderer(content: LitmusIndicator(isMatch: match, size: 44)
                .frame(width: 24, height: 24))
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
            try rgba.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress,
                    width: image.width, height: image.height, bitsPerComponent: 8,
                    bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
        }
        let match = try alphaMask(true)
        let mismatch = try alphaMask(false)
        XCTAssertGreaterThan(match.filter { $0 > 0 }.count, 20)
        XCTAssertGreaterThan(mismatch.filter { $0 > 0 }.count, 20)
        XCTAssertNotEqual(match, mismatch, "Litmus cannot rely only on green and red cell fills")
    }

    func testLiveGridReportsEverySquareInsideItsPhysicalFrame() async throws {
        for width: CGFloat in [320, 393, 430, 680] {
            let model = GameModel(frozen: try fixture(handCount: 4), page: .puzzle)
            let frames = try await capture(model: model, width: width)
            let board = try XCTUnwrap(frames[NumberReturnMotionAnchor.grid])
            let geometry = NumberReturnGeometry(frames: frames)
            let first = try XCTUnwrap(geometry.cell(Square(0)))
            let last = try XCTUnwrap(geometry.cell(Square(80)))
            XCTAssertEqual(board.width, board.height, accuracy: 0.1)
            XCTAssertGreaterThan(first.minX, board.minX + 3)
            XCTAssertGreaterThan(first.minY, board.minY + 3)
            XCTAssertLessThan(last.maxX, board.maxX - 3)
            XCTAssertLessThan(last.maxY, board.maxY - 3)
            XCTAssertEqual(first.width, first.height, accuracy: 0.1)
            XCTAssertLessThan(first.width, board.width / 9,
                              "The sage rim is not part of a playable square")
            for square in Square.all {
                let frame = try XCTUnwrap(geometry.cell(square))
                XCTAssertEqual(frame.width, first.width, accuracy: 0.1)
                XCTAssertEqual(frame.height, first.height, accuracy: 0.1)
                XCTAssertEqual(frame.minX, first.minX + CGFloat(square.col) * first.width, accuracy: 0.2)
                XCTAssertEqual(frame.minY, first.minY + CGFloat(square.row) * first.height, accuracy: 0.2)
            }
        }
    }

    func testActualArrangedOverflowCardsRetainSeparateMeasuredTargets() async throws {
        let model = GameModel(frozen: try fixture(handCount: 12), page: .puzzle)
        let canonical = model.handCards.map(\.id)
        model.arrangeHand(.ascending)
        let frames = try await capture(model: model, width: 320)
        let viewport = try XCTUnwrap(frames[NumberReturnMotionAnchor.hand])
        let geometry = NumberReturnGeometry(frames: frames)
        let displayed = model.displayedHandCards
        let arrange = try XCTUnwrap(frames["hand-arrangement-control"])
        XCTAssertGreaterThanOrEqual(arrange.height, 44)
        XCTAssertEqual(model.handCards.map(\.id), canonical)
        XCTAssertEqual(displayed.count, 12)
        var previousX: CGFloat?
        var clippedCount = 0
        for card in displayed {
            let frame = try XCTUnwrap(frames[NumberReturnMotionAnchor.card(card.id)])
            XCTAssertGreaterThanOrEqual(frame.minY, arrange.maxY,
                                       "Arrange and card hit regions must not overlap")
            if let previousX { XCTAssertGreaterThan(frame.midX, previousX) }
            previousX = frame.midX
            XCTAssertGreaterThanOrEqual(frame.width, 44)
            let point = try XCTUnwrap(geometry.cardPoint(card.id))
            if frame.midX > viewport.maxX {
                clippedCount += 1
                XCTAssertEqual(point.x, viewport.maxX - frame.width / 2, accuracy: 0.1)
            } else if frame.midX >= viewport.minX + frame.width / 2,
                      frame.midX <= viewport.maxX - frame.width / 2 {
                XCTAssertEqual(point.x, frame.midX, accuracy: 0.1)
                XCTAssertEqual(point.y, frame.midY, accuracy: 0.1)
            }
        }
        XCTAssertGreaterThan(clippedCount, 0, "Bonus cards overflow horizontally without resizing the board")
        let duplicates = Dictionary(grouping: displayed, by: \.digit).values.first { $0.count > 1 }
        let pair = try XCTUnwrap(duplicates)
        XCTAssertNotEqual(frames[NumberReturnMotionAnchor.card(pair[0].id)],
                          frames[NumberReturnMotionAnchor.card(pair[1].id)])
    }

    func testMissingGeometryNeverInventsEvenlySpacedCardOrOuterGridTargets() {
        let geometry = NumberReturnGeometry(frames: [
            NumberReturnMotionAnchor.grid: CGRect(x: 10, y: 90, width: 360, height: 360),
            NumberReturnMotionAnchor.hand: CGRect(x: 10, y: 470, width: 360, height: 60)
        ])
        XCTAssertNil(geometry.cell(Square(0)))
        XCTAssertNil(geometry.cardPoint(UUID()))
        XCTAssertNil(geometry.poolPoint)
    }

    func testFogAccessibilityNeverNamesHiddenMarkerOrItsEffect() {
        let square = Square(17)
        let marker = OwnedMarker(defID: "mk_copper", boughtAtLevel: 1,
                                 pricePaid: 0, squares: [square])
        let clear = GridCellAccessibility.label(square: square, digit: nil, provenance: nil,
                                                marker: marker, markersAreHidden: false)
        XCTAssertTrue(clear.contains(marker.def.name))
        XCTAssertTrue(clear.contains(marker.def.text))
        let hidden = GridCellAccessibility.label(square: square, digit: nil, provenance: nil,
                                                 marker: marker, markersAreHidden: true)
        XCTAssertEqual(hidden, GridCellAccessibility.label(square: square, digit: nil, provenance: nil,
                                                           marker: nil, markersAreHidden: true))
        let given = GridCellAccessibility.label(square: square, digit: .one, provenance: .given,
                                                marker: marker, markersAreHidden: false)
        XCTAssertTrue(given.contains("inactive under given number"))
    }

    private func fixture(handCount: Int) throws -> Game {
        var game = Game(seed: "live-gameplay-geometry")
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        // Pull valid duplicate copies from the actual pool, while retaining
        // canonical deal order independent of the view's requested sort.
        while puzzle.hand.count < handCount {
            let digit = try XCTUnwrap(Digit.all.reversed().first { puzzle.pool[$0] > 0 })
            XCTAssertTrue(puzzle.pool.take(digit))
            puzzle.hand.append(digit)
        }
        run.puzzle = puzzle
        return Game(run: run)
    }

    private func capture(model: GameModel, width: CGFloat) async throws -> [String: CGRect] {
        let ready = expectation(description: "Live grid and card geometry at \(width)pt")
        var frames: [String: CGRect] = [:]
        var didReport = false
        let board = try XCTUnwrap(model.puzzle?.board)
        let content = VStack(spacing: 12) {
            GridView(model: model, board: board).frame(width: width, height: width)
            HandStripView(model: model, handSize: model.hand.count).frame(width: width)
        }
        .frame(width: width, height: width + 120, alignment: .top)
        .coordinateSpace(name: NumberReturnMotionAnchor.space)
        .environment(\.cosmeticTheme, .standard)
        .transaction { $0.disablesAnimations = true }
        .onPreferenceChange(NumberReturnMotionFrames.self) { latest in
            frames = latest
            if !didReport, Square.all.allSatisfy({ latest[NumberReturnMotionAnchor.cell($0)] != nil }),
               model.handCards.allSatisfy({ latest[NumberReturnMotionAnchor.card($0.id)] != nil }) {
                didReport = true
                ready.fulfill()
            }
        }
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: width, height: width + 120)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        window.layoutIfNeeded()
        return frames
    }
}
