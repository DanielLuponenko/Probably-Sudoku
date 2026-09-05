import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BriefingBoundsTests: XCTestCase {
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
                           text: try recognize(image))
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

    private func normalize(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
