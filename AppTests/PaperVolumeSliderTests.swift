import XCTest
import SwiftUI
import UIKit
import Observation
@testable import ProbablySudoku

@MainActor
final class PaperVolumeSliderTests: XCTestCase {
    func testTrackEndpointsClampingSteppingAndRightToLeftMapping() {
        let track = CGRect(x: 14, y: 17, width: 200, height: 10)
        XCTAssertEqual(PaperVolumeValue.seek(x: -100, in: track, rightToLeft: false), 0)
        XCTAssertEqual(PaperVolumeValue.seek(x: 500, in: track, rightToLeft: false), 1)
        XCTAssertEqual(PaperVolumeValue.seek(x: 14, in: track, rightToLeft: true), 1)
        XCTAssertEqual(PaperVolumeValue.seek(x: 214, in: track, rightToLeft: true), 0)
        XCTAssertEqual(PaperVolumeValue.seek(x: 104, in: track, rightToLeft: false), 0.45)
        XCTAssertNil(PaperVolumeValue.seek(x: .nan, in: track, rightToLeft: false))
        XCTAssertNil(PaperVolumeValue.seek(x: 10, in: .zero, rightToLeft: false))
        XCTAssertEqual(PaperVolumeValue.label(.nan), "Muted")
        XCTAssertEqual(PaperVolumeValue.label(0.001), "<1%")
        XCTAssertEqual(PaperVolumeValue.label(2), "100%")
        XCTAssertEqual(PaperVolumeValue.adjusted(0.33, by: 1), 0.38)
    }

    func testTapSeeksAndVoiceOverChangesFivePercentWithoutDuplicateEndpointEvents() {
        let slider = PaperVolumeUIKitSlider(frame: CGRect(x: 0, y: 0, width: 228, height: 44))
        let events = ValueEvents()
        slider.addTarget(events, action: #selector(ValueEvents.changed(_:)), for: .valueChanged)
        slider.setDisplayedValue(0.8)
        XCTAssertTrue(slider.accessibilityTraits.contains(.adjustable))
        XCTAssertEqual(slider.intrinsicContentSize.height, 44)
        let tap = Tap()
        tap.reportedState = .ended
        tap.point = CGPoint(x: 114, y: 22)
        slider.handleTap(tap)
        XCTAssertEqual(slider.value, 0.5)
        XCTAssertEqual(slider.accessibilityValue, "50%")
        slider.accessibilityIncrement()
        XCTAssertEqual(slider.value, 0.55, accuracy: 0.0001)
        slider.accessibilityDecrement()
        XCTAssertEqual(slider.value, 0.5, accuracy: 0.0001)
        tap.point.x = -100
        slider.handleTap(tap)
        XCTAssertEqual(slider.accessibilityValue, "Muted")
        let mutedCount = events.values.count
        slider.accessibilityDecrement()
        XCTAssertEqual(events.values.count, mutedCount)
        tap.point.x = 500
        slider.handleTap(tap)
        let fullCount = events.values.count
        slider.accessibilityIncrement()
        XCTAssertEqual(events.values.count, fullCount)
        slider.isEnabled = false
        slider.accessibilityDecrement()
        tap.point.x = 14
        slider.handleTap(tap)
        XCTAssertEqual(slider.value, 1)
        XCTAssertEqual(events.values.count, fullCount)
    }

    func testSeekingAtDisplayedThumbCenterNeverJumpsInEitherLayoutDirection() {
        let slider = PaperVolumeUIKitSlider(frame: CGRect(x: 0, y: 0, width: 228, height: 44))
        for direction in [UISemanticContentAttribute.forceLeftToRight, .forceRightToLeft] {
            slider.semanticContentAttribute = direction
            for value in [0.0, 0.25, 0.5, 0.8, 1] {
                slider.setDisplayedValue(value)
                let thumb = slider.thumbRect(forBounds: slider.bounds,
                    trackRect: slider.trackRect(forBounds: slider.bounds), value: slider.value)
                let tap = Tap()
                tap.reportedState = .ended
                tap.point = CGPoint(x: thumb.midX, y: thumb.midY)
                slider.handleTap(tap)
                XCTAssertEqual(Double(slider.value), value, accuracy: 0.0001)
            }
        }
    }

    func testHorizontalDragUpdatesContinuouslyAndVerticalStartNeverChangesVolume() {
        let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 300, height: 500))
        let slider = PaperVolumeUIKitSlider(frame: CGRect(x: 0, y: 0, width: 228, height: 44))
        scroll.addSubview(slider)
        slider.setDisplayedValue(0.4)
        let events = ValueEvents()
        slider.addTarget(events, action: #selector(ValueEvents.changed(_:)), for: .valueChanged)
        XCTAssertTrue(slider.gestureRecognizer(slider.volumePan,
                            shouldBeRequiredToFailBy: scroll.panGestureRecognizer))
        let vertical = Pan()
        vertical.speed = CGPoint(x: 20, y: 160)
        vertical.point = CGPoint(x: 210, y: 22)
        XCTAssertFalse(slider.gestureRecognizerShouldBegin(vertical))
        for state in [UIGestureRecognizer.State.began, .changed, .ended] {
            vertical.reportedState = state
            slider.handlePan(vertical)
        }
        XCTAssertEqual(slider.value, 0.4)
        XCTAssertTrue(events.values.isEmpty)

        let horizontal = Pan()
        horizontal.speed = CGPoint(x: 180, y: 15)
        XCTAssertTrue(slider.gestureRecognizerShouldBegin(horizontal))
        horizontal.reportedState = .began
        horizontal.point = CGPoint(x: 114, y: 22)
        slider.handlePan(horizontal)
        XCTAssertEqual(slider.value, 0.5)
        horizontal.reportedState = .changed
        horizontal.point = CGPoint(x: 174, y: 80)
        slider.handlePan(horizontal)
        XCTAssertEqual(slider.value, 0.8)
        horizontal.reportedState = .cancelled
        slider.handlePan(horizontal)
        horizontal.reportedState = .changed
        horizontal.point.x = 14
        slider.handlePan(horizontal)
        XCTAssertEqual(slider.value, 0.8, "A cancelled drag cannot make later delayed writes")
        XCTAssertEqual(events.values, [0.5, 0.8])
    }

    func testMountedControlReadsExternalChangesAndWritesOnlyItsCurrentPersistedBinding() async throws {
        let suite = "NumberClub.PaperVolumeSliderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(0.45, forKey: AppPreferences.Key.musicVolume)
        defaults.set(0.7, forKey: AppPreferences.Key.effectsVolume)
        let state = MountedSliderState()
        let root = MountedSlider(state: state).defaultAppStorage(defaults)
        try await withHost(root, size: CGSize(width: 300, height: 100)) { window in
            let slider = try XCTUnwrap(self.findSlider(in: window))
            XCTAssertEqual(slider.value, 0.45, accuracy: 0.0001)
            XCTAssertEqual(slider.accessibilityLabel, "Music volume")
            slider.accessibilityIncrement()
            await self.settle(window)
            XCTAssertEqual(defaults.double(forKey: AppPreferences.Key.musicVolume), 0.5, accuracy: 0.0001)
            XCTAssertEqual(AppPreferences.audioMix(in: defaults).music, 0.5)

            defaults.set(0.25, forKey: AppPreferences.Key.musicVolume)
            await self.settle(window)
            XCTAssertEqual(slider.value, 0.25, accuracy: 0.0001)
            XCTAssertEqual(slider.accessibilityValue, "25%")

            state.usesEffects = true
            await self.settle(window)
            XCTAssertTrue(slider === self.findSlider(in: window), "A new binding must refresh the existing control")
            XCTAssertEqual(slider.value, 0.7, accuracy: 0.0001)
            XCTAssertEqual(slider.accessibilityLabel, "Sound effects volume")
            slider.accessibilityDecrement()
            await self.settle(window)
            XCTAssertEqual(defaults.double(forKey: AppPreferences.Key.effectsVolume), 0.65, accuracy: 0.0001)
            XCTAssertEqual(defaults.double(forKey: AppPreferences.Key.musicVolume), 0.25, accuracy: 0.0001)
            XCTAssertNil(defaults.object(forKey: AppPreferences.Key.masterVolume))
        }
        let restored = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(AppPreferences.audioMix(in: restored), .init(master: 0.8, music: 0.25, effects: 0.65))
    }

    func testCustomTrackAndThumbRemainVisibleAtMuteAndEnlargedText() async throws {
        for type in [DynamicTypeSize.large, .accessibility5] {
            let root = PaperVolumeSlider(title: "Sound effects", value: .constant(0))
                .padding(16)
                .environment(\.dynamicTypeSize, type)
                .environment(\.cosmeticTheme, .standard)
                .background(Paper.page)
            try await withHost(root, size: CGSize(width: 320, height: type == .large ? 120 : 240)) { window in
                let slider = try XCTUnwrap(self.findSlider(in: window))
                XCTAssertGreaterThanOrEqual(slider.bounds.height, 44)
                XCTAssertNotNil(slider.minimumTrackImage(for: .normal))
                XCTAssertNotNil(slider.maximumTrackImage(for: .normal))
                XCTAssertNotNil(slider.thumbImage(for: .normal))
                XCTAssertEqual(slider.accessibilityValue, "Muted")
                let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
                    window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
                }
                let attachment = XCTAttachment(image: image)
                attachment.name = "paper-volume-muted-\(type)"
                attachment.lifetime = .keepAlways
                self.add(attachment)
            }
        }
    }

    private func findSlider(in view: UIView) -> PaperVolumeUIKitSlider? {
        if let slider = view as? PaperVolumeUIKitSlider { return slider }
        return view.subviews.lazy.compactMap { self.findSlider(in: $0) }.first
    }

    private func settle(_ window: UIWindow) async {
        window.layoutIfNeeded()
        try? await Task.sleep(for: .milliseconds(150))
        window.layoutIfNeeded()
    }

    private func withHost<Content: View>(_ root: Content, size: CGSize,
                                        body: (UIWindow) async throws -> Void) async throws {
        let controller = UIHostingController(rootView: root)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = controller
        defer { window.isHidden = true; window.rootViewController = nil; previous?.makeKey() }
        window.makeKeyAndVisible()
        await settle(window)
        try await body(window)
    }
}

@MainActor @Observable
private final class MountedSliderState { var usesEffects = false }

private struct MountedSlider: View {
    let state: MountedSliderState
    @AppStorage(AppPreferences.Key.musicVolume) private var music = 0.45
    @AppStorage(AppPreferences.Key.effectsVolume) private var effects = 0.7

    var body: some View {
        PaperVolumeSlider(title: state.usesEffects ? "Sound effects" : "Music",
                          value: state.usesEffects ? $effects : $music)
    }
}

@MainActor
private final class ValueEvents: NSObject {
    var values: [Float] = []
    @objc func changed(_ slider: UISlider) { values.append(slider.value) }
}

private final class Tap: UITapGestureRecognizer {
    var reportedState: UIGestureRecognizer.State = .possible
    var point = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { reportedState }
        set { reportedState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { point }
}

private final class Pan: UIPanGestureRecognizer {
    var reportedState: UIGestureRecognizer.State = .possible
    var point = CGPoint.zero
    var speed = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { reportedState }
        set { reportedState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { point }
    override func velocity(in view: UIView?) -> CGPoint { speed }
}
