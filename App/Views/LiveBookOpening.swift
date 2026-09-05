import SwiftUI
import ProbablySudokuEngine

/// Opening the Book.
///
/// Not a clip. A recorded opening is one Book, one size and one light: every
/// volume would need its own, the app would grow by a film per title, and the
/// cut from the shelf to the film is always visible because the desk in the
/// film is not the desk you were just looking at.
///
/// Here it is the same desk and the same Book, and the front board simply
/// swings on its joint.
struct LiveBookOpening: View {
    var edition: BookEdition
    var obstacle: Obstacle
    var reduceMotion: Bool
    var onFinish: () -> Void

    /// Drawn once, when the Book is opened — not per frame, or the page would
    /// change its mind while you were reading it.
    @State private var epigraph = Jokes.random()
    @State private var angle: Double = 0
    @State private var closing: Double = 0     // the page coming up to meet you
    @State private var wash: Double = 0
    @State private var finished = false

    private let swing = 1.05
    private let handover = 0.30

    var body: some View {
        Button(action: skip) {
            ZStack {
                ShelfBackdrop(book: edition)

                GeometryReader { proxy in
                    LiveBook(edition: edition, openAngle: angle,
                             selectedObstacle: obstacle, epigraph: epigraph)
                        .frame(width: proxy.size.width * 0.72)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .scaleEffect(1 + closing * 1.35, anchor: .center)
                        .offset(y: -proxy.size.height * 0.02 * closing)
                }

                Paper.page.opacity(wash).ignoresSafeArea()
            }
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .background(Paper.deskDark)
        .statusBarHidden()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .task {
            guard !reduceMotion else { finish(); return }
            Haptics.pageTurn()

            // Heavy at the start, light at the end — a board is stiff on the
            // joint and then falls the last of the way under its own weight.
            withAnimation(.timingCurve(0.32, 0, 0.32, 1, duration: swing)) {
                angle = -172
            }
            try? await Task.sleep(for: .seconds(swing * 0.55))
            guard !finished else { return }
            withAnimation(.easeIn(duration: swing * 0.45 + handover)) { closing = 1 }

            try? await Task.sleep(for: .seconds(swing * 0.45))
            guard !finished else { return }
            withAnimation(.easeIn(duration: handover)) { wash = 1 }

            try? await Task.sleep(for: .seconds(handover))
            finish()
        }
        .accessibilityLabel("Opening the book")
        .accessibilityHint("Double tap to skip")
    }

    /// Cuts to the Puzzle, still through the wash rather than as a hard cut —
    /// a skip should be quick, not jarring.
    private func skip() {
        guard !finished else { return }
        withAnimation(.easeIn(duration: 0.16)) { wash = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            finish()
        }
    }

    /// Guards against the timed hand-over and a tap both firing, which would
    /// deal two Puzzles.
    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}
