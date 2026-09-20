import SwiftUI
import ProbablySudokuEngine

/// Owed draws are folded tickets, never previewed digits. Delivery removes
/// these tickets while the real drawn cards enter the existing Hand strip.
struct CourierTickets: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    let count: Int
    var body: some View {
        ZStack {
            if count > 0 {
                ZStack {
                    RoundedRectangle(cornerRadius: 2).fill(GameplaySurface.ivory)
                        .rotationEffect(.degrees(-8)).offset(x: -3, y: 1)
                    Text("\(count)").font(Print.numeral(14, weight: .bold))
                        .frame(width: 27, height: 23)
                        .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 2))
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(GameplaySurface.sage, lineWidth: 1))
                        .overlay(alignment: .topTrailing) {
                            Image(systemName: "arrow.up").font(.system(size: 7, weight: .bold)).padding(2)
                        }
                }
                .frame(width: 27, height: 23)
                .shadow(color: .black.opacity(0.15), radius: 1.5, y: 2)
                .transition(.asymmetric(insertion: .offset(y: 7).combined(with: .opacity),
                                        removal: .offset(y: -28).combined(with: .opacity)))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.24), value: count)
        .allowsHitTesting(false).accessibilityLabel("\(count) bonus draws due after banking")
    }
}

/// These marks occupy the existing Turn label's margin. They never control
/// banking; the cut is feedback for one completed engine boundary.
struct PageCutterMarks: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    let fills: Int
    let turn: Int
    @State private var cut: CGFloat = -1
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { index in
                Capsule().fill(index < fills ? GameplaySurface.sage : GameplaySurface.softInk.opacity(0.25))
                    .frame(width: 3, height: 9)
            }
        }
        .frame(width: 28, height: 15)
        .overlay {
            if cut >= 0 && cut < 1 {
                Rectangle().fill(GameplaySurface.ink.opacity(0.8)).frame(width: 1, height: 13)
                    .offset(x: -14 + cut * 28)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: fills)
        .onChange(of: turn) { _, _ in
            guard !reduceMotion else { return }
            cut = 0
            withAnimation(.linear(duration: 0.24)) { cut = 1 }
        }
        .allowsHitTesting(false)
        .accessibilityLabel("\(fills) of 4 fills before automatic banking")
    }
}
