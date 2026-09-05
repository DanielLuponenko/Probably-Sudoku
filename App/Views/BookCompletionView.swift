import SwiftUI
import ProbablySudokuEngine

/// The Book's final movement uses the same constructed cover as its opening:
/// it closes only after the reader dismisses the congratulations page.
struct LiveBookClosing: View {
    var edition: BookEdition
    var obstacle: Obstacle = .none
    var reduceMotion: Bool
    var onFinish: () -> Void

    @State private var angle = -172.0
    @State private var wash = 0.0
    @State private var finished = false

    private let swing = 0.9

    var body: some View {
        Button(action: skip) {
            ZStack {
                ShelfBackdrop(book: edition)
                GeometryReader { proxy in
                    LiveBook(edition: edition, openAngle: angle, selectedObstacle: obstacle)
                        .frame(width: proxy.size.width * 0.72)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                Paper.page.opacity(wash).ignoresSafeArea()
            }
        }
        .buttonStyle(.plain)
        .ignoresSafeArea()
        .background(Paper.deskDark)
        .statusBarHidden()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Closing \(edition.title)")
        .accessibilityHint("Double tap to skip")
        .accessibilityAction(named: "Skip book closing", skip)
        .task {
            guard !reduceMotion else { finish(); return }
            Haptics.pageTurn()
            withAnimation(.timingCurve(0.32, 0, 0.32, 1, duration: swing)) { angle = 0 }
            try? await Task.sleep(for: .seconds(swing * 0.7))
            guard !finished, !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: swing * 0.3)) { wash = 1 }
            try? await Task.sleep(for: .seconds(swing * 0.3))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func skip() {
        guard !finished else { return }
        withAnimation(.easeIn(duration: 0.16)) { wash = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(160))
            finish()
        }
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}
