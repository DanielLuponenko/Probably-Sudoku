import SwiftUI
import UIKit
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Mounts the production host: changing page chrome must not replace its
/// capture anchor, drop controls from the texture, or cancel the live turn.
@MainActor
final class PageCaptureTests: XCTestCase {
    func testFullscreenCaptureAndLiveContentUseEveryPointOfTheHost() async throws {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 430, height: 932),
                     CGSize(width: 768, height: 1024)] {
            let fixture = CaptureFixture(size: size)
            let host = try mount(fixture)
            defer { host.close() }
            await settle(host.window)
            let anchor = try XCTUnwrap(fixture.flipper.captureAnchor)
            let content = try XCTUnwrap(fixture.contentAnchor)
            let fullFrame = CGRect(origin: .zero, size: size)
            XCTAssertEqual(anchor.bounds, fullFrame)
            XCTAssertEqual(content.convert(content.bounds, to: anchor), fullFrame,
                           "Gameplay has no Book margins or content inset")
            let snapshot = try XCTUnwrap(fixture.flipper.capturePage())
            XCTAssertEqual(snapshot.size, size)
            XCTAssertEqual(snapshot.image.width, Int(size.width * snapshot.scale))
            XCTAssertEqual(snapshot.image.height, Int(size.height * snapshot.scale))
            let pixels = try raster(snapshot.image)
            assertColor(pixels, at: CGPoint(x: 5, y: 5), scale: snapshot.scale, channel: 0)
            assertColor(pixels, at: CGPoint(x: 5, y: 50), scale: snapshot.scale, channel: 1)
            assertColor(pixels, at: CGPoint(x: size.width - 5, y: size.height - 5),
                        scale: snapshot.scale, channel: 2)
        }
    }

    func testChangingChromeAfterFirstFrameKeepsHostCaptureAndTurnAlive() async throws {
        let fixture = CaptureFixture(size: CGSize(width: 390, height: 844))
        let host = try mount(fixture)
        defer { host.close() }
        await settle(host.window)
        let originalAnchor = try XCTUnwrap(fixture.flipper.captureAnchor)
        let originalContent = try XCTUnwrap(fixture.contentAnchor)

        for destinationChrome in [true, false] {
            let turn = await start(fixture) { fixture.showsChrome = destinationChrome }
            XCTAssertNotEqual(fixture.showsChrome, destinationChrome)
            let callbacks = try XCTUnwrap(fixture.driver.starts.last)
            callbacks.firstFrame()
            await settle(host.window)
            XCTAssertEqual(fixture.showsChrome, destinationChrome)
            XCTAssertTrue(fixture.flipper.captureAnchor === originalAnchor)
            XCTAssertTrue(fixture.contentAnchor === originalContent)
            XCTAssertEqual(originalAnchor.bounds.size, fixture.size)
            XCTAssertEqual(fixture.flipper.capturedPageSize, fixture.size)
            XCTAssertEqual(fixture.driver.preparedSize, fixture.size)
            XCTAssertTrue(fixture.flipper.isFlipping)
            XCTAssertEqual(fixture.driver.cancelCount, 0)
            let contentRect = originalContent.convert(originalContent.bounds, to: originalAnchor)
            if destinationChrome {
                XCTAssertEqual(contentRect.minX, Volume.spine + Volume.pageContentInsets.leading)
                XCTAssertEqual(contentRect.minY, Volume.head + Volume.pageContentInsets.top)
            } else {
                XCTAssertEqual(contentRect, originalAnchor.bounds)
            }
            callbacks.completion()
            await fulfillment(of: [turn.finished], timeout: 2)
            XCTAssertFalse(fixture.flipper.isFlipping)
            XCTAssertNil(fixture.flipper.capturedPageSize)
        }
    }

    func testSnapshotCapturesCurrentLiveStateBeforeDestinationChanges() async throws {
        let fixture = CaptureFixture(size: CGSize(width: 390, height: 844))
        let host = try mount(fixture)
        defer { host.close() }
        await settle(host.window)
        fixture.headerChanged = true
        await settle(host.window)
        let outgoing = try XCTUnwrap(fixture.flipper.capturePage())
        let turn = await start(fixture) {
            fixture.headerChanged = false
            fixture.showsChrome = true
        }
        let callbacks = try XCTUnwrap(fixture.driver.starts.last)
        XCTAssertTrue(fixture.headerChanged)
        let printed = try raster(XCTUnwrap(fixture.driver.preparedImage))
        let outgoingPixels = try raster(outgoing.image)
        XCTAssertEqual(printed.bytes, outgoingPixels.bytes)
        callbacks.firstFrame()
        await settle(host.window)
        XCTAssertFalse(fixture.headerChanged)
        XCTAssertEqual(try raster(XCTUnwrap(fixture.driver.preparedImage)).bytes, printed.bytes,
                       "Destination changes cannot replace the outgoing printed texture")
        callbacks.completion()
        await fulfillment(of: [turn.finished], timeout: 2)
    }

    func testResizingHostCancelsTurnAndKeepsAlreadyCommittedDestination() async throws {
        let fixture = CaptureFixture(size: CGSize(width: 390, height: 844))
        let host = try mount(fixture)
        defer { host.close() }
        await settle(host.window)
        let turn = await start(fixture) { fixture.showsChrome = true }
        let callbacks = try XCTUnwrap(fixture.driver.starts.last)
        callbacks.firstFrame()
        await settle(host.window)
        fixture.size = CGSize(width: 360, height: 780)
        await settle(host.window)
        await fulfillment(of: [turn.finished], timeout: 2)
        XCTAssertEqual(fixture.driver.cancelCount, 1)
        XCTAssertTrue(fixture.showsChrome)
        XCTAssertFalse(fixture.flipper.isFlipping)
        XCTAssertNil(fixture.flipper.capturedPageSize)
        callbacks.firstFrame()
        callbacks.completion()
        XCTAssertFalse(fixture.flipper.isFlipping)
    }

    private struct RunningTurn {
        let task: Task<Void, Never>
        let finished: XCTestExpectation
    }

    private func start(_ fixture: CaptureFixture, change: @escaping () -> Void) async -> RunningTurn {
        let started = expectation(description: "Real hierarchy captured and renderer started")
        let finished = expectation(description: "Capture turn released")
        fixture.driver.didStart = { started.fulfill() }
        let model = GameModel(frozen: Game(seed: "fullscreen-capture"), page: .puzzle)
        let task = Task { @MainActor in
            await fixture.flipper.flip(from: model, reduceMotion: false, change)
            finished.fulfill()
        }
        await fulfillment(of: [started], timeout: 2)
        fixture.driver.didStart = nil
        return RunningTurn(task: task, finished: finished)
    }

    @MainActor private final class MountedHost {
        let window: UIWindow
        let previousKey: UIWindow?
        let flipper: PageFlipper

        init(window: UIWindow, previousKey: UIWindow?, flipper: PageFlipper) {
            self.window = window
            self.previousKey = previousKey
            self.flipper = flipper
        }

        func close() {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
    }

    private func mount(_ fixture: CaptureFixture) throws -> MountedHost {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: fixture.size)
        let controller = UIHostingController(rootView: CaptureFixtureView(fixture: fixture))
        controller.safeAreaRegions = []
        window.rootViewController = controller
        window.makeKeyAndVisible()
        return MountedHost(window: window, previousKey: previousKey, flipper: fixture.flipper)
    }

    private func settle(_ window: UIWindow) async {
        let laidOut = expectation(description: "Host layout settled")
        DispatchQueue.main.async {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            _ = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            laidOut.fulfill()
        }
        await fulfillment(of: [laidOut], timeout: 3)
    }

    private struct Raster {
        let bytes: [UInt8]
        let width: Int
    }

    private func raster(_ image: CGImage) throws -> Raster {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let bitmap = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
            bitmap.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return Raster(bytes: bytes, width: image.width)
    }

    private func assertColor(_ raster: Raster, at point: CGPoint, scale: CGFloat, channel: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        let offset = (Int(point.y * scale) * raster.width + Int(point.x * scale)) * 4
        XCTAssertGreaterThan(raster.bytes[offset + channel], 200, file: file, line: line)
        for other in 0..<3 where other != channel {
            XCTAssertLessThan(raster.bytes[offset + other], 80, file: file, line: line)
        }
    }
}

@MainActor @Observable
private final class CaptureFixture {
    var showsChrome = false
    var headerChanged = false
    var size: CGSize
    let driver: ManualPageTurnRenderer
    let flipper: PageFlipper
    @ObservationIgnored weak var contentAnchor: UIView?

    init(size: CGSize) {
        self.size = size
        let driver = ManualPageTurnRenderer()
        self.driver = driver
        self.flipper = PageFlipper(driver: driver)
    }
}

private struct CaptureFixtureView: View {
    let fixture: CaptureFixture

    var body: some View {
        BookView(flipper: fixture.flipper, showsChrome: fixture.showsChrome) {
            VStack(spacing: 0) {
                (fixture.headerChanged ? Color.yellow : Color(.sRGB, red: 1, green: 0, blue: 0))
                    .frame(height: 40)
                Color(.sRGB, red: 0, green: 1, blue: 0).frame(height: 50)
                Color(.sRGB, red: 0, green: 0, blue: 1)
            }
            .background { CaptureContentProbe(fixture: fixture) }
        }
        .frame(width: fixture.size.width, height: fixture.size.height)
        .environment(\.scenePhase, .active)
        .environment(\.cosmeticTheme, .standard)
        .transaction { $0.disablesAnimations = true }
    }
}

private struct CaptureContentProbe: UIViewRepresentable {
    let fixture: CaptureFixture
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        fixture.contentAnchor = view
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        fixture.contentAnchor = uiView
    }
}
