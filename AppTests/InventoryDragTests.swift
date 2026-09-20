import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class InventoryDragTests: XCTestCase {
    func testCurvedMotionPreservesBothCoordinatesAndFingerOffsetBeyondTheInventoryRow() throws {
        let (presenter, owner, _) = fixture()
        for point in [CGPoint(x: 160, y: 210), CGPoint(x: 325, y: 390),
                      CGPoint(x: 220, y: 560), CGPoint(x: 55, y: 610)] {
            presenter.move(owner: owner, to: point)
            let session = try XCTUnwrap(presenter.session)
            XCTAssertEqual(session.center.x, point.x + 2)
            XCTAssertEqual(session.center.y, point.y + 3)
            XCTAssertEqual(session.finger, point)
        }
        XCTAssertEqual(presenter.finish(owner: owner, at: CGPoint(x: 55, y: 610)), .cancel)
        XCTAssertNil(presenter.session)
        let returning = try XCTUnwrap(presenter.returning)
        XCTAssertEqual(returning.start, CGPoint(x: 57, y: 613))
        XCTAssertEqual(returning.itemFrame, CGRect(x: 10, y: 100, width: 44, height: 44))
        presenter.finishReturn(id: UUID())
        XCTAssertNotNil(presenter.returning, "A stale animation cannot finish a newer return")
        presenter.finishReturn(id: returning.id)
        XCTAssertNil(presenter.returning)
    }

    func testVisibleActionRowIsTheSaleTargetAndOutsideReleaseRestoresTheControls() async throws {
        var run = RunState(seed: "drag-action-row")
        let buff = OwnedBuff(defID: Buffs.peek, pricePaid: 4)
        run.buffs = [buff]
        var game = Game(run: run)
        try game.startPuzzle()
        let model = GameModel(resuming: game, savesProgress: false)
        let presenter = InventoryDragPresenter()
        let surface = GameplayShell(model: model, controls: [], onTapBuff: { _ in }) {
            PuzzlePageView(model: model, puzzle: model.puzzle!, isClockRunning: false)
        }
        .inventoryDragHost(presenter: presenter)
        .environment(\.scenePhase, .active)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.levelPalette, .forDisplay(slot: .easy))
        .frame(width: 402, height: 778)
        .background { GameplaySurfaceBackground() }
        let host = UIHostingController(rootView: surface)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 402, height: 778)
        window.rootViewController = host
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(900))
        window.layoutIfNeeded()
        let actions = try XCTUnwrap(presenter.actionFrame)
        let before = try model.game.encoded()
        let initial = try printedText(window, name: "inventory-actions-before-drag")
        XCTAssertTrue(initial.contains("toss"), initial)
        XCTAssertTrue(initial.contains("endturn"), initial)
        let owner = UUID()
        presenter.begin(owner: owner, sale: InventorySale(buff: buff, index: 0),
                        itemFrame: CGRect(x: 340, y: 50, width: 44, height: 44),
                        bookmarkFrames: [], start: CGPoint(x: 362, y: 72), point: CGPoint(x: 200, y: 300))
        try await Task.sleep(for: .milliseconds(100))
        window.layoutIfNeeded()
        XCTAssertEqual(presenter.session?.trashFrame, actions)
        let dragging = try printedText(window, name: "inventory-actions-replaced-by-sell")
        XCTAssertTrue(dragging.contains("dragheretosell"), dragging)
        XCTAssertFalse(dragging.contains("toss"), dragging)
        XCTAssertFalse(dragging.contains("endturn"), dragging)
        XCTAssertEqual(presenter.finish(owner: owner, at: CGPoint(x: 200, y: 300)), .cancel)
        try await Task.sleep(for: .milliseconds(400))
        window.layoutIfNeeded()
        let restored = try printedText(window, name: "inventory-actions-after-cancel")
        XCTAssertTrue(restored.contains("toss"), restored)
        XCTAssertTrue(restored.contains("endturn"), restored)
        XCTAssertFalse(restored.contains("dragheretosell"), restored)
        XCTAssertNil(presenter.returning)
        XCTAssertEqual(try model.game.encoded(), before, "The entire drag/cancel presentation preserves the game")
    }

    private func printedText(_ window: UIWindow, name: String) throws -> String {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage), options: [:]).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().lowercased().filter { $0.isLetter || $0.isNumber }
    }

    func testOnlyReleaseInsideTheVisibleTrashCommitsAndItCanCommitOnlyOnce() throws {
        let (presenter, owner, sale) = fixture()
        let target = try XCTUnwrap(presenter.session?.trashFrame)
        presenter.move(owner: owner, to: CGPoint(x: target.midX, y: target.midY))
        XCTAssertTrue(try XCTUnwrap(presenter.session).overTrash)
        XCTAssertEqual(presenter.finish(owner: owner, at: CGPoint(x: target.maxX + 1, y: target.midY)), .cancel,
                       "Entering the trash earlier is not a committed sale.")
        let (retry, nextOwner, _) = fixture(sale: sale)
        let point = CGPoint(x: target.midX, y: target.midY)
        XCTAssertEqual(retry.finish(owner: nextOwner, at: point), .sell(sale))
        XCTAssertEqual(retry.finish(owner: nextOwner, at: point), .cancel)
    }

    func testCancelNavigationBackgroundAndResizingInvalidateDelayedEnds() throws {
        let (presenter, owner, _) = fixture()
        let target = try XCTUnwrap(presenter.session?.trashFrame)
        let point = CGPoint(x: target.midX, y: target.midY)
        presenter.cancel(owner: owner)
        XCTAssertEqual(presenter.finish(owner: owner, at: point), .cancel)
        let (resized, resizeOwner, _) = fixture()
        resized.rootFrame = CGRect(x: 0, y: 0, width: 844, height: 390)
        XCTAssertNil(resized.session)
        XCTAssertEqual(resized.finish(owner: resizeOwner, at: point), .cancel)
    }

    func testOnlyOwningRowCanMoveOrCommitItsGesture() throws {
        let (presenter, owner, _) = fixture()
        let before = try XCTUnwrap(presenter.session)
        let stranger = UUID()
        presenter.move(owner: stranger, to: .zero)
        presenter.cancel(owner: stranger)
        XCTAssertEqual(presenter.session, before)
        XCTAssertEqual(presenter.finish(owner: stranger, at: .zero), .cancel)
        XCTAssertEqual(presenter.session?.owner, owner)
    }

    func testDepartingRouteCannotEraseTheNewRoutesSaleTarget() throws {
        let presenter = InventoryDragPresenter()
        presenter.rootFrame = CGRect(x: 0, y: 0, width: 402, height: 874)
        let old = UUID(), next = UUID(), drag = UUID()
        presenter.registerActions(owner: old, frame: CGRect(x: 8, y: 750, width: 386, height: 50))
        let destination = CGRect(x: 12, y: 730, width: 378, height: 56)
        presenter.registerActions(owner: next, frame: destination)
        presenter.removeActions(owner: old)
        XCTAssertEqual(presenter.actionFrame, destination)
        presenter.begin(owner: drag, sale: InventorySale(buff: OwnedBuff(defID: Buffs.peek, pricePaid: 4), index: 0),
                        itemFrame: CGRect(x: 340, y: 100, width: 44, height: 44), bookmarkFrames: [],
                        start: CGPoint(x: 362, y: 122), point: CGPoint(x: 220, y: 350))
        XCTAssertEqual(presenter.session?.trashFrame, destination)
        presenter.removeActions(owner: next)
        XCTAssertNil(presenter.session)
        XCTAssertEqual(presenter.finish(owner: drag, at: CGPoint(x: destination.midX, y: destination.midY)), .cancel)
    }

    func testBookmarkReorderTargetsVisibleOccupiedSlotsAndTracksIdentityAfterward() throws {
        let first = OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5)
        let second = OwnedBookmark(defID: Bookmarks.weatherForecast, boughtAtLevel: 1, pricePaid: 4)
        var run = RunState(seed: "reorder-sale-exact-copy")
        run.bookmarks = [first, second]
        let sale = InventorySale(bookmark: first, index: 0, run: run)
        let (presenter, owner, _) = fixture(sale: sale)
        let destination = try XCTUnwrap(presenter.session?.bookmarkFrames.last)
        XCTAssertEqual(presenter.finish(owner: owner, at: CGPoint(x: destination.midX, y: destination.midY)),
                       .reorder(first.id, 1))
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        model.reorderBookmark(id: first.id, to: 1)
        XCTAssertEqual(model.run.bookmarks.map(\.id), [second.id, first.id])
        XCTAssertEqual(sale.resolvedIndex(in: model.run), 1)
        let coins = model.coins
        model.sell(kind: .bookmark, index: try XCTUnwrap(sale.resolvedIndex(in: model.run)))
        XCTAssertEqual(model.run.bookmarks.map(\.id), [second.id])
        XCTAssertEqual(model.coins, coins + sale.refund)
        XCTAssertNil(sale.resolvedIndex(in: model.run))
    }

    func testSameDefinitionSamePriceReplacementsNeverMatchOldBookmarkSale() {
        let old = OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5)
        var run = RunState(seed: "replacement-purchase")
        run.bookmarks = [old]
        let sale = InventorySale(bookmark: old, index: 0, run: run)
        run.bookmarks = [OwnedBookmark(defID: old.defID, boughtAtLevel: old.boughtAtLevel,
                                        pricePaid: old.pricePaid)]
        XCTAssertNil(sale.resolvedIndex(in: run))
    }

    func testBuybackQuoteMatchesTheExactSaleAndExpiresAfterOneRefund() throws {
        var run = RunState(seed: "buyback-visible-refund")
        let first = OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 7)
        let second = OwnedBookmark(defID: Bookmarks.weatherForecast, boughtAtLevel: 1, pricePaid: 5)
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.buybackColumn, boughtAtLevel: 1, pricePaid: 6), first, second]
        Shop.open(&run)
        let quote = InventorySale(bookmark: first, index: 1, run: run)
        XCTAssertEqual(quote.refund, 7)
        XCTAssertEqual(quote.actionTitle, "Sell for 7 coins")
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        let before = model.coins
        model.sell(kind: .bookmark, index: try XCTUnwrap(quote.resolvedIndex(in: model.run)))
        XCTAssertEqual(model.coins - before, quote.refund)
        let next = InventorySale(bookmark: second, index: 1, run: model.run)
        XCTAssertEqual(next.refund, Shop.sellPrice(second.pricePaid))
        XCTAssertEqual(InventorySale(buff: OwnedBuff(defID: Buffs.peek, pricePaid: 5), index: 0).refund, Shop.sellPrice(5))
    }

    func testStripGeometryMatchesAllSevenVisibleCardsWithoutUsingTheGapAsATarget() {
        let strip = InventoryStripGeometry(frame: CGRect(x: 20, y: 104, width: 396, height: 44), bookmarkCount: 5)
        XCTAssertEqual(strip.itemFrame(kind: .bookmark, index: 0), CGRect(x: 20, y: 104, width: 50, height: 44))
        XCTAssertEqual(strip.itemFrame(kind: .buff, index: 1).maxX, 416)
        XCTAssertEqual(strip.bookmarkFrames.count, 5)
        XCTAssertFalse(strip.bookmarkFrames.contains { $0.contains(CGPoint(x: 71, y: 120)) })
    }

    func testCollateralDimsOnlyCommittedOwnedBookmarkAndAnnouncesPuzzleDuration() throws {
        var run = RunState(seed: "collateral-visible-suspension")
        let chosen = OwnedBookmark(defID: Bookmarks.typeCase, boughtAtLevel: 1, pricePaid: 6)
        let other = OwnedBookmark(defID: Bookmarks.localGossip, boughtAtLevel: 1, pricePaid: 5)
        let collateral = OwnedBuff(defID: Buffs.collateral, pricePaid: 5)
        run.bookmarks = [chosen, other]
        run.buffs = [collateral]
        var game = Game(run: run)
        try game.startPuzzle()
        // Declining Type Case's optional opening digit does not take a Turn
        // action, so Collateral is still a legal first action.
        for choice in game.run.pendingItemDecisions {
            XCTAssertTrue(choice.allowsCancel)
            XCTAssertTrue(try game.resolveItemDecision(id: choice.id, selected: nil))
        }
        let model = GameModel(resuming: game, savesProgress: false)
        let before = try inventoryStatusImage(model, name: "collateral-before")
        XCTAssertTrue(model.useBuff(at: 0))
        let cancelled = try XCTUnwrap(model.pendingItemDecision)
        XCTAssertTrue(model.resolveItemDecision(id: cancelled.id, selected: nil))
        XCTAssertFalse(BookmarkMechanics.isSuspended(id: chosen.id, puzzle: model.puzzle))
        XCTAssertEqual(model.run.buffs.map(\.id), [collateral.id])
        let cancelledImage = try inventoryStatusImage(model, name: "collateral-cancelled")
        XCTAssertEqual(try bookmarkPixels(before, slot: 0), try bookmarkPixels(cancelledImage, slot: 0))

        XCTAssertTrue(model.useBuff(at: 0))
        let choice = try XCTUnwrap(model.pendingItemDecision)
        XCTAssertTrue(model.resolveItemDecision(id: choice.id, selected: [chosen.id.uuidString]))
        XCTAssertTrue(BookmarkMechanics.isSuspended(id: chosen.id, puzzle: model.puzzle))
        XCTAssertFalse(BookmarkMechanics.isSuspended(id: other.id, puzzle: model.puzzle))
        XCTAssertTrue(model.run.buffs.isEmpty)
        let suspended = try inventoryStatusImage(model, name: "collateral-suspended")
        XCTAssertNotEqual(try bookmarkPixels(before, slot: 0), try bookmarkPixels(suspended, slot: 0),
                          "The actual row must visibly dim and cross out the suspended copy")
        XCTAssertEqual(try bookmarkPixels(before, slot: 1), try bookmarkPixels(suspended, slot: 1),
                       "The other owned Bookmark must remain visually active")

        let status = inventoryStatus(chosen, slot: 0, model: model)
        XCTAssertTrue(status.contains("Suspended for this Puzzle."))
        XCTAssertFalse(status.contains("Asleep this Turn"))
        XCTAssertFalse(inventoryStatus(other, slot: 1, model: model).contains("Suspended"))
        let sleeping = InventoryBookmark(def: other.def, colour: Paper.pageWarm, ink: Paper.ink,
            flagged: false, slot: 1, pulling: false, asleep: true, fired: false,
            explaining: .constant(false)).accessibilityStatus
        XCTAssertTrue(sleeping.contains("Asleep this Turn."), "Boss duration remains one Turn")
        XCTAssertFalse(sleeping.contains("Suspended"))
    }

    private func inventoryStatus(_ bookmark: OwnedBookmark, slot: Int, model: GameModel) -> String {
        InventoryBookmark(def: bookmark.def, colour: Paper.pageWarm, ink: Paper.ink,
            flagged: false, slot: slot, pulling: false, asleep: model.sleepingBookmark == slot,
            suspended: BookmarkMechanics.isSuspended(id: bookmark.id, puzzle: model.puzzle),
            fired: false, explaining: .constant(false)).accessibilityStatus
    }

    private func inventoryStatusImage(_ model: GameModel, name: String) throws -> UIImage {
        let row = BookmarkRow(model: model, isGameplay: true, onTapBuff: { _ in })
            .padding(12).frame(width: 402, height: 68).background(GameplaySurface.ivory)
            .environment(\.dynamicTypeSize, .large).environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light).transaction { $0.disablesAnimations = true }
        let renderer = ImageRenderer(content: row)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = name; attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func bookmarkPixels(_ image: UIImage, slot: Int) throws -> Data {
        let strip = InventoryStripGeometry(frame: CGRect(x: 12, y: 12, width: 378, height: 44), bookmarkCount: 2)
        let frame = strip.itemFrame(kind: .bookmark, index: slot).insetBy(dx: 2, dy: 2)
        let pixels = CGRect(x: frame.minX * 2, y: frame.minY * 2, width: frame.width * 2, height: frame.height * 2).integral
        let crop = try XCTUnwrap(try XCTUnwrap(image.cgImage).cropping(to: pixels))
        return try XCTUnwrap(UIImage(cgImage: crop).pngData())
    }

    private func fixture(sale: InventorySale? = nil) -> (InventoryDragPresenter, UUID, InventorySale) {
        let sale = sale ?? InventorySale(buff: OwnedBuff(defID: Buffs.redraw, pricePaid: 7), index: 0)
        let presenter = InventoryDragPresenter()
        presenter.rootFrame = CGRect(x: 0, y: 0, width: 390, height: 844)
        let owner = UUID()
        presenter.begin(owner: owner, sale: sale,
            itemFrame: CGRect(x: 10, y: 100, width: 44, height: 44),
            bookmarkFrames: [CGRect(x: 10, y: 100, width: 44, height: 44), CGRect(x: 59, y: 100, width: 44, height: 44)],
            start: CGPoint(x: 30, y: 119), point: CGPoint(x: 30, y: 119))
        return (presenter, owner, sale)
    }
}
