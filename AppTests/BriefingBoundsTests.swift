import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BriefingBoundsTests: XCTestCase {
    private let verifiedPeekSource = "+1 Clue this Puzzle; a revealed placement scores 0 unless Onyx restores it."

    func testVerifiedPeekOCRCorrectionCannotAcceptAnotherNumberOrMissingOnyxRule() throws {
        let peek = try XCTUnwrap(Buffs.all.first { $0.id == Buffs.peek })
        XCTAssertEqual(CatalogueDetails.item(peek.id)?.shortEffect, verifiedPeekSource,
                       "The numerical gameplay rule must remain literal0 in the actual catalogue source")
        let observed = verifiedPeekSource.replacingOccurrences(of: "scores 0 unless Onyx restores it",
                                                               with: "scores O unless Onyx restores it")
        XCTAssertTrue(matchesVerifiedPeekRendering(normalize(observed), buff: peek))
        for wrong in ["1", "2", "10"] {
            XCTAssertFalse(matchesVerifiedPeekRendering(normalize(verifiedPeekSource
                .replacingOccurrences(of: "scores 0", with: "scores \(wrong)")), buff: peek))
        }
        XCTAssertFalse(matchesVerifiedPeekRendering(normalize(observed.replacingOccurrences(of: "Onyx restores it", with: "")), buff: peek))
        XCTAssertFalse(matchesVerifiedPeekRendering(normalize(observed.replacingOccurrences(of: "+1 Clue", with: "+2 Clues")), buff: peek))
        let insurance = try XCTUnwrap(Buffs.all.first { $0.id == "bf_insurance" })
        XCTAssertFalse(matchesVerifiedPeekRendering(normalize(observed), buff: insurance))
    }

    func testEveryViewportBudgetsTheWholeDecisionWithoutScrolling() {
        for size in [CGSize(width: 300, height: 440), CGSize(width: 359, height: 537),
                     CGSize(width: 386, height: 672), CGSize(width: 834, height: 1_040)] {
            let layout = PuzzleBriefingLayout(available: size)
            let used = layout.headerHeight + layout.routeHeight + layout.targetHeight
                + layout.boardSide + layout.decisionHeight + layout.actionHeight + layout.spacing * 5
            XCTAssertLessThanOrEqual(used, layout.contentSize.height + 0.01)
            XCTAssertLessThanOrEqual(layout.boardSide, layout.contentSize.width)
            XCTAssertGreaterThanOrEqual(layout.boardSide, 80)
            XCTAssertGreaterThanOrEqual(layout.actionHeight, 44)
            XCTAssertLessThanOrEqual(layout.contentSize.width, 560)
            XCTAssertLessThanOrEqual(layout.contentSize.height, 840)
        }
    }

    func testEveryBuffKeepsItsCanonicalSummaryOnTheCompactRewardSlip() throws {
        for width: CGFloat in [320, 386, 560] {
            for buff in Buffs.all {
                let compact = width == 320
                // Enlarged text owns its natural height. The hosted page
                // tests verify that this measured article and both decisions
                // fit the phone; a fixed 100pt box would reward tiny type.
                let renderer = ImageRenderer(content: BriefingRewardSlip(buff: buff, compact: compact,
                    readingStyle: BriefingReadingStyle(available: CGSize(width: width, height: compact ? 440 : 650), scale: 3.12))
                    .frame(width: width)
                    .environment(\.cosmeticTheme, .standard)
                    .environment(\.dynamicTypeSize, .accessibility5))
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                let attachment = XCTAttachment(image: image)
                attachment.name = "briefing-readable-reward-\(Int(width))-\(buff.id)"
                attachment.lifetime = .keepAlways
                add(attachment)
                let text = try recognize(image)
                XCTAssertTrue(text.contains(normalize(buff.name)), "\(width): \(buff.name): \(text)")
                let printedEffect = CatalogueDetails.item(buff.id)?.shortEffect ?? buff.text
                let effect = normalize(printedEffect)
                // A serif 0 may be recognized as O without language context.
                // Re-read the same pixels; retain the exact numerical rule.
                let retry = text.contains(effect) ? text : try recognize(image, languageCorrection: true)
                let exactCandidate = retry.contains(effect) ? true : try recognizesExactPhrase(printedEffect, in: image)
                XCTAssertTrue(exactCandidate || matchesVerifiedPeekRendering(text, buff: buff),
                              "\(width): \(buff.text): \(text); retry: \(retry)")
                XCTAssertTrue(text.contains("skipreward"))
                XCTAssertFalse(text.contains("skipsremaining"))
            }
        }
    }

    func testPhoneAndTabletBriefingsShowBoardOfferAndActionsTogether() async throws {
        for viewport in Viewport.all {
            for slot in [PuzzleSlot.easy, .boss] {
                let page = try await measure(slot: slot, boss: .editor, viewport: viewport,
                                             fullInventory: true)
                XCTAssertTrue(page.text.contains("nextpuzzle"), page.text)
                XCTAssertTrue(page.text.contains("chapter1"), page.text)
                XCTAssertTrue(page.text.contains("target"), page.text)
                XCTAssertTrue(page.text.contains("10turns"), page.text)
                XCTAssertTrue(page.text.contains("playpuzzle"), page.text)
                XCTAssertTrue(page.text.contains(normalize(BossModifier.editor.name)), page.text)
                XCTAssertFalse(page.text.contains("preparingpuzzle"), "The real prepared board must be visible.")
                XCTAssertFalse(page.hasScrollableContent)
                if slot == .easy {
                    let buff = try XCTUnwrap(RunState(seed: "briefing-height-regression").currentSkipOffer).buff
                    XCTAssertTrue(page.text.contains(normalize(buff.name)), page.text)
                    XCTAssertTrue(page.text.contains(normalize(CatalogueDetails.item(buff.id)?.shortEffect ?? buff.text)), page.text)
                    let skip = try recognizedFrame(in: page.image, containing: "Skip + Buff")
                    let play = try recognizedFrame(in: page.image, containing: "Play puzzle")
                    XCTAssertLessThan(skip.maxX, play.minX)
                    XCTAssertEqual(skip.midY, play.midY, accuracy: 8)
                } else {
                    XCTAssertTrue(page.text.contains("bosspuzzlesmustbeplayed"), page.text)
                    XCTAssertFalse(page.text.contains("skipbuff"))
                }
            }
        }
    }

    func testSkippingKeepsRouteBoardAndActionAllocationStable() async throws {
        let viewport = Viewport.pro
        let first = try await measure(slot: .easy, boss: .editor, viewport: viewport)
        let route = try recognizedFrame(in: first.image, containing: BossModifier.editor.name)
        let play = try recognizedFrame(in: first.image, containing: "Play puzzle")
        for skips in 1...2 {
            let after = try await measure(slot: .easy, boss: .editor, viewport: viewport, skips: skips)
            let nextRoute = try recognizedFrame(in: after.image, containing: BossModifier.editor.name)
            let nextPlay = try recognizedFrame(in: after.image, containing: "Play puzzle")
            XCTAssertEqual(nextRoute.midY, route.midY, accuracy: 1.5)
            XCTAssertEqual(nextPlay.midY, play.midY, accuracy: 1.5)
            XCTAssertTrue(after.text.contains("buffadded"), after.text)
            XCTAssertFalse(after.hasScrollableContent)
        }
    }

    func testLongestBossRulesRemainCompleteOnShortPhoneWithoutScrolling() async throws {
        for boss in [BossModifier.unluckyLucky, .overPusher, .grayTheGarry, .garryTheGray, .accountant] {
            for type in [DynamicTypeSize.large, .accessibility5] {
            let page = try await measure(slot: .boss, boss: boss, viewport: .short,
                                         dynamicType: type)
            XCTAssertTrue(page.text.contains(normalize(boss.text)), "\(boss.name): \(page.text)")
            XCTAssertTrue(page.text.contains(normalize(boss.name)), page.text)
            // The full name in the lower encounter slip must not mask a
            // truncated route label. Read only the third stop above Target.
            if type == .large {
                let routeCrop = try bossRouteCrop(in: page.image)
                let routeText = try recognize(routeCrop)
                XCTAssertTrue(routeText.contains(normalize(boss.name)),
                              "The route itself must name \(boss.name) completely: \(routeText)")
                let routeAttachment = XCTAttachment(image: routeCrop)
                routeAttachment.name = "briefing-route-name-\(boss.rawValue)"
                routeAttachment.lifetime = .keepAlways
                add(routeAttachment)
            } else {
                XCTAssertTrue(page.text.contains("chapter1boss"), "The concise reading hierarchy must retain the current stop.")
            }
            let note = try recognizedFrame(in: page.image, containing: "Boss Puzzles must be played")
            let play = try recognizedFrame(in: page.image, containing: "Play puzzle")
            XCTAssertLessThan(note.maxY, play.minY)
            XCTAssertFalse(page.hasScrollableContent)
            }
        }
    }

    func testLargerTextOrdinaryBriefingsRetainTheAnnouncedBossAndItsPower() async throws {
        for boss in [BossModifier.collateral, .chainStitcher, .unluckyLucky] {
            for type in [DynamicTypeSize.xLarge, .accessibility5] {
                let page = try await measure(slot: .easy, boss: boss, viewport: .short, dynamicType: type)
                XCTAssertTrue(page.text.contains(normalize("Chapter boss: \(boss.name)")), page.text)
                XCTAssertTrue(page.text.contains(normalize(boss.text)), page.text)
                XCTAssertTrue(page.text.contains("skipbuff"), page.text)
                XCTAssertTrue(page.text.contains("playpuzzle"), page.text)
                XCTAssertFalse(page.hasScrollableContent)
                let skip = try recognizedFrame(in: page.image, containing: "Skip + Buff")
                let play = try recognizedFrame(in: page.image, containing: "Play puzzle")
                XCTAssertLessThan(skip.maxY, play.minY, "Both enlarged actions remain separate and reachable")
            }
        }
    }

    func testBlankBossBandPreservesTheExactPreviousBoardHeightBudget() throws {
        for width: CGFloat in [280, 300, 327, 365] {
            for type in [DynamicTypeSize.large, .accessibility5] {
                let oldReservation = try render(BossStamp(boss: .deadline, censored: nil).opacity(0), width: width, type: type)
                let emptyReservation = try render(BossStampReservation(), width: width, type: type)
                XCTAssertEqual(emptyReservation.size.height, oldReservation.size.height, accuracy: 0.01)
                XCTAssertTrue(try recognize(emptyReservation).isEmpty)
            }
        }
    }

    func testEveryKnownRouteAnnouncesCommittedBossNameAndFullPower() {
        for slot in PuzzleSlot.allCases {
            for boss in BossModifier.allCases {
                let announcement = RunRouteStrip(currentSlot: slot, boss: boss).accessibilitySummary
                XCTAssertTrue(announcement.contains(boss.name))
                XCTAssertTrue(announcement.contains(boss.text))
            }
        }
        let unknown = RunRouteStrip(currentSlot: .easy, boss: nil).accessibilitySummary
        XCTAssertTrue(unknown.contains("not yet known"))
        XCTAssertFalse(unknown.contains(BossModifier.deadline.name))
    }

    private struct Viewport {
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
        static let short = Viewport(size: CGSize(width: 375, height: 667), top: 20, bottom: 0)
        static let pro = Viewport(size: CGSize(width: 402, height: 874), top: 62, bottom: 34)
        static let all = [short, pro, Viewport(size: CGSize(width: 834, height: 1_194), top: 24, bottom: 20)]
    }

    private struct Measurement {
        let text: String
        let image: UIImage
        let hasScrollableContent: Bool
    }

    private func measure(slot: PuzzleSlot, boss: BossModifier, viewport: Viewport, skips: Int = 0,
                         fullInventory: Bool = false, dynamicType: DynamicTypeSize = .large) async throws -> Measurement {
        var run = RunState(seed: "briefing-height-regression")
        run.slot = slot
        run.pendingBoss = boss
        if fullInventory {
            run.bookmarks = Bookmarks.all.prefix(5).map {
                OwnedBookmark(defID: $0.id, boughtAtLevel: run.level, pricePaid: $0.listedPrice)
            }
            run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 3), OwnedBuff(defID: Buffs.freshInk, pricePaid: 4)]
        }
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        for _ in 0..<skips {
            let claim = try XCTUnwrap(model.currentSkipClaim)
            XCTAssertTrue(model.takeSkip(ifCurrent: claim))
        }
        let before = try model.game.encoded()
        let preparation = await model.prepareUpcomingPuzzle()
        XCTAssertNotNil(preparation)
        let preview = try XCTUnwrap(model.preparedPuzzlePreview)
        let preparedBoard = try XCTUnwrap(preparation?.puzzle?.board)
        XCTAssertEqual(preview.board.placed, preparedBoard.placed)
        XCTAssertEqual(preview.board.filledBy, preparedBoard.filledBy)
        let flipper = PageFlipper()
        let content = RunPageSurface(model: model, flipper: flipper, controls: [
            StripControl(systemImage: "questionmark", label: "Run information", action: {}),
            StripControl(systemImage: "gearshape", label: "Settings", action: {})
        ], safeAreaInsets: EdgeInsets(top: viewport.top, leading: 0, bottom: viewport.bottom, trailing: 0),
           onTapBuff: { _ in }) {
            PuzzleBriefingView(model: model)
        }
        .frame(width: viewport.size.width, height: viewport.size.height)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.levelPalette, .forDisplay(slot: slot))
        .environment(\.scenePhase, .active)
        .environment(\.dynamicTypeSize, dynamicType)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: viewport.size)
        window.rootViewController = host
        defer {
            model.cancelPuzzlePreparation()
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        try await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: viewport.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        func scrollViews(in view: UIView) -> [UIScrollView] {
            (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
        }
        let scrollable = scrollViews(in: host.view).contains {
            $0.contentSize.height > $0.bounds.height + 1 || $0.contentSize.width > $0.bounds.width + 1
        }
        XCTAssertEqual(try model.game.encoded(), before, "Rendering the true next board cannot commit a deal, award, or RNG change.")
        let attachment = XCTAttachment(image: image)
        attachment.name = "briefing-single-page-\(Int(viewport.size.width))-\(slot.rawValue)-\(boss.rawValue)-skips\(skips)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return Measurement(text: try recognize(image), image: image, hasScrollableContent: scrollable)
    }

    private func bossRouteCrop(in image: UIImage) throws -> UIImage {
        let chapter = try recognizedFrame(in: image, containing: "Chapter 1")
        let target = try recognizedFrame(in: image, containing: "Target")
        let bounds = CGRect(x: image.size.width * 2 / 3,
                            y: chapter.maxY + 3,
                            width: image.size.width / 3,
                            height: target.minY - chapter.maxY - 6)
        XCTAssertGreaterThan(bounds.height, 0)
        let pixels = bounds.applying(CGAffineTransform(scaleX: image.scale, y: image.scale))
        let crop = try XCTUnwrap(image.cgImage?.cropping(to: pixels))
        return UIImage(cgImage: crop, scale: image.scale, orientation: .up)
    }

    private func render<V: View>(_ content: V, width: CGFloat, type: DynamicTypeSize) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width).environment(\.dynamicTypeSize, type))
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage)
    }

    private func recognize(_ image: UIImage, languageCorrection: Bool = false) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = languageCorrection
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return normalize((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " "))
    }

    /// Vision can rank O above 0 in a serif line. Require a complete sequence
    /// of its actual candidates, including the digit; never substitute a rule
    /// word or number in the recognized output.
    private func recognizesExactPhrase(_ phrase: String, in image: UIImage) throws -> Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let rows = request.results ?? []
        let goal = normalize(phrase)
        for start in rows.indices {
            var prefixes: Set<String> = [""]
            for row in rows.dropFirst(start) {
                let candidates = row.topCandidates(10).map { normalize($0.string) }
                prefixes = Set(prefixes.flatMap { prefix in candidates.map { prefix + $0 } }
                    .filter { goal.hasPrefix($0) })
                if prefixes.contains(goal) { return true }
                if prefixes.isEmpty { break }
            }
        }
        return false
    }

    /// Verified against verified-peek-ocr-zero.png. The view renders
    /// the canonical short effect; this exact source contains0, while both Vision engines
    /// identify the narrow serif glyph as O at the start of its wrapped line.
    /// No other number, clause, item, or catalogue revision is normalized.
    private func matchesVerifiedPeekRendering(_ text: String, buff: ItemDef) -> Bool {
        guard buff.id == Buffs.peek, CatalogueDetails.item(buff.id)?.shortEffect == verifiedPeekSource else { return false }
        let observed = verifiedPeekSource.replacingOccurrences(of: "scores 0 unless Onyx restores it",
                                                               with: "scores O unless Onyx restores it")
        return text.contains(normalize(observed))
    }

    private func recognizedFrame(in image: UIImage, containing text: String) throws -> CGRect {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let observation = try XCTUnwrap(request.results?.first {
            $0.topCandidates(1).first.map { normalize($0.string).contains(normalize(text)) } ?? false
        }, "Missing visible \(text)")
        let rect = observation.boundingBox
        return CGRect(x: rect.minX * image.size.width, y: (1 - rect.maxY) * image.size.height,
                      width: rect.width * image.size.width, height: rect.height * image.size.height)
    }

    private func normalize(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
}
