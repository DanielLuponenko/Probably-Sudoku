import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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

// MARK: - The curl

extension View {
    /// Bends this view around a cylinder that sweeps across it, showing the
    /// back of the sheet as it comes over. See `PageCurl.metal`.
    ///
    /// The size is passed in rather than read from a `visualEffect` proxy:
    /// inside `visualEffect` the shader only ever sees the final value of an
    /// animated parameter, so the curl arrives already finished.
    func pageCurl(progress: Double, size: CGSize) -> some View {
        modifier(PageCurlEffect(progress: progress, size: size))
    }
}

private struct PageCurlEffect: ViewModifier, Animatable {
    var progress: Double
    var size: CGSize

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        guard size.width > 1, size.height > 1 else { return AnyView(content) }
        return AnyView(
            content.layerEffect(
                ShaderLibrary.pageCurl(
                    .float2(size),
                    .float(Float(progress)),
                    // A tighter roll than this creases; a looser one is a tube.
                    .float(Float(min(size.width, size.height) * 0.17))
                ),
                maxSampleOffset: size
            )
        )
    }
}

enum Haptics {
    static func prepare() {}

    static func menuPress() { impact(.medium, 0.55) }
    static func menuOpen() { impact(.light, 0.45) }
    static func lift() { impact(.soft, 0.5) }

    /// The soft thump of a sheet landing.
    static func pageTurn() {
        impact(.soft, 0.7)
    }

    private static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle,
                               _ intensity: CGFloat) {
        guard AppPreferences.hapticsEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
        #endif
    }
}
