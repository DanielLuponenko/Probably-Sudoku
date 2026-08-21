import SwiftUI

/// A page turn is one continuous movement, not a rotation with a cut in the
/// middle. The sheet that is leaving keeps its old contents and bends away,
/// while the page it uncovers is already live underneath.
///
/// Freezing the outgoing page costs nothing: `Game` is a value type all the way
/// down, so the snapshot is a copy rather than a render.
@Observable
final class PageFlipper {
    private(set) var progress: Double = 0
    /// The page as it was, kept alive only for the length of the turn.
    private(set) var outgoing: GameModel?
    private(set) var isFlipping = false

    /// Long enough to read as paper, short enough to survive ten times a Puzzle.
    private let duration = 0.65

    #if DEBUG
    /// Freezes a turn part-way so the curl can be looked at without racing an
    /// animation. `-curlHold 0.35` on launch.
    @MainActor
    func hold(from model: GameModel, at value: Double, _ change: @escaping () -> Void) {
        isFlipping = true
        outgoing = GameModel(frozen: model.game, page: model.page)
        change()
        progress = value
    }
    #endif

    @MainActor
    func flip(from model: GameModel, reduceMotion: Bool, _ change: @escaping () -> Void) async {
        guard !isFlipping else { return }

        guard !reduceMotion else {
            change()
            return
        }

        isFlipping = true
        outgoing = GameModel(frozen: model.game, page: model.page)
        change()
        Haptics.pageTurn()

        // The leaving sheet has to be committed flat for one frame before it
        // starts to move. Inserting a view and animating it in the same update
        // gives the animation no value to travel from, so it arrives already
        // finished — which looks exactly like no animation at all.
        try? await Task.sleep(for: .milliseconds(16))

        withAnimation(.easeInOut(duration: duration)) { progress = 1 }
        try? await Task.sleep(for: .seconds(duration))

        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            progress = 0
            outgoing = nil
        }
        isFlipping = false
    }
}

// MARK: - The leaf turn

extension View {
    /// Turns one complete leaf about the book's spine. The previous Metal
    /// deform sampled a full-page texture for every output pixel and produced
    /// a long triangular wedge on device. A sheet turning on its hinge is both
    /// closer to a physical book and lets Core Animation keep the movement on
    /// the compositor.
    func pageLeafTurn(progress: Double, size: CGSize) -> some View {
        modifier(PageLeafTurn(progress: progress, size: size))
    }
}

private struct PageLeafTurn: ViewModifier, Animatable {
    var progress: Double
    var size: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let turn = min(max(progress, 0), 1)
        // Keep the sheet just shy of edge-on. The last fraction is masked by
        // its own travelling shadow, so the new page is revealed continuously
        // instead of the old page becoming a mirrored card face.
        let angle = -89.7 * turn
        let foldOpacity = 0.30 * sin(turn * .pi)

        content
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                              anchor: .leading, perspective: 0.24)
            .scaleEffect(x: 1 - turn * 0.018, y: 1 - turn * 0.006,
                         anchor: .leading)
            .shadow(color: .black.opacity(0.22 * (1 - turn)),
                    radius: max(2, size.width * 0.018), x: 3, y: 3)
            .overlay(alignment: .leading) {
                LinearGradient(colors: [.black.opacity(foldOpacity), .clear],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: size.width * 0.28)
                    .allowsHitTesting(false)
            }
    }
}
