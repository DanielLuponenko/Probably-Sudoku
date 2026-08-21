import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// The shared tactile vocabulary. Every entry checks the one user preference
/// before touching either Core Haptics or its no-hardware fallback.
@MainActor
enum Haptics {
    static func prepare() {
        guard isEnabled else { return }
        HapticBox.shared.prepare()
    }

    static func menuPress() { transient(intensity: 0.62, sharpness: 0.30, fallback: .medium) }
    static func menuOpen() { transient(intensity: 0.42, sharpness: 0.42, fallback: .light) }
    static func lift() { transient(intensity: 0.52, sharpness: 0.10, fallback: .soft) }
    static func pageTurn() { transient(intensity: 0.58, sharpness: 0.12, fallback: .soft) }

    /// A score scales its weight modestly, so a large placement feels more
    /// decisive without becoming an accessibility obstacle or a notification.
    static func scored(points: Int) {
        guard isEnabled else { return }
        let weight = min(1, 0.32 + Float(max(points, 0)) / 420)
        HapticBox.shared.play([
            .transient(at: 0, intensity: weight, sharpness: 0.28 + weight * 0.24),
            .continuous(at: 0.005, duration: 0.09,
                        intensity: weight * 0.38, sharpness: 0.12),
        ]) {
            impact(.light, intensity: CGFloat(weight))
        }
    }

    /// A line, box, or full-board clear is one event even when a placement
    /// clears several units. This avoids turning a high-value play into a
    /// burst of unrelated taps.
    static func cleared(units: Int, isFullClear: Bool) {
        guard isEnabled else { return }
        let count = max(1, min(units, 3))
        let step: TimeInterval = 0.055
        var events: [HapticBox.Event] = [
            .continuous(at: 0, duration: TimeInterval(count) * step + 0.10,
                        intensity: isFullClear ? 0.58 : 0.36,
                        sharpness: 0.14),
        ]
        for index in 0..<count {
            events.append(.transient(at: TimeInterval(index) * step,
                                     intensity: 0.36 + Float(index) * 0.18,
                                     sharpness: 0.34 + Float(index) * 0.10))
        }
        if isFullClear {
            events.append(.transient(at: TimeInterval(count) * step,
                                     intensity: 0.95, sharpness: 0.62))
        }
        HapticBox.shared.play(events) {
            impact(isFullClear ? .rigid : .medium,
                   intensity: isFullClear ? 0.9 : 0.65)
        }
    }

    private static var isEnabled: Bool { AppPreferences.hapticsEnabled }

    private static func transient(intensity: Float, sharpness: Float,
                                  fallback: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard isEnabled else { return }
        HapticBox.shared.play([.transient(at: 0, intensity: intensity, sharpness: sharpness)]) {
            impact(fallback, intensity: CGFloat(intensity))
        }
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                               intensity: CGFloat) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
        #endif
    }
}
