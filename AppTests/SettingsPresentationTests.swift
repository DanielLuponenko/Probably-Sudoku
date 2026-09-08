import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class SettingsPresentationTests: XCTestCase {
    func testSettingsIndexHasOneLocalAchievementDestinationAndPreservesLearningEntries() {
        XCTAssertEqual(SettingsDestination.allCases, [.guide, .practice, .achievements, .privacy])
        XCTAssertEqual(Set(SettingsDestination.allCases.map(\.accessibilityID)).count, 4)
        XCTAssertEqual(SettingsDestination.guide.accessibilityID, "learning-how-to-play")
        XCTAssertEqual(SettingsDestination.practice.accessibilityID, "learning-replay-tutorial")
        XCTAssertEqual(SettingsDestination.achievements.title, "Achievements")
    }

    func testEverySettingsNavigationTargetMeetsTouchSizeAndWrapsLargeText() throws {
        for size in [DynamicTypeSize.large, .accessibility3] {
            for destination in SettingsDestination.allCases {
                let renderer = ImageRenderer(content:
                    SettingsNavigationRow(destination: destination, action: { })
                        .frame(width: 230)
                        .environment(\.dynamicTypeSize, size)
                        .background(Paper.page)
                )
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertEqual(image.size.width, 230, accuracy: 0.5)
                XCTAssertGreaterThanOrEqual(image.size.height, 44)
                XCTAssertLessThan(image.size.height, 320,
                                  "A settings row should wrap, not grow into an unbounded page")
                if size == .large {
                    XCTAssertTrue(try text(in: image).contains(destination.title.lowercased()))
                }
                attach(image, name: "settings-row-\(destination.rawValue)-\(size)")
            }
        }
    }

    func testSettingsContentHasThreeAudioSlidersAndCompactNavigation() throws {
        let renderer = ImageRenderer(content:
            SettingsCommonContent()
                .frame(width: 320)
                .environment(\.colorScheme, .light)
                .background(Paper.page)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let copy = try text(in: image)
        for label in ["master", "music", "sound effects", "haptics", "background motion",
                      "how to play", "replay tutorial", "achievements", "privacy & support"] {
            XCTAssertTrue(copy.contains(label), "Missing Settings entry: \(label)")
        }
        XCTAssertFalse(copy.contains("leaderboards"), "Game Center detail belongs inside Achievements")
        XCTAssertFalse(copy.contains("same seed"), "Book statistics should not crowd app preferences")
        attach(image, name: "settings-common-index")
    }

    func testBookstoreSettingsHasNativeScrollRangeAndReachesPrivacy() async throws {
        for (name, viewport, presentation) in settingsScrollSizes {
            var didClose = false
            try await assertSettingsScroll(
                AppSettingsSlip(onClose: { didClose = true }),
                viewport: viewport, presentation: presentation,
                expectedBottom: ["privacysupport"], name: "app-settings-\(name)"
            )
            XCTAssertFalse(didClose, "Scrolling preferences must not dismiss Settings.")
        }
    }

    func testActiveBookSettingsHasNativeScrollRangeAndReachesAbandon() async throws {
        let model = GameModel(frozen: Game(seed: "settings-native-scroll"), page: .puzzle)
        for (name, viewport, presentation) in settingsScrollSizes {
            var didClose = false
            var didAbandon = false
            try await assertSettingsScroll(
                SettingsSlip(model: model, onAbandon: { didAbandon = true }, onClose: { didClose = true }),
                viewport: viewport, presentation: presentation,
                expectedBottom: ["privacysupport", "abandonbook"], name: "book-settings-\(name)"
            )
            XCTAssertFalse(didClose, "Scrolling the Book's preferences must not dismiss Settings.")
            XCTAssertFalse(didAbandon, "Reaching the Abandon control must not activate it.")
        }
    }

    func testAchievementDestinationHasSettingsReturnAndDoesNotNeedAuthentication() throws {
        let profile = PlayerProfileStore(profile: PlayerProfile())
        let before = profile.profile
        let renderer = ImageRenderer(content:
            AchievementsPageView(backLabel: "Back to Settings", showsGameCenter: true, onBack: { })
                .frame(width: 320, height: 620)
                .padding(12)
                .environment(profile)
                .background(Paper.page)
        )
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.uiImage)
        let copy = try text(in: image)
        XCTAssertTrue(copy.contains("achievements"))
        XCTAssertTrue(copy.contains("back to settings"))
        XCTAssertFalse(copy.contains("back to the book"))
        XCTAssertEqual(profile.profile, before, "Viewing the offline collection cannot award or erase progress")
        attach(image, name: "settings-achievement-destination")
    }

    private func text(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ").lowercased()
    }

    private var settingsScrollSizes: [(String, CGSize, CGSize)] {
        [
            ("phone", CGSize(width: 375, height: 667), CGSize(width: 375, height: 667)),
            ("ipad", CGSize(width: 834, height: 1210), CGSize(width: 834, height: 1210))
        ]
    }

    private func assertSettingsScroll<Content: View>(
        _ content: Content, viewport: CGSize, presentation: CGSize,
        expectedBottom: [String], name: String
    ) async throws {
        let host = UIHostingController(rootView: content
            .frame(width: presentation.width, height: presentation.height)
            .frame(width: viewport.width, height: viewport.height)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
            .transaction { $0.disablesAnimations = true })
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: viewport)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        let settled = expectation(description: "Actual Settings completed native layout")
        DispatchQueue.main.async {
            window.layoutIfNeeded()
            host.view.layoutIfNeeded()
            DispatchQueue.main.async {
                window.layoutIfNeeded()
                host.view.layoutIfNeeded()
                settled.fulfill()
            }
        }
        await fulfillment(of: [settled], timeout: 3)
        // In-Book Settings fades in after onAppear. Its native scroll view
        // can be laid out while an ancestor still has zero presentation alpha;
        // allow that existing 0.12-second arrival to finish before inspecting
        // which scroll container is actually visible.
        try await Task.sleep(for: .milliseconds(250))
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()

        let candidates = nativeScrollViews(in: host.view).filter { scroll in
            guard scroll.window === window, !scroll.bounds.isEmpty else { return false }
            var ancestor: UIView? = scroll
            while let view = ancestor {
                if view.isHidden || view.alpha < 0.01 { return false }
                ancestor = view.superview
            }
            return scroll.convert(scroll.bounds, to: window).intersects(window.bounds)
        }
        let scroll = try XCTUnwrap(candidates.max { $0.bounds.height < $1.bounds.height },
                                  "\(name): the overflowing Settings article must select a visible native ScrollView.")
        XCTAssertTrue(scroll.isScrollEnabled, name)
        XCTAssertTrue(scroll.panGestureRecognizer.isEnabled, name)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height + 1,
                             "\(name): content size must include the preferences below the initial viewport.")

        func snapshot() -> UIImage {
            UIGraphicsImageRenderer(size: viewport).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
        }
        let before = snapshot()
        attach(before, name: "\(name)-before-scroll")
        XCTAssertTrue(try text(in: before).contains("close"), "Close must be visible before scrolling.")

        let bottomOffset = max(-scroll.adjustedContentInset.top,
                               scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: bottomOffset), animated: false)
        window.layoutIfNeeded()
        host.view.layoutIfNeeded()
        XCTAssertEqual(scroll.contentOffset.y, bottomOffset, accuracy: 1, name)
        XCTAssertGreaterThan(scroll.contentOffset.y, 0, "\(name): native scrolling must move the article.")
        let after = snapshot()
        attach(after, name: "\(name)-after-scroll")
        let bottomCopy = try text(in: after).filter { $0.isLetter || $0.isNumber }
        for phrase in expectedBottom {
            XCTAssertTrue(bottomCopy.contains(phrase), "\(name): bottom Settings content '\(phrase)' remains unreachable: \(bottomCopy)")
        }
        XCTAssertTrue(bottomCopy.contains("close"), "Close must remain visible outside the scrolling article.")
    }

    private func nativeScrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { nativeScrollViews(in: $0) }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
