import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BriefingBoundsTests: XCTestCase {
    func testTabletReadingMeasureDoesNotChangePhonePageProposals() {
        for size in [CGSize(width: 300, height: 590), CGSize(width: 327, height: 646),
                     CGSize(width: 365, height: 700), CGSize(width: 390, height: 760)] {
            XCTAssertEqual(PuzzleBriefingLayout(available: size).contentSize, size)
            XCTAssertNil(PuzzleBriefingLayout(available: size).clippingMaximumHeight,
                         "Phone tickets keep their original flexible height.")
        }
        for size in [CGSize(width: 708, height: 870), CGSize(width: 774, height: 1_040),
                     CGSize(width: 964, height: 1_210)] {
            XCTAssertEqual(PuzzleBriefingLayout(available: size).contentSize,
                           CGSize(width: 560, height: 840))
            XCTAssertEqual(PuzzleBriefingLayout(available: size).clippingMaximumHeight, 280)
        }
    }

    func testEveryClippingFitsTheWidePageTicketWithoutItsFormerEmptyInterior() throws {
        let layout = PuzzleBriefingLayout(available: CGSize(width: 964, height: 1_210))
        for clipping in Clipping.allCases {
            let renderer = ImageRenderer(content: ClippingOfferTicket(
                clipping: clipping, remaining: 2, arrived: true,
                clipBounced: false, stampVisible: true, onTake: {})
                .frame(maxHeight: layout.clippingMaximumHeight)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.dynamicTypeSize, .large))
            renderer.proposedSize = ProposedViewSize(width: layout.contentSize.width,
                                                     height: layout.contentSize.height)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.height, 280, accuracy: 0.5)
            let text = try recognize(image)
            XCTAssertTrue(text.contains(normalize(clipping.name)))
            XCTAssertTrue(text.contains(normalize(clipping.detail)))
            XCTAssertTrue(text.contains(normalize("Skip + reward")))
        }
    }

    func testRouteCardsKeepTheirCompactMeasureInsteadOfStretchingAcrossAnIPad() throws {
        for width: CGFloat in [300, 327, 365, 708, 774, 964] {
            let renderer = ImageRenderer(content: RunRouteStrip(currentSlot: .easy, boss: .paywall)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.dynamicTypeSize, .large))
            renderer.proposedSize = ProposedViewSize(width: width, height: nil)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size.width, min(width, PuzzleBriefingLayout.routeMaximumWidth), accuracy: 0.5)
            XCTAssertEqual(image.size.height, 156, accuracy: 0.5,
                           "The tablet route remains the same three compact paper cards.")
        }
    }

    func testIPadBriefingsKeepTheirDecisionAndPlayActionInsideABoundedReadingColumn() async throws {
        let tablets = [
            Phone(size: CGSize(width: 768, height: 1_024), top: 24, bottom: 20),
            Phone(size: CGSize(width: 834, height: 1_194), top: 24, bottom: 20),
            Phone(size: CGSize(width: 1_024, height: 1_366), top: 24, bottom: 20)
        ]
        for tablet in tablets {
            let ordinary = try await measure(slot: .easy, boss: .paywall, phone: tablet)
            let boss = try await measure(slot: .boss, boss: .paywall, phone: tablet)
            let clipping = try XCTUnwrap(RunState(seed: "briefing-height-regression").currentClipping)
            XCTAssertTrue(ordinary.text.contains(normalize(clipping.name)), "The offered reward stays visible.")
            XCTAssertTrue(ordinary.text.contains(normalize(clipping.detail)), "Keep the full clipping rule readable.")
            XCTAssertTrue(ordinary.text.contains(normalize("Skip + reward")))
            let ticketHeading = try recognizedFrame(in: ordinary.image, containing: "Clipping on offer")
            let ticketAction = try recognizedFrame(in: ordinary.image, containing: "Skip + reward")
            XCTAssertLessThanOrEqual(ticketAction.maxY - ticketHeading.minY, 280,
                "The real page must not stretch the single-rule ticket back to roughly 500 points.")
            for page in [ordinary, boss] {
                let heading = try recognizedFrame(in: page.image, containing: "Next Puzzle")
                let play = try recognizedFrame(in: page.image, containing: "Play Puzzle")
                // Allow the Book's asymmetric binding insets and OCR glyph
                // bounds; the old edge-to-edge column misses by over 60pt.
                XCTAssertGreaterThanOrEqual(heading.minX, (tablet.size.width - 560) / 2 - 8,
                    "The decision must be centered in a reading column, not spread across the tablet.")
                XCTAssertLessThanOrEqual(play.maxY - heading.minY, 840,
                    "The flexible Clipping/encounter cannot stretch to fill the whole iPad page.")
                XCTAssertGreaterThan(play.minY, heading.maxY + 300)
                XCTAssertEqual(play.midX, tablet.size.width / 2, accuracy: 28)
                XCTAssertLessThanOrEqual(page.book.maxY, tablet.size.height - tablet.bottom - 8 + 0.5)
            }
            XCTAssertEqual(boss.book, ordinary.book, "Tablet content must not resize the physical Book.")
            XCTAssertEqual(boss.bookmarks, ordinary.bookmarks, "The HUD/bookmark boundary stays fixed.")
            XCTAssertTrue(boss.text.contains(normalize("Boss encounter")))
            XCTAssertTrue(boss.text.contains(normalize(BossModifier.paywall.name)))
        }
    }

    func testBossBriefingsKeepTheOrdinaryBookAndBookmarkFramesOnPhone() async throws {
        for phone in Phone.all {
            let ordinary = try await measure(slot: .easy, boss: .unluckyLucky, phone: phone)
            for boss in [BossModifier.unluckyLucky, .accountant, .heavyLifter] {
                let encounter = try await measure(slot: .boss, boss: boss, phone: phone)
                XCTAssertEqual(encounter.book.minY, ordinary.book.minY, accuracy: 0.5,
                               "\(boss.name) cannot push the Book upward into the HUD.")
                XCTAssertEqual(encounter.book.height, ordinary.book.height, accuracy: 0.5,
                               "An encounter must fit the existing Book, not enlarge it.")
                XCTAssertEqual(encounter.bookmarks.minY, ordinary.bookmarks.minY, accuracy: 0.5,
                               "The Bookmark row must keep its normal desk position.")
                XCTAssertGreaterThanOrEqual(encounter.bookmarks.minY, phone.top)
                XCTAssertLessThanOrEqual(encounter.book.maxY, phone.size.height - phone.bottom - 8 + 0.5)
                XCTAssertTrue(encounter.text.contains(normalize("Boss encounter")))
                XCTAssertTrue(encounter.text.contains(normalize(boss.name)), "Boss identity must remain visible.")
                XCTAssertTrue(encounter.text.contains(normalize("Play Puzzle")), "The play action must remain visible.")
            }
        }
    }

    func testBlankBossBandPreservesTheExactPreviousBoardHeightBudget() throws {
        for width: CGFloat in [280, 300, 327, 365] {
            for type in [DynamicTypeSize.large, .accessibility5] {
                let oldReservation = try render(BossStamp(boss: .deadline, censored: nil).opacity(0),
                                                 width: width, type: type)
                let emptyReservation = try render(BossStampReservation(), width: width, type: type)
                XCTAssertEqual(emptyReservation.size.height, oldReservation.size.height, accuracy: 0.01,
                               "Removing the placeholder's semantics must not move the gameplay grid.")
                XCTAssertTrue(try recognize(emptyReservation).isEmpty,
                              "The reserved band must not print an adversary or rule.")
            }
        }
    }

    func testEveryKnownRunPlanAnnouncesTheCommittedBossNameAndFullPower() {
        for slot in PuzzleSlot.allCases {
            for boss in BossModifier.allCases {
                let announcement = RunRouteStrip(currentSlot: slot, boss: boss).accessibilitySummary
                XCTAssertTrue(announcement.contains(boss.name))
                XCTAssertTrue(announcement.contains(boss.text),
                              "The ordinary-puzzle preview must expose the same known power as the Boss briefing.")
            }
        }
        let unknown = RunRouteStrip(currentSlot: .easy, boss: nil).accessibilitySummary
        XCTAssertTrue(unknown.contains("not yet known"))
        XCTAssertFalse(unknown.contains(BossModifier.deadline.name), "Missing metadata cannot invent a Boss.")
    }

    private struct Phone {
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat

        static let all = [
            Phone(size: CGSize(width: 402, height: 874), top: 62, bottom: 34),
            Phone(size: CGSize(width: 375, height: 812), top: 44, bottom: 34)
        ]
    }

    private struct Measurement {
        let book: CGRect
        let bookmarks: CGRect
        let text: String
        let image: UIImage
    }

    private func measure(slot: PuzzleSlot, boss: BossModifier, phone: Phone) async throws -> Measurement {
        var run = RunState(seed: "briefing-height-regression")
        run.slot = slot
        run.pendingBoss = boss
        let model = GameModel(frozen: Game(run: run), page: .briefing)
        let flipper = PageFlipper()
        let ready = expectation(description: "Briefing frames \(slot)-\(boss.rawValue)-\(phone.size.width)")
        var frames = [String: CGRect]()
        var reported = false
        let content = VStack(spacing: 0) {
            BookmarkRow(model: model, onTapBuff: { _ in })
                .background(frameProbe("bookmarks"))
                .padding(.horizontal, 26).padding(.top, 4)
            BookView(flipper: flipper) {
                PuzzleBriefingView(model: model)
            }
            .background(frameProbe("book"))
            .padding(.leading, 8).padding(.trailing, 10)
            .padding(.top, -(BookmarkRow.tuck - 4))
        }
        .padding(.bottom, 8)
        .padding(.top, phone.top).padding(.bottom, phone.bottom)
        .frame(width: phone.size.width, height: phone.size.height)
        .environment(flipper)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.levelPalette, .forDisplay(slot: slot))
        .environment(\.scenePhase, .inactive)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.colorScheme, .dark)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        .onPreferenceChange(BriefingFrames.self) { latest in
            frames = latest
            if !reported, latest["book"] != nil, latest["bookmarks"] != nil {
                reported = true
                ready.fulfill()
            }
        }
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = host
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready], timeout: 5)
        if phone.size.width >= 768, slot != .boss {
            // The ticket's real arrival is task-driven. Frame preferences can
            // precede that first state update; capture its settled visible state.
            try await Task.sleep(for: .milliseconds(550))
        }
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: phone.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "briefing-\(Int(phone.size.width))-\(slot.rawValue)-\(boss.rawValue)"
        attachment.lifetime = .keepAlways
        add(attachment)
        return Measurement(book: try XCTUnwrap(frames["book"]),
                           bookmarks: try XCTUnwrap(frames["bookmarks"]),
                           text: try recognize(image), image: image)
    }

    private func frameProbe(_ key: String) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: BriefingFrames.self, value: [key: proxy.frame(in: .global)])
        }
    }

    private struct BriefingFrames: PreferenceKey {
        static var defaultValue: [String: CGRect] = [:]
        static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
            value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
        }
    }

    private func render<V: View>(_ content: V, width: CGFloat, type: DynamicTypeSize) throws -> UIImage {
        let renderer = ImageRenderer(content: content.frame(width: width)
            .environment(\.dynamicTypeSize, type))
        renderer.scale = 3
        return try XCTUnwrap(renderer.uiImage)
    }

    private func recognize(_ image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return normalize((request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " "))
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

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
