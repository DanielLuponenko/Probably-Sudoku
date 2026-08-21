import SwiftUI

/// Three little boxes at the head of the desk, quietly working themselves out.
///
/// Not decoration for its own sake: the empty wood above the Book was the one
/// place on the shelf that said nothing, and what belongs there is the same
/// thing that is inside the Book. Each is a single sudoku box — nine cells,
/// the digits one to nine, no repeats — filling itself in and starting again.
///
/// Deliberately faint. It is meant to be noticed on the second look, the way
/// you notice a clock, and never to compete with the cover below it.
struct SolvingBoxes: View {
    /// The desk's slow clock. One turn is one solve.
    var phase: Double
    var size: CGFloat = 46

    var body: some View {
        HStack(spacing: size * 0.52) {
            ForEach(0..<3, id: \.self) { index in
                // Offset so they are never in step: three boxes finishing
                // together would read as one animation in three pieces.
                SolvingBox(phase: phase + Double(index) * 0.37, seed: index)
                    .frame(width: size, height: size)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
/// One box, mid-solve.
///
/// `Animatable` rather than a value read in a body: a plain `Double` is only
/// read when state changes, so a repeating animation on one would fill every
/// cell in a single jump and then sit still.
private struct SolvingBox: View, Animatable {
    var phase: Double
    var seed: Int

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    /// Of each turn: filling, then a moment of it standing finished, then out.
    private static let filling = 0.68
    private static let clearing = 0.88

    var body: some View {
        let round = Int(floor(phase))
        let cycle = phase - floor(phase)
        let digits = Self.digits(round: round, seed: seed)
        let order = Self.order(round: round, seed: seed)
        // How many cells are in, to the fraction — the fraction is the fade.
        let written = cycle / Self.filling * 9
        let clearing = cycle > Self.clearing
            ? 1 - (cycle - Self.clearing) / (1 - Self.clearing)
            : 1

        GeometryReader { proxy in
            let s = proxy.size.width
            let cell = s / 3

            ZStack {
                Rules(cell: cell)

                ForEach(0..<9, id: \.self) { square in
                    let arrival = min(1, max(0, written - Double(order[square])))
                    Text("\(digits[square])")
                        .font(.system(size: cell * 0.62, weight: .semibold,
                                      design: .rounded))
                        .foregroundStyle(Paper.page.opacity(0.34 * arrival * clearing))
                        // Set down onto the square rather than faded up in
                        // place, which is what makes it read as written.
                        .scaleEffect(0.62 + 0.38 * arrival)
                        .position(x: (Double(square % 3) + 0.5) * cell,
                                  y: (Double(square / 3) + 0.5) * cell)
                }
            }
            .frame(width: s, height: s)
        }
    }

    // MARK: What it writes

    /// A permutation of one to nine: every box is a solved box, which is the
    /// only kind worth watching finish.
    private static func digits(round: Int, seed: Int) -> [Int] {
        shuffled(Array(1...9), salt: round &* 31 &+ seed)
    }

    /// The order the squares are filled in. Scattered, because a box filled
    /// left to right reads as a loading bar.
    private static func order(round: Int, seed: Int) -> [Int] {
        var places = [Int](repeating: 0, count: 9)
        for (step, square) in shuffled(Array(0..<9), salt: round &* 97 &+ seed &+ 5).enumerated() {
            places[square] = step
        }
        return places
    }

    private static func shuffled(_ input: [Int], salt: Int) -> [Int] {
        var values = input
        var state = UInt64(bitPattern: Int64(salt)) &* 2654435761 &+ 12345
        for index in stride(from: values.count - 1, to: 0, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            values.swapAt(index, Int(state >> 33) % (index + 1))
        }
        return values
    }
}

/// The box drawn round them: hairlines inside, a heavier edge, the way a
/// sudoku box is ruled.
private struct Rules: View {
    var cell: CGFloat

    var body: some View {
        ZStack {
            Path { path in
                for step in 1..<3 {
                    let offset = cell * CGFloat(step)
                    path.move(to: CGPoint(x: offset, y: 0))
                    path.addLine(to: CGPoint(x: offset, y: cell * 3))
                    path.move(to: CGPoint(x: 0, y: offset))
                    path.addLine(to: CGPoint(x: cell * 3, y: offset))
                }
            }
            .stroke(Paper.page.opacity(0.13), lineWidth: 0.5)

            Rectangle()
                .strokeBorder(Paper.page.opacity(0.20), lineWidth: 0.8)
        }
    }
}
