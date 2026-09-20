import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class MarkerInspectionLayoutTests: XCTestCase {
    func testJadeAtAllFourBoardCornersFitsBothPhoneSizesWithoutMovingGameplay() async throws {
        for phone in Phone.all {
            let model = GameModel(frozen: try fixture(markerID: Markers.jade), page: .puzzle)
            model.tapHand(0)
            try await withHostedPuzzle(model: model, phone: phone, type: .large) { host in
                let before = try model.game.encoded()
                let selection = model.selectedHandIndex
                let originalFrames = host.frames()
                attach(screenshot(host.window), name: "marker-resting-\(phone.name)")
                for square in [Square(0), Square(8), Square(72), Square(80)] {
                    let cell = try host.cellFrame(square)
                    var feedbackCount = 0
                    let owner = UUID()
                    host.presenter.begin(square: square, model: model, cellFrame: cell,
                                         source: .touch(owner), feedback: { feedbackCount += 1 })
                    try await settle(host.window)
                    assertPlacement(host.presenter.popupFrame, cell: cell, viewport: phone.viewport)
                    XCTAssertEqual(feedbackCount, 1)
                    XCTAssertEqual(host.frames(), originalFrames, "Inspecting cannot move the board, Hand, or cells")
                    XCTAssertEqual(model.selectedHandIndex, selection)
                    XCTAssertEqual(try model.game.encoded(), before)
                    let scroll = try popupScroll(in: host.window, frame: host.presenter.popupFrame)
                    XCTAssertLessThanOrEqual(scroll.contentSize.height, scroll.bounds.height + 2,
                                             "Normal Jade text must fit without scrolling at \(phone.name) \(square)")
                    let image = screenshot(host.window)
                    attach(image, name: "marker-inspected-\(phone.name)-\(square)")
                    let text = try recognizedText(image, in: host.presenter.popupFrame)
                    XCTAssertTrue(text.contains("jademarker"), text)
                    let info = try XCTUnwrap(MarkerInspectionInfo.make(square: square, run: model.run))
                    XCTAssertTrue(text.contains(normalized(info.compactExplanation)),
                                  "The complete current Jade explanation, including its penalty caveat, must be readable: \(text)")
                    host.presenter.endTouch(owner: owner)
                    try await settle(host.window)
                    XCTAssertNil(host.presenter.session)
                    XCTAssertEqual(host.presenter.popupFrame, .zero)
                    XCTAssertEqual(host.frames(), originalFrames)
                    XCTAssertEqual(model.selectedHandIndex, selection)
                    XCTAssertEqual(try model.game.encoded(), before)
                }
            }
        }
    }

    func testLongGivenAndFilledExplanationsStayReadableAtAccessibilitySize() async throws {
        for phone in Phone.all {
            let model = GameModel(frozen: try fixture(markerID: Markers.rose), page: .puzzle)
            let puzzle = try XCTUnwrap(model.puzzle)
            let given = try XCTUnwrap(Square.all.first { puzzle.board.filledBy[$0.index] == .given })
            let filled = try XCTUnwrap(Square.all.first { puzzle.board.filledBy[$0.index] == .player })
            try await withHostedPuzzle(model: model, phone: phone, type: .accessibility5) { host in
                let before = try model.game.encoded()
                let originalFrames = host.frames()
                for square in [given, filled] {
                    let info = try XCTUnwrap(MarkerInspectionInfo.make(square: square, run: model.run))
                    let cell = try host.cellFrame(square)
                    host.presenter.begin(square: square, model: model, cellFrame: cell,
                                         source: .accessibility, feedback: {})
                    try await settle(host.window)
                    assertPlacement(host.presenter.popupFrame, cell: cell, viewport: phone.viewport)
                    XCTAssertEqual(host.frames(), originalFrames)
                    let scroll = try popupScroll(in: host.window, frame: host.presenter.popupFrame)
                    XCTAssertGreaterThan(scroll.bounds.height, 0)
                    // Canonical compact copy may fit on a taller phone. When it
                    // does not, inspect every viewport rather than requiring a
                    // scrollbar merely because the text size is accessible.
                    let maximumOffset = max(0, scroll.contentSize.height - scroll.bounds.height)
                    let top = screenshot(host.window)
                    attach(top, name: "marker-AX5-\(phone.name)-\(info.availability)-top")
                    let topText = try recognizedText(top, in: host.presenter.popupFrame)
                    XCTAssertTrue(topText.contains("dismiss"),
                                  "Dismissal must be visible immediately without scrolling: \(topText)")
                    var readableText = topText
                    var offset: CGFloat = 0
                    while offset < maximumOffset {
                        offset = min(maximumOffset, offset + max(1, scroll.bounds.height * 0.5))
                        scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                        try await settle(host.window)
                        readableText += try recognizedText(screenshot(host.window), in: host.presenter.popupFrame)
                    }
                    let expectedCopy = [info.title, info.compactExplanation, info.inspectionNotice]
                        .compactMap { $0 }.joined(separator: " ")
                    let expectedWords = expectedCopy.split { !$0.isLetter && !$0.isNumber }
                        .map { normalized(String($0)) }.filter { $0.count >= 3 }
                    for word in Set(expectedWords) {
                        XCTAssertTrue(readableText.contains(word),
                                      "The complete current explanation must remain readable at AX5; missing \(word): \(readableText)")
                    }
                    let bottom = screenshot(host.window)
                    attach(bottom, name: "marker-AX5-\(phone.name)-\(info.availability)-bottom")
                    let text = try recognizedText(bottom, in: host.presenter.popupFrame)
                    XCTAssertTrue(text.contains("dismiss"), "Explicit accessible dismissal must remain visible after scrolling: \(text)")
                    XCTAssertEqual(try model.game.encoded(), before)
                    host.presenter.dismiss()
                    try await settle(host.window)
                    XCTAssertNil(host.presenter.session)
                    XCTAssertEqual(host.frames(), originalFrames)
                }
            }
        }
    }

    private struct Phone {
        let name: String
        let size: CGSize
        let insets: EdgeInsets
        var viewport: CGRect {
            CGRect(x: 0, y: insets.top, width: size.width, height: size.height - insets.top - insets.bottom)
        }
        static let all = [
            Phone(name: "SE", size: CGSize(width: 375, height: 667), insets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0)),
            Phone(name: "17Pro", size: CGSize(width: 402, height: 874), insets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0))
        ]
    }

    private struct HostedPuzzle {
        let window: UIWindow
        let presenter: MarkerInspectionPresenter
        let frames: () -> [String: CGRect]
        let pageFrame: () -> CGRect
        func cellFrame(_ square: Square) throws -> CGRect {
            try XCTUnwrap(frames()[NumberReturnMotionAnchor.cell(square)])
                .offsetBy(dx: pageFrame().minX, dy: pageFrame().minY)
        }
    }

    private func withHostedPuzzle(model: GameModel, phone: Phone, type: DynamicTypeSize,
                                  check: (HostedPuzzle) async throws -> Void) async throws {
        let presenter = MarkerInspectionPresenter()
        let ready = expectation(description: "Live marker board geometry")
        var frames: [String: CGRect] = [:]
        var pageFrame = CGRect.zero
        var reported = false
        let content = GameplayShell(model: model, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], onTapBuff: { _ in }, inspectionPresenter: presenter) {
            PuzzlePageView(model: model, puzzle: model.puzzle!, isClockRunning: false)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { pageFrame = $0 }
        }
        .padding(phone.insets)
        .frame(width: phone.size.width, height: phone.size.height)
        .background { GameplaySurfaceBackground() }
        .environment(\.scenePhase, .active)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.levelPalette, .forDisplay(slot: .easy))
        .environment(\.dynamicTypeSize, type)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US"))
        .onPreferenceChange(NumberReturnMotionFrames.self) { latest in
            frames = latest
            if !reported, latest[NumberReturnMotionAnchor.cell(Square(80))] != nil {
                reported = true
                ready.fulfill()
            }
        }
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = controller
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        try await settle(window)
        try await check(HostedPuzzle(window: window, presenter: presenter, frames: { frames }, pageFrame: { pageFrame }))
    }

    private func fixture(markerID: String) throws -> Game {
        var game = Game(seed: "marker-inspection-layout")
        try game.startPuzzle()
        var run = game.run
        var puzzle = try XCTUnwrap(run.puzzle)
        let filled = try XCTUnwrap(puzzle.board.blanks.first)
        let given = try XCTUnwrap(Square.all.first { puzzle.board.filledBy[$0.index] == .given })
        // Arrange a legal, conserved played board before testing read-only UI.
        let digit = puzzle.board.correctDigit(at: filled)
        if let index = puzzle.hand.firstIndex(of: digit) { puzzle.hand.remove(at: index) }
        else { XCTAssertTrue(puzzle.pool.take(digit)) }
        puzzle.board.fill(filled, with: digit, by: .player)
        run.puzzle = puzzle
        let positions = Set([Square(0), Square(8), Square(72), Square(80), given, filled]).sorted()
        run.markers = [OwnedMarker(defID: markerID, boughtAtLevel: 1, pricePaid: 0, squares: positions)]
        return Game(run: run)
    }

    private func assertPlacement(_ frame: CGRect, cell: CGRect, viewport: CGRect,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(frame.isEmpty, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, viewport.minX + 7, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY + 7, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, viewport.maxX - 7, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY - 7, file: file, line: line)
        XCTAssertFalse(frame.intersects(cell), "The popup must leave the inspected square and finger clear", file: file, line: line)
    }

    private func settle(_ window: UIWindow) async throws {
        try await Task.sleep(for: .milliseconds(180))
        window.layoutIfNeeded()
    }

    private func popupScroll(in window: UIWindow, frame: CGRect) throws -> UIScrollView {
        func descendants(_ view: UIView) -> [UIScrollView] {
            if let scroll = view as? UIScrollView { return [scroll] }
            return view.subviews.flatMap(descendants)
        }
        return try XCTUnwrap(descendants(window).first { view in
            let rect = view.convert(view.bounds, to: window)
            return frame.insetBy(dx: -2, dy: -2).contains(rect)
                && abs(rect.width - frame.width) < 3 && rect.height > 60
        })
    }

    private func screenshot(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func normalized(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func recognizedText(_ image: UIImage, in frame: CGRect) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        let rect = CGRect(x: frame.minX * image.scale, y: frame.minY * image.scale,
                          width: frame.width * image.scale, height: frame.height * image.scale)
        let crop = try XCTUnwrap(image.cgImage?.cropping(to: rect))
        try VNImageRequestHandler(cgImage: crop).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
