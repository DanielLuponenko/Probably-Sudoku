import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Turning a page in a real book is two movements: the sheet you were working
/// on lifts away, and the next one falls flat in its place. Driving both from
/// one view means the content can change while the paper is edge-on, so the
/// swap is never seen — which is the whole trick.
///
/// The lift is led by the **top-left corner**, the way a hand actually takes a
/// page. That means the axis is tilted off vertical and anchored at the corner
/// rather than running down the whole edge — a page pivoting about its entire
/// spine reads as a swinging door, not paper.
@Observable
final class PageFlipper {
    private(set) var angle: Double = 0
    private(set) var shade: Double = 0
    private(set) var isFlipping = false

    /// Short and physical, not cinematic: the design brief asks for paper, not
    /// a page-curl showreel.
    private let liftDuration = 0.17
    private let fallDuration = 0.21

    /// Runs `change` at the midpoint, while the page is side-on and nothing of
    /// it is visible.
    @MainActor
    func flip(reduceMotion: Bool, _ change: @escaping () -> Void) async {
        guard !isFlipping else { return }

        guard !reduceMotion else {
            // Reduce Motion gets the outcome without the rotation.
            withAnimation(.easeInOut(duration: 0.12)) { shade = 0.25 }
            change()
            withAnimation(.easeInOut(duration: 0.12)) { shade = 0 }
            return
        }

        isFlipping = true
        Haptics.pageTurn()

        withAnimation(.easeIn(duration: liftDuration)) {
            angle = -88
            shade = 0.5
        }
        try? await Task.sleep(for: .seconds(liftDuration))

        change()

        // Snap to the far side without animating, then let the new page fall.
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { angle = 88 }

        withAnimation(.easeOut(duration: fallDuration)) {
            angle = 0
            shade = 0
        }
        try? await Task.sleep(for: .seconds(fallDuration))
        isFlipping = false
    }
}

extension View {
    /// Applies a flipper's current state to a page.
    func pageFlip(_ flipper: PageFlipper) -> some View {
        let angle = flipper.angle
        return self
            .rotation3DEffect(
                .degrees(angle),
                // Tilted off vertical so the top-left corner leads and the
                // foot of the page trails behind it.
                axis: (x: 0.34, y: 1, z: 0),
                anchor: .topLeading,
                // Enough foreshortening to read as paper, little enough that
                // the near edge stays inside the book.
                perspective: 0.38
            )
            // A few degrees of in-plane swing, so the corner is visibly what
            // the page is being carried by.
            .rotationEffect(.degrees(angle * 0.05), anchor: .topLeading)
            .overlay {
                // Paper leaving the flat picks up shadow, and the raised corner
                // catches the light the desk lamp throws from the upper left.
                LinearGradient(
                    colors: [.white.opacity(flipper.shade * 0.28),
                             .black.opacity(flipper.shade),
                             .black.opacity(flipper.shade * 1.15)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)
            }
            .compositingGroup()
            .disabled(flipper.isFlipping)
    }
}

enum Haptics {
    /// The soft thump of a sheet landing.
    static func pageTurn() {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.7)
        #endif
    }
}
