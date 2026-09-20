import SwiftUI
import UIKit

/// Reads the existing active-play clock. This view owns no timer and never
/// writes a game, so frozen pages and accessibility inspection cannot tick it.
struct TikTakCountdownValue: Equatable {
    enum Urgency: Equatable { case ordinary, warning, urgent, finalSeconds, expired }
    let seconds: Int
    let isPaused: Bool

    init(remaining: Double, isPaused: Bool) {
        seconds = remaining.isFinite ? Int(min(240, max(0, remaining)).rounded(.up)) : 240
        self.isPaused = isPaused && seconds > 0
    }

    var text: String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    var urgency: Urgency {
        if seconds == 0 { return .expired }
        if seconds <= 10 { return .finalSeconds }
        if seconds <= 30 { return .urgent }
        if seconds <= 60 { return .warning }
        return .ordinary
    }
    var caption: String {
        if isPaused { return "Time left · Paused" }
        switch urgency {
        case .ordinary: return "Time left"
        case .warning: return "Time left · Low"
        case .urgent: return "Time left · Urgent"
        case .finalSeconds: return "Time left · Final 10"
        case .expired: return "Time's up"
        }
    }
    var accessibilityLabel: String {
        let minutes = seconds / 60
        let remainder = seconds % 60
        return "Time left, \(minutes) \(minutes == 1 ? "minute" : "minutes"), \(remainder) \(remainder == 1 ? "second" : "seconds").\(isPaused ? " Paused." : "")"
    }

    /// A resumed or first-rendered value is not a threshold crossing. A late
    /// display update announces only the most urgent crossed boundary.
    static func warningCrossed(from old: Int, to new: Int) -> Int? {
        guard new < old else { return nil }
        return [0, 10, 30, 60].first { old > $0 && new <= $0 }
    }
}

struct TikTakCountdown: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let value: TikTakCountdownValue
    var compact = false
    @State private var pulse = 0

    private var ink: Color {
        switch value.urgency {
        case .ordinary: GameplaySurface.ink
        case .warning: Paper.coinRim
        case .urgent, .finalSeconds, .expired: Paper.redPencil
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value.text)
                .font(Print.numeral(compact ? 32 : 36, weight: .semibold))
                .monospacedDigit()
                .tracking(0.3)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.identity)
                .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
                    content.scaleEffect(scale, anchor: .trailing)
                } keyframes: { _ in
                    CubicKeyframe(1.045, duration: 0.12)
                    CubicKeyframe(1, duration: 0.20)
                }
            Text(value.caption)
                .font(Print.caption(10))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.accessibilityLabel)
        .accessibilityIdentifier("boss.tikTak.countdown")
        .onChange(of: value.seconds) { old, new in
            guard presented, scenePhase == .active, !value.isPaused,
                  let crossed = TikTakCountdownValue.warningCrossed(from: old, to: new) else { return }
            if !reduceMotion, crossed == 30 || crossed == 10 { pulse += 1 }
            if UIAccessibility.isVoiceOverRunning {
                UIAccessibility.post(notification: .announcement,
                                     argument: crossed == 0 ? "Time's up" : "\(crossed) seconds remaining")
            }
        }
    }
}
