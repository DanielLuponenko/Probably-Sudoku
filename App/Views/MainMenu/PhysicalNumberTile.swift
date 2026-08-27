import SwiftUI

/// One tile out of the nine: a slab of warm ivory with a number pressed into
/// it, sitting in a wooden slot.
///
/// Everything that makes it read as an object is drawn here rather than
/// exported — a highlight along the top-left where the lamp catches the
/// chamfer, a sidewall under the face, and a contact shadow at the bottom
/// right where it touches the board. The numeral is live, so it stays sharp at
/// any tile size and can be read out loud.
/// Nothing here moves. Where the tile is, and how far it has arrived, is
/// `TileMotion`'s business — which is what keeps the grain, the chamfer and the
/// numeral from being redrawn a hundred and twenty times a second.
struct PhysicalNumberTile: View {
    var number: Int
    var side: CGFloat
    /// A short reverse-side mark used by the opening board's playful tiles.
    /// Keeping it on the same physical slab preserves the tile's material
    /// while only the face changes during a flip.
    var glyph: String?

    /// Never more than a third of a degree: a tile that is visibly crooked
    /// reads as broken, and a tile that is perfectly square reads as printed.
    var tilt: Double

    private var faceText: String { glyph ?? "\(number)" }

    private var faceFont: Font {
        glyph == nil
            ? Print.numeral(side * 0.60, weight: .semibold)
            : .system(size: side * 0.31, weight: .black, design: .rounded)
    }

    var body: some View {
        let corner = side * 0.085
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack {
            // The sidewall, showing under the face.
            shape
                .fill(Color(hex: 0xB6A98A))
                .offset(y: side * 0.035)

            // The face.
            shape
                .fill(LinearGradient(colors: [Color(hex: 0xEDE5CE), Paper.pageWarm,
                                              Color(hex: 0xD2C8AE)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { PaperGrain(opacity: 0.05, seed: UInt64(number * 31 + 7))
                    .clipShape(shape) }
                .overlay {
                    // The chamfer: lit on the lamp's side, in shade opposite.
                    shape.strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.75), .clear,
                                                .black.opacity(0.18)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(0.7, side * 0.045))
                }
                .overlay {
                    shape.strokeBorder(Paper.pageEdge.opacity(0.9), lineWidth: 0.8)
                        .padding(max(0.7, side * 0.045))
                }

            Text(faceText)
                .font(faceFont)
                .foregroundStyle(Color(hex: 0x4A4235))
                // Pressed in: one dark line under, one light line over.
                .background {
                    Text(faceText)
                        .font(faceFont)
                        .foregroundStyle(.white.opacity(0.55))
                        .offset(y: -0.7)
                }
        }
        .frame(width: side, height: side)
        .rotationEffect(.degrees(tilt))
        .shadow(color: .black.opacity(0.35), radius: side * 0.06,
                x: side * 0.02, y: side * 0.045)
        .accessibilityHidden(true)
    }
}
/// Where one tile is, this frame.
///
/// Animatable, so it is sampled continuously; a modifier, so the tile it moves
/// is drawn once and then only transformed.
struct TileMotion: ViewModifier, Animatable {
    var phase: Double
    var entrance: Double
    var index: Int
    var side: CGFloat
    var reduceMotion: Bool

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, entrance) }
        set {
            phase = newValue.first
            entrance = newValue.second
        }
    }

    /// The entrance, in seconds. The entire board arrives with the room;
    /// serial tile arrivals read as assets loading rather than as a board.
    static let span = 0.72
    private static let firstAt = 0.04
    private static let settle = 0.32

    func body(content: Content) -> some View {
        content
            .overlay {
                if sheen > 0.01 {
                    RoundedRectangle(cornerRadius: side * 0.11, style: .continuous)
                        .strokeBorder(.white.opacity(0.55 * sheen),
                                      lineWidth: max(0.6, side * 0.035))
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
            }
            // Coming down into the slot, then the occasional nudge.
            .offset(y: (1 - arrival) * -side * 0.16 - lift * side * 0.02)
            .scaleEffect(0.96 + 0.04 * arrival)
            .opacity(0.65 + 0.35 * arrival)
    }

    private var arrival: Double {
        guard !reduceMotion else { return 1 }
        let seconds = entrance * Self.span
        return min(1, max(0, (seconds - Self.firstAt) / Self.settle))
    }

    /// Twice in every cycle — about nine seconds apart — one tile shifts by a
    /// point and settles. Which two is fixed, because two tiles chosen afresh
    /// every cycle is a fidget rather than a room.
    private var lift: Double {
        guard !reduceMotion, entrance >= 1 else { return 0 }
        for (at, tile) in [(0.30, 2), (0.74, 6)] where tile == index {
            let through = (phase - at) / 0.06
            if through > 0, through < 1 { return sin(through * .pi) }
        }
        return 0
    }

    /// A faint warmth running across the nine in order, once a cycle. It is
    /// the light moving, not the tiles.
    private var sheen: Double {
        guard !reduceMotion else { return 0 }
        let start = 0.08 + Double(index) * 0.012
        let through = (phase - start) / 0.09
        guard through > 0, through < 1 else { return 0 }
        return sin(through * .pi) * 0.5
    }
}
