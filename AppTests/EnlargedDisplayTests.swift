import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

/// These are logical viewport equivalents, not a claim that Simulator changed
/// its Display Zoom setting. Every view uses the live shell and real safe insets.
@MainActor
final class EnlargedDisplayTests: XCTestCase {
    private let largerText: [DynamicTypeSize] = [
        .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5
    ]

    func test320By568ZoomEquivalentAcrossEveryLargerTextSize() async throws {
        try await auditCorePages(on: .smallest)
    }

    func test375By667AcrossEveryLargerTextSize() async throws {
        try await auditCorePages(on: .se)
    }

    func test393By852ZoomEquivalentAcrossEveryLargerTextSize() async throws {
        try await auditCorePages(on: .zoomedPro)
    }

    func test402By874AcrossEveryLargerTextSize() async throws {
        try await auditCorePages(on: .pro)
    }

    func testBriefingRewardAndPrimaryActionActuallyEnlargeForAccessibilityText() async throws {
        let model = try await fixture(.briefing)
        let reward = try XCTUnwrap(model.currentSkipClaim?.offer.buff)
        let phrases = [reward.name, CatalogueDetails.item(reward.id)?.shortEffect ?? reward.text, "Play puzzle"]
        var heights = Dictionary(uniqueKeysWithValues: phrases.map { ($0, [CGFloat]()) })
        for type in [DynamicTypeSize.large, .accessibility5] {
            try await withHostedPage(model, page: .briefing, phone: .zoomedPro, type: type) { host in
                let image = screenshot(host.window)
                attach(image, name: "briefing-readable-growth-\(type)")
                let rows = try recognize(image)
                for phrase in phrases {
                    let row = try XCTUnwrap(printedPhrase(phrase, in: rows))
                    heights[phrase, default: []].append(row.bounds.height * image.size.height)
                }
            }
        }
        for (phrase, sizes) in heights {
            XCTAssertEqual(sizes.count, 2)
            guard sizes.count == 2 else { continue }
            XCTAssertGreaterThan(sizes[1], sizes[0] * 1.2,
                                 "'\(phrase)' must become meaningfully larger; fixed small text is not accessibility support")
        }
        model.cancelPuzzlePreparation()
    }

    func testEveryBuffEffectAndLongestBossDecisionsFitAtMaximumTextSize() async throws {
        var seeds: [String: String] = [:]
        for index in 0..<1_000 where seeds.count < Buffs.all.count {
            let seed = "enlarged-every-reward-\(index)"
            if let reward = RunState(seed: seed).currentSkipOffer?.buff {
                seeds[reward.id] = seed
            }
        }
        XCTAssertEqual(seeds.count, Buffs.all.count)
        for phone in [Phone.smallest, .zoomedPro] {
            for buff in Buffs.all {
                do {
                let model = try await fixture(.briefing, seed: XCTUnwrap(seeds[buff.id]))
                defer { model.cancelPuzzlePreparation() }
                try await withHostedPage(model, page: .briefing, phone: phone, type: .accessibility5) { host in
                    let image = screenshot(host.window)
                    attach(image, name: "\(phone.name)-full-reward-\(buff.id)-AX5")
                    let rows = try recognize(image)
                    let text = normalize(rows.map(\.text).joined(separator: " "))
                    XCTAssertTrue(text.contains(normalize(buff.name)), text)
                    let summary = CatalogueDetails.item(buff.id)?.shortEffect ?? buff.text
                    // The exported AX5 images show the complete printed zero,
                    // which Vision reads as the letter O in this exact phrase.
                    // Keep every other word and every other Buff comparison exact.
                    let peekZeroGlyphMatch = buff.id == Buffs.peek
                        && text.contains(normalize(summary).replacingOccurrences(of: "scores0unless", with: "scoresounless"))
                    XCTAssertTrue(text.contains(normalize(summary)) || printedPhrase(summary, in: rows) != nil || peekZeroGlyphMatch,
                                  "The canonical effect summary must be visible before accepting: \(buff.name): \(text)")
                    for action in Page.briefing.actions {
                        let printed = try XCTUnwrap(printedPhrase(action, in: rows),
                                                  "\(phone.name) \(buff.name): missing complete '\(action)' in \(text)")
                        assertReadableAction(printed, image: image, phone: phone, context: buff.name)
                    }
                    assertSeparate("Skip + Buff", "Play puzzle", rows: rows, context: buff.name)
                }
                } catch {
                    XCTFail("\(phone.name) \(buff.name): \(error)")
                }
            }
            for boss in [BossModifier.unluckyLucky, .overPusher, .grayTheGarry] {
                do {
                let model = try await fixture(.briefing, slot: .boss, boss: boss)
                defer { model.cancelPuzzlePreparation() }
                try await withHostedPage(model, page: .briefing, phone: phone, type: .accessibility5) { host in
                    let image = screenshot(host.window)
                    attach(image, name: "\(phone.name)-boss-\(boss.rawValue)-AX5")
                    let rows = try recognize(image)
                    let text = normalize(rows.map(\.text).joined(separator: " "))
                    XCTAssertTrue(text.contains(normalize(boss.name)), text)
                    XCTAssertTrue(text.contains(normalize(boss.text)), text)
                    XCTAssertTrue(text.contains(normalize("Boss Puzzles must be played")), text)
                    XCTAssertNil(printedPhrase("Skip + Buff", in: rows))
                    let play = try XCTUnwrap(printedPhrase("Play puzzle", in: rows), "\(phone.name) \(boss.name): \(text)")
                    assertReadableAction(play, image: image, phone: phone, context: boss.name)
                }
                } catch {
                    XCTFail("\(phone.name) \(boss.name): \(error)")
                }
            }
        }
    }

    func testReplacementDecisionNamesGrowWithoutChangingEitherOwnedCopy() async throws {
        let model = try await fixture(.puzzle)
        let before = try model.game.encoded()
        let offer = try XCTUnwrap(Buffs.all.first { $0.id == "bf_insurance" })
        var glyphHeights: [CGFloat] = []
        for type in [DynamicTypeSize.large, .accessibility5] {
            let panel = SkipBuffReplacementSlip(offer: offer, buffs: model.run.buffs) { _ in
                XCTFail("Reading and scrolling must never accept a replacement")
            }
            try await withHosted(panel.padding(Phone.zoomedPro.insets), phone: .zoomedPro, type: type) { window in
                let scroll = scrollViews(in: window).max { $0.contentSize.height < $1.contentSize.height }
                let bottom = scroll.map { max(0, $0.contentSize.height - $0.bounds.height + $0.adjustedContentInset.bottom) } ?? 0
                let step = max(44, (scroll?.bounds.height ?? Phone.zoomedPro.size.height) * 0.4)
                var found = Set<String>()
                var height: CGFloat = 0
                for (index, offset) in (Array(stride(from: CGFloat.zero, to: bottom, by: step)) + [bottom]).enumerated() {
                    scroll?.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                    await settle(window)
                    let image = screenshot(window)
                    attach(image, name: "replacement-readable-growth-\(type)-\(index)")
                    let rows = try recognize(image)
                    let cancel = try XCTUnwrap(printedPhrase("Cancel", in: rows))
                    assertReadableAction(cancel, image: image, phone: .zoomedPro, context: "replacement")
                    for name in ["Replace Fresh Ink", "Replace Insurance"] {
                        if let row = printedPhrase(name, in: rows),
                           scroll.map({ $0.convert($0.bounds, to: window).contains(logicalBounds(row, image: image)) }) ?? true {
                            found.insert(name)
                        }
                    }
                    if let line = rows.first(where: { normalize($0.text).hasPrefix("replace") }) {
                        height = max(height, line.bounds.height * image.size.height)
                    }
                }
                XCTAssertEqual(found, Set(["Replace Fresh Ink", "Replace Insurance"]))
                glyphHeights.append(height)
            }
        }
        XCTAssertGreaterThan(glyphHeights[1], glyphHeights[0] * 1.2,
                             "Replacement choices must use visibly enlarged text")
        XCTAssertEqual(try model.game.encoded(), before)
        XCTAssertEqual(Set(model.run.buffs.map(\.id)).count, 2)
    }

    private func auditCorePages(on phone: Phone) async throws {
        for page in Page.allCases {
            let model = try await fixture(page)
            let original = try model.game.encoded()
            for type in largerText {
                do {
                try await withHostedPage(model, page: page, phone: phone, type: type) { host in
                    let label = "\(phone.name)-\(page)-\(type)"
                    let image = screenshot(host.window)
                    let rows = try recognize(image)
                    let allText = normalize(rows.map(\.text).joined(separator: " "))
                    attach(image, name: label)
                    XCTAssertFalse(scrollViews(in: host.window).contains {
                        $0.contentSize.height > $0.bounds.height + 1
                    }, "\(label): the core page must not need vertical scrolling")
                    for action in page.actions {
                        let row = try XCTUnwrap(printedPhrase(action, in: rows),
                                               "\(label): missing full action '\(action)' in \(allText)")
                        assertReadableAction(row, image: image, phone: phone, context: label)
                    }
                    switch page {
                    case .briefing:
                        let reward = try XCTUnwrap(model.currentSkipClaim?.offer.buff)
                        XCTAssertTrue(allText.contains(normalize(reward.name)), "\(label): \(allText)")
                        let summary = CatalogueDetails.item(reward.id)?.shortEffect ?? reward.text
                        XCTAssertTrue(allText.contains(normalize(summary)) || printedPhrase(summary, in: rows) != nil,
                                      "\(label): \(allText)")
                        assertSeparate("Skip + Buff", "Play puzzle", rows: rows, context: label)
                    case .puzzle:
                        let grid = try XCTUnwrap(host.geometry.frames[NumberReturnMotionAnchor.grid])
                        let hand = try XCTUnwrap(host.geometry.frames[NumberReturnMotionAnchor.hand])
                        let bounds = CGRect(origin: .zero, size: host.geometry.page.size)
                        XCTAssertTrue(bounds.insetBy(dx: -1, dy: -1).contains(grid), "\(label): board outside page")
                        XCTAssertTrue(bounds.insetBy(dx: -1, dy: -1).contains(hand), "\(label): Hand outside page")
                        XCTAssertFalse(grid.intersects(hand), "\(label): board and Hand overlap")
                        XCTAssertEqual(grid.width, grid.height, accuracy: 1)
                        XCTAssertGreaterThanOrEqual(grid.width, 140, "\(label): the board must remain usable")
                        assertSeparate("Toss", "End turn", rows: rows, context: label)
                    case .results:
                        assertSeparate("Keep filling", "Cash out", rows: rows, context: label)
                    case .shop:
                        for offer in try XCTUnwrap(model.shop).offers {
                            XCTAssertTrue(allText.contains(normalize(offer.def.name)),
                                          "\(label): missing complete offer '\(offer.def.name)' in \(allText)")
                        }
                    case .victory:
                        for phrase in ["Congratulations", "Professionally Overthinking", "Book achievement",
                                       "Volume 8 Complete", "Obstacle II is ready"] {
                            let directlyRead = allText.contains(normalize(phrase))
                            let cropRead = phrase == "Volume 8 Complete" && !directlyRead
                                ? try receiptTitleCropContains(phrase, rows: rows, image: image) : false
                            XCTAssertTrue(directlyRead || cropRead, "\(label): missing '\(phrase)' in \(allText)")
                        }
                        assertSeparate("Obstacle II is ready", "Close the Book", rows: rows, context: label)
                    }
                    XCTAssertEqual(try model.game.encoded(), original,
                                   "\(label): rendering must not change the Book or random streams")
                }
                } catch {
                    // One clipped control must not hide the remaining pages
                    // or intermediate text sizes from this audit.
                    XCTFail("\(phone.name)-\(page)-\(type): \(error)")
                }
            }
            model.cancelPuzzlePreparation()
        }
    }

    func testCustomPaperPanelsKeepDismissalAndDecisionsReachableAtZoomEquivalentAX5() async throws {
        for phone in [Phone.smallest, .zoomedPro] {
            let puzzle = try await fixture(.puzzle)
            let shop = try await fixture(.shop)
            let offer = try XCTUnwrap(shop.shop?.offers.first)
            var redrawRun = RunState(seed: "enlarged-baseline")
            redrawRun.coins = 999
            let redrawOffer = ShopOffer(slot: 4, defID: Buffs.redraw, price: 3)
            redrawRun.shop = ShopState(offers: [redrawOffer])
            let redrawShop = GameModel(frozen: Game(run: redrawRun), page: .shop)
            let award = try XCTUnwrap(Buffs.all.first { $0.id == "bf_insurance" })
            let panels: [(String, AnyView, [String], Set<String>)] = [
                ("buff", AnyView(BuffSlip(model: puzzle, index: 0, onDone: {})), ["Use", "Keep it"], ["Use", "Keep it"]),
                ("shop-offer", AnyView(OfferSlip(model: shop, offer: offer, markerBought: { _ in })), ["Buy this item", "Close"], ["Close"]),
                ("redraw-offer", AnyView(OfferSlip(model: redrawShop, offer: redrawOffer, markerBought: { _ in })), ["Buy this item", "Close"], ["Close"]),
                ("skip-replacement", AnyView(SkipBuffReplacementSlip(offer: award,
                    buffs: puzzle.run.buffs, onReplace: { _ in })), ["Replace Fresh Ink", "Replace Insurance", "Cancel"], ["Cancel"]),
                ("settings", AnyView(SettingsSlip(model: puzzle, onAbandon: {}, onClose: {})), ["Abandon Book", "Close"], ["Close"])
            ]
            for (name, panel, actions, pinnedActions) in panels {
                try await withHosted(panel.padding(phone.insets), phone: phone, type: .accessibility5) { window in
                    var seen: [String: PrintedRow] = [:]
                    var pinnedFrames: [String: CGRect] = [:]
                    var originalFooterFrame: CGRect?
                    var originalFooterPixels: Data?
                    let scroll = scrollViews(in: window).max { $0.contentSize.height < $1.contentSize.height }
                    let bottom = scroll.map { max(0, $0.contentSize.height - $0.bounds.height + $0.adjustedContentInset.bottom) } ?? 0
                    let step = max(44, (scroll?.bounds.height ?? phone.size.height) * 0.45)
                    let offsets = Array(stride(from: CGFloat.zero, to: bottom, by: step)) + [bottom]
                    for (index, offset) in offsets.enumerated() {
                        if let scroll {
                            scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
                            await settle(window)
                        }
                        let image = screenshot(window)
                        attach(image, name: "\(phone.name)-\(name)-AX5-step\(index)")
                        let rows = try recognize(image)
                        let articleFrame = scroll.map { $0.convert($0.bounds, to: window) }
                        if let articleFrame {
                            // Vision can shift the estimated word width as the
                            // surrounding article changes. Compare the actual
                            // footer pixels instead of that inferred X center.
                            // UIScrollView conversion can return 382.0000000001
                            // for a 382pt pixel-aligned edge. Ceil would invent
                            // a one-pixel shift and compare different crops.
                            let top = (articleFrame.maxY * image.scale).rounded() / image.scale
                            let footerFrame = CGRect(x: phone.safeBounds.minX, y: top,
                                width: phone.safeBounds.width, height: phone.safeBounds.maxY - top)
                            XCTAssertGreaterThan(footerFrame.height, 0)
                            let pixels = try rgbaPixels(in: image, frame: footerFrame)
                            if let originalFooterFrame, let originalFooterPixels {
                                XCTAssertEqual(footerFrame, originalFooterFrame,
                                    "\(name): the pinned footer frame must not move while scrolling")
                                XCTAssertTrue(pixels == originalFooterPixels,
                                    "\(name): pinned footer pixels changed while scrolling")
                            } else {
                                originalFooterFrame = footerFrame
                                originalFooterPixels = pixels
                            }
                        }
                        // Explanatory prose can contain "use" or "cancel".
                        // Identify a pinned action only from fully visible
                        // glyphs in the footer, never that scrolling prose.
                        let footerRows = rows.filter { row in
                            let rect = logicalBounds(row, image: image)
                            return phone.safeBounds.insetBy(dx: -1, dy: -1).contains(rect)
                                && (articleFrame.map { rect.minY >= $0.maxY - 1 } ?? true)
                        }
                        for action in actions {
                            let candidates = pinnedActions.contains(action) ? footerRows : rows
                            if let row = printedPhrase(action, in: candidates) {
                                let rect = logicalBounds(row, image: image)
                                if let scroll {
                                    let frame = scroll.convert(scroll.bounds, to: window)
                                    if pinnedActions.contains(action) {
                                        XCTAssertGreaterThanOrEqual(rect.minY, frame.maxY - 1,
                                            "\(name): pinned '\(action)' must remain below the scrolling article")
                                    } else {
                                        // Intermediate offsets may cut across an
                                        // article control. Count only a fully
                                        // visible label within its clip bounds.
                                        guard frame.insetBy(dx: -1, dy: -1).contains(rect) else { continue }
                                    }
                                }
                                if pinnedActions.contains(action) {
                                    if let original = pinnedFrames[action] {
                                        XCTAssertEqual(rect.midY, original.midY, accuracy: 1,
                                            "\(name): pinned '\(action)' moved while scrolling")
                                    } else { pinnedFrames[action] = rect }
                                }
                                seen[action] = row
                                assertReadableAction(row, image: image, phone: phone, context: name)
                            }
                        }
                        for pinned in pinnedActions {
                            XCTAssertNotNil(printedPhrase(pinned, in: footerRows),
                                "\(phone.name) \(name): pinned '\(pinned)' must stay visible below the article while it scrolls")
                        }
                    }
                    for action in actions { XCTAssertNotNil(seen[action], "\(phone.name) \(name): '\(action)' unreachable") }
                }
            }
        }
    }

    func testAnchoredHandMenuKeepsEveryChoiceReadableInZoomEquivalentSizes() async throws {
        for phone in [Phone.smallest, .zoomedPro] {
            for type in [DynamicTypeSize.large, .accessibility5] {
                let model = try await fixture(.puzzle)
                let original = try model.game.encoded()
                try await withHostedPage(model, page: .puzzle, phone: phone, type: type) { host in
                    let presenter = try XCTUnwrap(host.geometry.arrangement)
                    let hand = try XCTUnwrap(host.geometry.frames[NumberReturnMotionAnchor.hand])
                        .offsetBy(dx: host.geometry.page.minX, dy: host.geometry.page.minY)
                    let owner = UUID()
                    presenter.toggle(owner: owner,
                        anchor: CGRect(x: phone.size.width - 52, y: hand.minY - 44, width: 44, height: 44), model: model)
                    await settle(host.window)
                    XCTAssertNotNil(presenter.session)
                    let image = screenshot(host.window)
                    attach(image, name: "\(phone.name)-arrangement-\(type)")
                    let rows = try recognize(image)
                    for action in ["Ascending", "Descending", "Shuffle hand"] {
                        let row = try XCTUnwrap(printedPhrase(action, in: rows),
                                               "\(phone.name) \(type): arrangement choice '\(action)' was clipped")
                        assertReadableAction(row, image: image, phone: phone, context: "arrangement")
                    }
                    assertSeparate("Ascending", "Descending", rows: rows, context: "arrangement")
                    assertSeparate("Descending", "Shuffle hand", rows: rows, context: "arrangement")
                    presenter.dismiss(owner: owner)
                    XCTAssertNil(presenter.session)
                    XCTAssertEqual(try model.game.encoded(), original)
                }
            }
        }
    }

    func testMarkerInspectionAtBoardEdgesFitsZoomEquivalentSizesWithoutMovingGameplay() async throws {
        for phone in [Phone.smallest, .zoomedPro] {
            for type in [DynamicTypeSize.large, .accessibility5] {
                let model = try await fixture(.puzzle)
                let original = try model.game.encoded()
                try await withHostedPage(model, page: .puzzle, phone: phone, type: type) { host in
                    let originalFrames = host.geometry.frames
                    for square in [Square(0), Square(8), Square(72), Square(80)] {
                        let cell = try XCTUnwrap(originalFrames[NumberReturnMotionAnchor.cell(square)])
                            .offsetBy(dx: host.geometry.page.minX, dy: host.geometry.page.minY)
                        host.inspection.begin(square: square, model: model, cellFrame: cell,
                                              source: .accessibility, feedback: {})
                        await settle(host.window)
                        XCTAssertNotNil(host.inspection.session)
                        let popup = host.inspection.popupFrame
                        XCTAssertTrue(phone.safeBounds.insetBy(dx: -1, dy: -1).contains(popup),
                                      "\(phone.name) \(type): inspection left the safe area")
                        XCTAssertFalse(popup.intersects(cell), "Inspection must leave the held square visible")
                        let image = screenshot(host.window)
                        attach(image, name: "\(phone.name)-marker-\(square.index)-\(type)")
                        let rows = try recognize(image)
                        let dismiss = try XCTUnwrap(rows.first { normalize($0.text).contains("dismiss") })
                        assertReadableAction(dismiss, image: image, phone: phone, context: "marker inspection")
                        XCTAssertEqual(host.geometry.frames, originalFrames)
                        XCTAssertEqual(try model.game.encoded(), original)
                        host.inspection.dismiss()
                        await settle(host.window)
                    }
                }
            }
        }
    }

    private enum Page: CaseIterable, Equatable {
        case briefing, puzzle, results, shop, victory
        var actions: [String] {
            switch self {
            case .briefing: return ["Skip + Buff", "Play puzzle"]
            case .puzzle: return ["Toss", "End turn"]
            case .results: return ["Keep filling", "Cash out"]
            case .shop: return ["Reroll", "Continue"]
            case .victory: return ["Close the Book"]
            }
        }
    }

    private struct Phone {
        let name: String
        let size: CGSize
        let insets: EdgeInsets
        var safeBounds: CGRect { CGRect(x: 0, y: insets.top, width: size.width,
                                         height: size.height - insets.top - insets.bottom) }
        static let smallest = Phone(name: "zoom-equivalent-320", size: CGSize(width: 320, height: 568),
                                    insets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
        static let se = Phone(name: "SE-375", size: CGSize(width: 375, height: 667),
                              insets: EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0))
        static let zoomedPro = Phone(name: "zoom-equivalent-393", size: CGSize(width: 393, height: 852),
                                     insets: EdgeInsets(top: 59, leading: 0, bottom: 34, trailing: 0))
        static let pro = Phone(name: "17Pro-402", size: CGSize(width: 402, height: 874),
                               insets: EdgeInsets(top: 62, leading: 0, bottom: 34, trailing: 0))
    }

    private func fixture(_ page: Page, seed: String = "enlarged-display-audit",
                         slot: PuzzleSlot = .easy, boss: BossModifier = .unluckyLucky) async throws -> GameModel {
        var run = RunState(seed: seed, book: page == .victory ? .overthinking : .probably)
        run.bookmarks = Bookmarks.all.prefix(5).map {
            OwnedBookmark(defID: $0.id, boughtAtLevel: 1, pricePaid: $0.listedPrice)
        }
        run.buffs = [OwnedBuff(defID: Buffs.freshInk, pricePaid: 4), OwnedBuff(defID: "bf_insurance", pricePaid: 3)]
        run.markers = [OwnedMarker(defID: Markers.jade, boughtAtLevel: 1, pricePaid: 0,
                                  squares: [Square(0), Square(8), Square(72), Square(80)])]
        if page == .briefing {
            run.slot = slot
            run.pendingBoss = boss
            let model = GameModel(resuming: Game(run: run), savesProgress: false)
            let prepared = await model.prepareUpcomingPuzzle()
            XCTAssertNotNil(prepared)
            return model
        }
        if page == .shop {
            run.coins = 999
            let ids = ["bm_the_sunday_supplement", "bm_letters_to_the_editor", "mk_silver",
                       "mk_sapphire", "bf_second_print", Buffs.paperCrane]
            run.shop = ShopState(offers: ids.enumerated().map { ShopOffer(slot: $0.offset, defID: $0.element, price: 5) })
            return GameModel(frozen: Game(run: run), page: .shop)
        }
        if page == .victory { run.level = 9; run.slot = .boss; run.pendingBoss = .unluckyLucky }
        var game = Game(run: run)
        try game.startPuzzle()
        if page == .results || page == .victory { game.qaMeetTarget() }
        if page == .victory { _ = try game.cashOut() }
        return GameModel(frozen: game, page: page == .puzzle ? .puzzle : .results)
    }

    private final class Geometry {
        var page = CGRect.zero
        var frames: [String: CGRect] = [:]
        var arrangement: HandArrangementPresenter?
    }

    private struct ArrangementProbe: View {
        @Environment(\.handArrangementPresenter) private var presenter
        let report: (HandArrangementPresenter?) -> Void
        var body: some View { Color.clear.task { report(presenter) } }
    }

    private struct Host {
        let window: UIWindow
        let geometry: Geometry
        let inspection: MarkerInspectionPresenter
    }

    private func withHostedPage(_ model: GameModel, page: Page, phone: Phone, type: DynamicTypeSize,
                                check: (Host) async throws -> Void) async throws {
        let flipper = PageFlipper()
        let inspection = MarkerInspectionPresenter()
        let geometry = Geometry()
        let content = BookView(flipper: flipper, showsChrome: false) {
            GameplayShell(model: model, controls: [
                StripControl(systemImage: "questionmark", label: "Run information", action: {}),
                StripControl(systemImage: "gearshape", label: "Settings", action: {})
            ], onTapBuff: { _ in }, inspectionPresenter: inspection) {
                pageView(model, page: page)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { geometry.page = $0 }
                    .background(ArrangementProbe { geometry.arrangement = $0 })
            }
            .padding(phone.insets)
        }
        .environment(flipper)
        .onPreferenceChange(NumberReturnMotionFrames.self) { geometry.frames = $0 }
        defer { flipper.cancel(); inspection.dismiss() }
        try await withHosted(content, phone: phone, type: type) { window in
            try await check(Host(window: window, geometry: geometry, inspection: inspection))
        }
    }

    @ViewBuilder private func pageView(_ model: GameModel, page: Page) -> some View {
        switch page {
        case .briefing: PuzzleBriefingView(model: model)
        case .puzzle: PuzzlePageView(model: model, puzzle: model.puzzle!, isClockRunning: false)
        case .results, .victory: ResultsPageView(model: model, onBookCompletion: {}, onAbandon: {})
        case .shop: ShopPageView(model: model, shop: model.shop!, onClaimMarker: { _ in })
        }
    }

    private func withHosted<V: View>(_ content: V, phone: Phone, type: DynamicTypeSize,
                                     check: (UIWindow) async throws -> Void) async throws {
        let host = UIHostingController(rootView: content
            .frame(width: phone.size.width, height: phone.size.height)
            .background { GameplaySurfaceBackground() }
            .environment(\.cosmeticTheme, .standard)
            .environment(\.dynamicTypeSize, type)
            .environment(\.scenePhase, .active)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = host
        defer { window.isHidden = true; window.rootViewController = nil; previousKey?.makeKey() }
        window.makeKeyAndVisible()
        await settle(window)
        try await check(window)
    }

    private func settle(_ window: UIWindow) async {
        try? await Task.sleep(for: .milliseconds(120))
        window.layoutIfNeeded()
    }

    private struct PrintedRow {
        let text: String
        let bounds: CGRect
        var alternatives: [String] = []
    }

    private func recognize(_ image: UIImage) throws -> [PrintedRow] {
        let source = try XCTUnwrap(image.cgImage)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: source).perform([request])
        return try (request.results ?? []).compactMap { row in
            let candidates = row.topCandidates(10)
            guard let first = candidates.first else { return nil }
            var alternatives = candidates.dropFirst().map(\.string)
            // Serif ff can be ranked as fi in a full-page paragraph pass.
            // A tight crop of this same complete action reads the ligature
            // correctly; no expected spelling is supplied to the recognizer.
            let text = normalize(first.string)
            if text.hasPrefix("skip"), !text.contains("reward") {
                let box = row.boundingBox
                let rect = CGRect(x: box.minX * CGFloat(source.width) - 12,
                    y: (1 - box.maxY) * CGFloat(source.height) - 12,
                    width: box.width * CGFloat(source.width) + 24,
                    height: box.height * CGFloat(source.height) + 24)
                if let crop = source.cropping(to: rect) {
                    let retry = VNRecognizeTextRequest()
                    retry.recognitionLevel = .accurate
                    retry.recognitionLanguages = ["en-US"]
                    retry.usesLanguageCorrection = false
                    try VNImageRequestHandler(cgImage: crop).perform([retry])
                    alternatives += (retry.results ?? []).flatMap { $0.topCandidates(10).map(\.string) }
                }
            }
            return PrintedRow(text: first.string, bounds: row.boundingBox, alternatives: alternatives)
        }
    }

    private func rgbaPixels(in image: UIImage, frame: CGRect) throws -> Data {
        let source = try XCTUnwrap(image.cgImage)
        let pixelFrame = CGRect(x: frame.minX * image.scale, y: frame.minY * image.scale,
                                width: frame.width * image.scale, height: frame.height * image.scale).integral
        let crop = try XCTUnwrap(source.cropping(to: pixelFrame))
        // Materialize tightly packed pixels; a CGImage crop's backing provider
        // can retain bytes outside the visible crop, including the article.
        var pixels = Data(count: crop.width * crop.height * 4)
        let rendered = pixels.withUnsafeMutableBytes { storage -> Bool in
            guard let context = CGContext(data: storage.baseAddress, width: crop.width, height: crop.height,
                bitsPerComponent: 8, bytesPerRow: crop.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            return true
        }
        XCTAssertTrue(rendered, "Footer pixels must be readable before testing stability")
        return pixels
    }

    private func assertReadableAction(_ row: PrintedRow, image: UIImage, phone: Phone, context: String) {
        let rect = logicalBounds(row, image: image)
        XCTAssertTrue(phone.safeBounds.insetBy(dx: -1, dy: -1).contains(rect), "\(context): action glyphs outside safe area: \(row.text)")
        XCTAssertGreaterThanOrEqual(rect.height, 9, "\(context): action text became too small: \(row.text)")
    }

    private func assertSeparate(_ first: String, _ second: String, rows: [PrintedRow], context: String) {
        guard let a = printedPhrase(first, in: rows), let b = printedPhrase(second, in: rows) else { return }
        XCTAssertFalse(a.bounds.intersects(b.bounds), "\(context): '\(first)' overlaps '\(second)'")
    }

    private func logicalBounds(_ row: PrintedRow, image: UIImage) -> CGRect {
        CGRect(x: row.bounds.minX * image.size.width, y: (1 - row.bounds.maxY) * image.size.height,
               width: row.bounds.width * image.size.width, height: row.bounds.height * image.size.height)
    }

    /// Wrapped labels are one control. Only join vertically adjacent rows
    /// whose complete text is the requested phrase; unrelated article text
    /// cannot make a partially clipped action pass.
    private func printedPhrase(_ phrase: String, in rows: [PrintedRow]) -> PrintedRow? {
        let target = normalize(phrase)
        for row in rows {
            if let match = ([row.text] + row.alternatives).first(where: { normalize($0).contains(target) }) {
                return PrintedRow(text: match, bounds: row.bounds)
            }
        }
        let ordered = rows.sorted { $0.bounds.maxY > $1.bounds.maxY }
        for first in ordered.indices {
            var prefixes = Set(([ordered[first].text] + ordered[first].alternatives).map(normalize)
                .filter { !$0.isEmpty && target.hasPrefix($0) })
            guard !prefixes.isEmpty else { continue }
            var bounds = ordered[first].bounds
            var previous = ordered[first].bounds
            for next in ordered.indices where next > first {
                let row = ordered[next]
                let gap = previous.minY - row.bounds.maxY
                guard gap >= -0.004, gap < max(previous.height, row.bounds.height) * 1.3,
                      min(previous.maxX, row.bounds.maxX) > max(previous.minX, row.bounds.minX) else { break }
                let candidates = ([row.text] + row.alternatives).map(normalize)
                prefixes = Set(prefixes.flatMap { prefix in candidates.map { prefix + $0 } }
                    .filter { target.hasPrefix($0) })
                guard !prefixes.isEmpty else { break }
                bounds = bounds.union(row.bounds)
                if prefixes.contains(target) { return PrintedRow(text: phrase, bounds: bounds) }
                previous = row.bounds
            }
        }
        return nil
    }

    /// Vision dropped the clearly printed8 in one full-screen320 image.
    /// Retry only the already-located title crop; the digit is still required.
    private func receiptTitleCropContains(_ phrase: String, rows: [PrintedRow], image: UIImage) throws -> Bool {
        guard let title = rows.first(where: { normalize($0.text).contains("volume") && normalize($0.text).contains("complete") }) else { return false }
        let rect = logicalBounds(title, image: image).insetBy(dx: -5, dy: -5)
            .intersection(CGRect(origin: .zero, size: image.size))
        let pixels = rect.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))
        guard let crop = image.cgImage?.cropping(to: pixels) else { return false }
        let cropped = UIImage(cgImage: crop, scale: image.scale, orientation: .up)
        attach(cropped, name: "receipt-title-OCR-retry")
        return try recognize(cropped).contains { normalize($0.text).contains(normalize(phrase)) }
    }

    private func normalize(_ text: String) -> String {
        text.lowercased().replacingOccurrences(of: #"\bobstacle\s+il\b"#, with: "obstacle ii", options: .regularExpression)
            .filter { $0.isLetter || $0.isNumber }
    }

    private func screenshot(_ window: UIWindow) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = "enlarged-display-\(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }
}
