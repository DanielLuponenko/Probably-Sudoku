import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The shared tactile vocabulary. Every entry checks the one user preference
/// before touching either Core Haptics or its no-hardware fallback.
@MainActor
enum Haptics {
    private static var sceneActive = true
    private static var throttle = FeedbackThrottle()
    private static var impactGenerators: [Int: UIImpactFeedbackGenerator] = [:]

    static func prepare() {
        guard isEnabled else { return }
        HapticBox.shared.prepare()
        for style: UIImpactFeedbackGenerator.FeedbackStyle in [.light, .medium, .soft, .rigid] {
            generator(for: style).prepare()
        }
    }

    static func setSceneActive(_ active: Bool) {
        sceneActive = active
        HapticBox.shared.setActive(active && AppPreferences.hapticsEnabled)
        if active { prepare() }
        else { throttle.reset(); impactGenerators.removeAll() }
    }

    static func preferencesChanged() {
        HapticBox.shared.setActive(isEnabled)
        if isEnabled { prepare() }
        else { throttle.reset(); impactGenerators.removeAll() }
    }

    static func menuPress() {
        GameAudio.shared.play(.menuTap)
        transient("menu", intensity: 0.42, sharpness: 0.48, fallback: .light)
    }

    static func menuOpen() {
        GameAudio.shared.play(.menuTap)
        transient("menu", intensity: 0.32, sharpness: 0.36, fallback: .light)
    }

    static func lift() {
        transient("lift", intensity: 0.34, sharpness: 0.12, fallback: .soft)
    }

    static func pageTurn() {
        GameAudio.shared.play(.paperTurn)
        guard allows("page", interval: 0.12) else { return }
        HapticBox.shared.play([
            .continuous(at: 0, duration: 0.075, intensity: 0.19, sharpness: 0.08),
            .transient(at: 0.045, intensity: 0.29, sharpness: 0.16),
        ]) { impact(.soft, intensity: 0.38) }
    }

    static func tossed() {
        guard allows("toss", interval: 0.12) else { return }
        HapticBox.shared.play([
            .continuous(at: 0, duration: 0.06, intensity: 0.22, sharpness: 0.12),
            .transient(at: 0.045, intensity: 0.30, sharpness: 0.34),
        ]) { impact(.soft, intensity: 0.40) }
    }

    static func error() {
        guard allows("error", interval: 0.15) else { return }
        HapticBox.shared.play([
            .transient(at: 0, intensity: 0.37, sharpness: 0.12),
            .transient(at: 0.075, intensity: 0.24, sharpness: 0.08),
        ]) { impact(.medium, intensity: 0.40) }
    }

    /// A score scales its weight modestly, so a large placement feels more
    /// decisive without becoming an accessibility obstacle or a notification.
    static func scored(points: Int) {
        guard allows("score", interval: 0.055) else { return }
        let weight = min(0.72, 0.28 + Float(max(points, 0)) / 700)
        HapticBox.shared.play([
            .transient(at: 0, intensity: weight, sharpness: 0.28 + weight * 0.24),
            .continuous(at: 0.005, duration: 0.045,
                        intensity: weight * 0.22, sharpness: 0.12),
        ]) {
            impact(.light, intensity: CGFloat(weight))
        }
    }

    /// A line, box, or full-board clear is one event even when a placement
    /// clears several units. This avoids turning a high-value play into a
    /// burst of unrelated taps.
    static func cleared(units: Int, isFullClear: Bool) {
        guard allows("clear", interval: 0.18) else { return }
        let count = max(1, min(units, 3))
        let step: TimeInterval = 0.055
        var events: [HapticBox.Event] = [
            .continuous(at: 0, duration: TimeInterval(count) * step + 0.10,
                        intensity: isFullClear ? 0.30 : 0.20,
                        sharpness: 0.14),
        ]
        for index in 0..<count {
            events.append(.transient(at: TimeInterval(index) * step,
                                     intensity: 0.30 + Float(index) * 0.12,
                                     sharpness: 0.34 + Float(index) * 0.10))
        }
        if isFullClear {
            events.append(.transient(at: TimeInterval(count) * step,
                                     intensity: 0.72, sharpness: 0.58))
        }
        HapticBox.shared.play(events) {
            impact(isFullClear ? .rigid : .medium,
                   intensity: isFullClear ? 0.70 : 0.50)
        }
    }

    private static var isEnabled: Bool { sceneActive && AppPreferences.hapticsEnabled }

    private static func allows(_ key: String, interval: TimeInterval) -> Bool {
        guard isEnabled,
              throttle.allows(key, at: ProcessInfo.processInfo.systemUptime, interval: interval) else { return false }
        // AppStorage writes synchronously, but a view's onChange is deferred.
        // The tap that re-enables haptics should already get its feedback.
        HapticBox.shared.setActive(true)
        return true
    }

    private static func transient(_ key: String, intensity: Float, sharpness: Float,
                                  fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard allows(key, interval: 0.055) else { return }
        HapticBox.shared.play([.transient(at: 0, intensity: intensity, sharpness: sharpness)]) {
            impact(fallback, intensity: CGFloat(intensity))
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                               intensity: CGFloat) {
        #if canImport(UIKit)
        let generator = generator(for: style)
        generator.impactOccurred(intensity: intensity)
        // Prepare the retained generator for the next interaction, not the
        // impact that has already happened.
        generator.prepare()
        #endif
    }

    private static func generator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let existing = impactGenerators[style.rawValue] { return existing }
        let created = UIImpactFeedbackGenerator(style: style)
        impactGenerators[style.rawValue] = created
        return created
    }
}
