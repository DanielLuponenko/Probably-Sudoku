import SwiftUI
import ProbablySudokuEngine

/// A line the Book says to you, written by hand in the margin.
///
/// Where and when it appears is rolled from the seed rather than from a live
/// random source, so a Book says the same things in the same places every time
/// it is played — which is the same promise §15 makes about everything else.
struct MarginNote: Equatable {
    let text: String
    /// 0 = hard left of the margin, 1 = hard right. Never outside it.
    let lateral: Double
    let angle: Double
    let underlined: Bool

    /// Notes are hand-written, so they are print handwriting rather than a
    /// script face: Bradley Hand is on every iOS device and is unjoined.
    static func font(_ size: CGFloat) -> Font {
        .custom("Bradley Hand", size: size)
    }

    /// Rolls the note for one Turn. Returns nil for most Turns — a book that
    /// talks constantly stops being a book and starts being a chat window.
    static func roll(seed: String, level: Int, slot: Int, turn: Int,
                     from edition: BookEdition) -> MarginNote? {
        var rng = RandomStream(seed: "\(seed):\(level):\(slot):\(turn)", stream: "marginalia")

        // The Book always introduces itself on the first Turn of a Puzzle;
        // after that it chips in now and then.
        let speaks = turn == 1 || rng.next() < 0.42
        guard speaks, !edition.marginalia.isEmpty else { return nil }

        let text = edition.marginalia[rng.int(edition.marginalia.count)]
        return MarginNote(
            text: text,
            lateral: rng.next(),
            angle: -2.6 + rng.next() * 5.2,
            underlined: rng.next() < 0.22
        )
    }

    /// The first Book teaches by writing beside the work, never by stopping it
    /// with a modal tour. These fixed beats are one line per Turn.
    static func firstRunTeachingLine(at index: Int) -> MarginNote? {
        let lines = [
            "Pick a number from your Hand, then put it on a Blank.",
            "Right numbers score. Wrong ones cost 50 times their value and go back to the Pool.",
            "End a Turn to deal back up. What you do not place stays in your Hand.",
            "Toss sends a picked number back to the Pool. The allowance is printed on the button.",
            "The target is the number beside the slash. Clear rows, columns and boxes to reach it.",
            "When you meet the target, Cash Out to bank it — or Keep Filling for more coins."
        ]
        guard lines.indices.contains(index) else { return nil }
        let lateral = [0.02, 0.64, 0.16, 0.58, 0.10, 0.48][index]
        let angle = [-1.4, 1.2, -0.7, 1.6, -1.1, 0.8][index]
        return MarginNote(text: lines[index], lateral: lateral, angle: angle,
                          underlined: index == 4 || index == 5)
    }
}

/// Draws the note in the band under the grid — the one part of the page with
/// nothing printed on it and nothing to tap, so a note can never cover a
/// square, a number or a button, and can never fall off the page.
struct MarginNoteView: View {
    @Environment(\.cosmeticTheme) private var theme
    var note: MarginNote

    /// The note is offset from the left by at most a quarter of the free width
    /// and is never wider than the remaining three quarters, so whatever the
    /// line says it cannot reach the edge of the page.
    private let inset: CGFloat = 10
    private let lateralShare = 0.25

    var body: some View {
        GeometryReader { proxy in
            let slack = max(0, proxy.size.width - inset * 2)
            noteText
                .frame(maxWidth: slack * (1 - lateralShare), alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .rotationEffect(.degrees(note.angle), anchor: .leading)
                .padding(.leading, inset + slack * lateralShare * note.lateral)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .allowsHitTesting(false)
        .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .leading)))
        .accessibilityLabel("Note in the margin: \(note.text)")
    }

    private var noteText: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(note.text)
                .font(MarginNote.font(16))
                .foregroundStyle(theme.paper.handwritingInk(theme.marker.tint))
                // Two lines, shrinking rather than wrapping to a third: the
                // band is fixed, and a third line runs into the Hand below it.
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .multilineTextAlignment(.leading)
            if note.underlined {
                // A wobbly underline, drawn the way a hand draws one.
                Underline()
                    .stroke(theme.paper.handwritingInk(theme.marker.tint).opacity(0.55), lineWidth: 1.2)
                    .frame(height: 3)
            }
        }
    }
}

private struct Underline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.width * 0.3, y: rect.midY - 1.6),
            control2: CGPoint(x: rect.width * 0.7, y: rect.midY + 1.6)
        )
        return path
    }
}
