import SwiftUI

/// A pinned corner catches the paper, swings twice, then releases it to
/// gravity. Values are presentation only; the model validates the claim.
struct ClippingDeparture: Equatable {
    let angle: Double
    let fall: CGFloat
    let opacity: Double

    static func at(_ progress: Double) -> Self {
        let p = min(1, max(0, progress))
        let release = 0.58
        if p < release {
            let swing = sin(p / release * .pi * 2) * -14 * (1 - p * 0.65)
            return Self(angle: swing, fall: 0, opacity: 1)
        }
        let t = (p - release) / (1 - release)
        return Self(angle: -24 * t * t, fall: 1.6 * t * t,
                    opacity: 1 - max(0, (t - 0.55) / 0.45))
    }
}

struct ClippingDepartureModifier: ViewModifier {
    let isTaking: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content.opacity(isTaking ? 0 : 1)
                .animation(.easeOut(duration: 0.12), value: isTaking)
        } else {
            content.keyframeAnimator(initialValue: 0.0, trigger: isTaking) { paper, progress in
                let pose = ClippingDeparture.at(progress)
                paper.visualEffect { element, geometry in
                    element
                        .rotationEffect(.degrees(pose.angle), anchor: UnitPoint(x: 0.89, y: 0.015))
                        .offset(y: geometry.size.height * pose.fall)
                        .opacity(pose.opacity)
                }
            } keyframes: { _ in
                KeyframeTrack(\.self) {
                    if isTaking { LinearKeyframe(1, duration: 0.80) }
                    else { MoveKeyframe(0) }
                }
            }
        }
    }
}
