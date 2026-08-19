import SwiftUI

/// A page of a real book turns about its spine. The outgoing page swings away,
/// picking up a shadow as it lifts; the incoming one is already lying flat
/// underneath. Short and physical, not cinematic.
struct PageTurn: Transition {
    /// Turning forward lifts the right-hand page towards the spine on the left.
    var forward: Bool = true

    func body(content: Content, phase: TransitionPhase) -> some View {
        let angle: Double = switch phase {
        case .willAppear: forward ? -95 : 95
        case .identity: 0
        case .didDisappear: forward ? 88 : -88
        }

        return content
            .rotation3DEffect(
                .degrees(angle),
                axis: (x: 0, y: 1, z: 0),
                anchor: forward ? .leading : .trailing,
                perspective: 0.55
            )
            .overlay {
                // The paper darkens as it leaves the flat, which is what sells
                // the fold more than the rotation does.
                Rectangle()
                    .fill(.black.opacity(min(0.5, abs(angle) / 190)))
                    .allowsHitTesting(false)
            }
            .opacity(phase == .didDisappear ? 0.25 : 1)
    }
}

extension AnyTransition {
    static func pageTurn(forward: Bool = true) -> AnyTransition {
        .asymmetric(
            insertion: AnyTransition(PageTurn(forward: forward)),
            removal: AnyTransition(PageTurn(forward: forward))
        )
    }
}

extension View {
    /// Honours Reduce Motion by swapping the fold for a plain cross-fade.
    func pageTurnTransition(forward: Bool, reduceMotion: Bool) -> some View {
        transition(reduceMotion ? .opacity : .pageTurn(forward: forward))
    }
}
