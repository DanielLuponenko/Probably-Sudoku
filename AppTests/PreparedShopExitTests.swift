#if DEBUG && targetEnvironment(simulator)
import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Mount the production Shop and invoke its actual Continue action. A manual
/// renderer separates first-frame commitment from later animation completion.
@MainActor
final class PreparedShopExitTests: XCTestCase {
    func testCommittedShopDisappearanceLetsItsPageTurnFinishExactlyOnce() async throws {
        let probe = Probe()
        let model = try model(probe)
        let driver = ManualPageTurnRenderer()
        let flipper = PageFlipper(driver: driver, snapshotProvider: Self.snapshot)
        let mounted = try await mount(model, probe: probe, flipper: flipper)
        defer { mounted.close() }
        let started = expectation(description: "The Shop Continue starts its real page turn")
        driver.didStart = { started.fulfill() }
        let disappeared = expectation(description: "Committed Shop has left the hosted hierarchy")
        probe.disappeared = { disappeared.fulfill() }
        try XCTUnwrap(probe.continueAction)()
        await fulfillment(of: [started], timeout: 5)
        XCTAssertTrue(probe.saves.isEmpty)
        let callbacks = try XCTUnwrap(driver.starts.first)

        callbacks.firstFrame()
        await fulfillment(of: [disappeared], timeout: 5)
        await flushMainActor()
        XCTAssertEqual(model.page, .briefing)
        XCTAssertTrue(flipper.isFlipping, "The outgoing Shop cannot cancel the curl it just committed")
        XCTAssertEqual(driver.cancelCount, 0)
        XCTAssertEqual(probe.saves.count, 1)
        let committed = try model.game.encoded()
        callbacks.firstFrame()
        callbacks.completion()
        await flushMainActor()
        XCTAssertFalse(flipper.isFlipping)
        XCTAssertEqual(driver.cancelCount, 0)
        XCTAssertEqual(probe.saves, [committed])
        XCTAssertEqual(try model.game.encoded(), committed)
    }

    func testCoveringShopBeforeFirstFrameCancelsWithoutAdvancingOrSaving() async throws {
        try await checkPrecommitCancellation(background: false)
    }

    func testBackgroundingShopBeforeFirstFrameCancelsWithoutAdvancingOrSaving() async throws {
        try await checkPrecommitCancellation(background: true)
    }

    private func checkPrecommitCancellation(background: Bool) async throws {
        let probe = Probe()
        let model = try model(probe)
        let original = try model.game.encoded()
        let driver = ManualPageTurnRenderer()
        let flipper = PageFlipper(driver: driver, snapshotProvider: Self.snapshot)
        let mounted = try await mount(model, probe: probe, flipper: flipper)
        defer { mounted.close() }
        let started = expectation(description: "The Shop is awaiting its first printed frame")
        driver.didStart = { started.fulfill() }
        try XCTUnwrap(probe.continueAction)()
        await fulfillment(of: [started], timeout: 5)
        let callbacks = try XCTUnwrap(driver.starts.first)

        if background { probe.scenePhase = .inactive } else { probe.covered = true }
        mounted.window.layoutIfNeeded()
        for _ in 0..<30 where flipper.isFlipping {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertFalse(flipper.isFlipping)
        XCTAssertEqual(driver.cancelCount, 1)
        callbacks.firstFrame()
        callbacks.completion()
        await flushMainActor()
        XCTAssertEqual(model.page, .shop)
        XCTAssertEqual(try model.game.encoded(), original)
        XCTAssertTrue(probe.saves.isEmpty)
    }

    private func model(_ probe: Probe) throws -> GameModel {
        var game = Game(seed: "hosted-shop-exit")
        try game.startPuzzle()
        game.qaMeetTarget()
        _ = try game.cashOut()
        game.openShop()
        XCTAssertNotNil(game.shop)
        let persistence = GameModel.Persistence(save: { game, _ in
            probe.saves.append(try! game.encoded())
            return true
        }, recordCompletion: { _, _ in true }, clear: { true }, recordsPlayerProfile: false)
        let model = GameModel(resuming: game, savesProgress: true, persistence: persistence)
        probe.saves.removeAll()
        return model
    }

    private func mount(_ model: GameModel, probe: Probe, flipper: PageFlipper) async throws -> Mounted {
        let ready = expectation(description: "Production Shop action is mounted")
        probe.ready = { ready.fulfill() }
        let controller = UIHostingController(rootView: ShopHost(model: model, probe: probe, flipper: flipper))
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 748)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        return Mounted(window: window, previousKey: previousKey, probe: probe)
    }

    private func flushMainActor() async {
        for _ in 0..<3 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }

    private static func snapshot() -> PageTurnSnapshot {
        let size = CGSize(width: 8, height: 12)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return PageTurnSnapshot(image: image.cgImage!, size: size, scale: 1)
    }

    @MainActor @Observable
    final class Probe {
        var covered = false
        var scenePhase = ScenePhase.active
        @ObservationIgnored var continueAction: (@MainActor () -> Void)?
        @ObservationIgnored var ready: (() -> Void)?
        @ObservationIgnored var disappeared: (() -> Void)?
        @ObservationIgnored var saves: [Data] = []
    }

    private struct ShopHost: View {
        @Bindable var model: GameModel
        @Bindable var probe: Probe
        let flipper: PageFlipper
        var body: some View {
            Group {
                if model.page == .shop, let shop = model.shop {
                    ShopPageView(model: model, shop: shop, onClaimMarker: { _ in },
                        isPresentationCovered: probe.covered,
                        canStartPresentation: { !probe.covered && probe.scenePhase == .active },
                        onContinueReady: { action in
                            probe.continueAction = action
                            let ready = probe.ready
                            probe.ready = nil
                            ready?()
                        })
                        .onDisappear { probe.disappeared?() }
                } else {
                    Text("Next puzzle")
                }
            }
            .environment(flipper)
            .environment(\.scenePhase, probe.scenePhase)
            .environment(\.gameReduceMotion, false)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
            .environment(\.dynamicTypeSize, .large)
        }
    }

    @MainActor private struct Mounted {
        let window: UIWindow
        let previousKey: UIWindow?
        let probe: Probe
        func close() {
            probe.continueAction = nil
            probe.disappeared = nil
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
    }
}
#endif
