import SwiftUI

/// A note somebody left taped to the cabinet.
///
/// One line per day, not one every few seconds. A joke that changes while you
/// are looking at it stops being a note in a room and becomes a banner ad, and
/// the whole effect of the thing is that it was written once and never taken
/// down.
struct HumourNote: View {
    var metrics: MainMenuSceneMetrics

    private var scale: CGFloat { metrics.scale }

    /// The club's voice: dry, short, and quietly disappointed in you.
    private static let notes: [[String]] = [
        ["The grid", "is patient.", "You are not."],
        ["Take your time.", "The timer", "will not."],
        ["Nine numbers.", "How difficult", "could it be?"],
        ["A calm mind helps.", "Let me know", "if you find one."],
        ["The grid remembers.", "Conveniently,", "you do not have to."],
        ["One square at a time.", "Preferably", "the correct ones."],
    ]

    /// Chosen by the day, so the note is the same all afternoon and different
    /// tomorrow. Deterministic, like everything else the game says.
    private static var todaysNote: [String] {
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return notes[abs(day) % notes.count]
    }

    private let lines = HumourNote.todaysNote

    var body: some View {
        VStack(alignment: .leading, spacing: 1 * scale) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(Print.handwritten(max(11, 26 * scale)))
                    .foregroundStyle(Paper.pencil)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            Image(systemName: "heart.fill")
                .font(.system(size: max(7, 18 * scale)))
                .foregroundStyle(Paper.sage)
                .padding(.top, 2 * scale)
        }
        .padding(.horizontal, 14 * scale)
        .padding(.top, 26 * scale)
        .padding(.bottom, 22 * scale)
        .frame(width: metrics.humourNoteFrame.width,
               height: metrics.humourNoteFrame.height,
               alignment: .topLeading)
        .background {
            TornPaper()
                .fill(LinearGradient(colors: [Paper.page, Paper.pageWarm],
                                     startPoint: .top, endPoint: .bottom))
                .overlay { PaperGrain(opacity: 0.07, seed: 33).clipShape(TornPaper()) }
                .shadow(color: .black.opacity(0.45), radius: 6 * scale, x: 2, y: 5 * scale)
        }
        .overlay(alignment: .top) { tape }
        .rotationEffect(.degrees(-1.2))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(lines.joined(separator: " "))
    }

    private var tape: some View {
        Rectangle()
            .fill(ClubRoomMaterial.tape.opacity(0.72))
            .frame(width: metrics.humourNoteFrame.width * 0.52, height: 20 * scale)
            .overlay(Rectangle().strokeBorder(.white.opacity(0.18), lineWidth: 0.6))
            .rotationEffect(.degrees(2.5))
            .offset(y: -7 * scale)
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
}
/// Paper that was torn off something rather than cut. The tear is along the
/// bottom only — the other three edges came off a pad.
private struct TornPaper: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.05))

        // Deterministic, so the same sheet is torn the same way every launch.
        var state: UInt64 = 8675309
        func unit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        var x = rect.maxX
        while x > rect.minX {
            x -= rect.width * (0.06 + unit() * 0.07)
            let y = rect.maxY - rect.height * (0.02 + unit() * 0.055)
            path.addLine(to: CGPoint(x: max(rect.minX, x), y: y))
        }
        path.closeSubpath()
        return path
    }
}
