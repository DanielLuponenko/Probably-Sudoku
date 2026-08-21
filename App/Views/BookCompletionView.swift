import SwiftUI

/// The Book's final movement uses the same constructed cover as its opening:
/// it closes on the shelf before the congratulations slip is shown.
struct LiveBookClosing: View {
    var edition: BookEdition
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
                    LiveBook(edition: edition, openAngle: angle)
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
            guard !finished else { return }
            withAnimation(.easeIn(duration: swing * 0.3)) { wash = 1 }
            try? await Task.sleep(for: .seconds(swing * 0.3))
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

/// Held above the shelf after the cover lands. All values are a terminal run
/// snapshot, so returning to the shelf can safely discard the completed run.
struct BookCompletionView: View {
    var summary: GameModel.BookCompletionSummary
    var onReturnToShelf: () -> Void
    @State private var displayedStamps = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("BOOK COMPLETE")
                .font(Print.caption(12))
                .tracking(2)
                .foregroundStyle(Paper.sageDeep)
            Text(summary.edition.title)
                .pageHeading(30)
                .multilineTextAlignment(.center)
            Text("The cover is back on the shelf. Your next volume is ready.")
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                CompletionMetric(label: "Levels cleared", value: "\(summary.levelsCleared) of 9")
                CompletionMetric(label: "Bosses beaten", value: "\(summary.bossesBeaten) of 9")
                CompletionMetric(label: "Best Puzzle score", value: summary.bestPuzzleScore.formatted())
                HStack {
                    Text("Stamps earned")
                        .font(Print.body(13))
                        .foregroundStyle(Paper.inkSoft)
                    Spacer()
                    RollingNumber(value: displayedStamps, size: 16, weight: .bold,
                                  color: Paper.coinRim)
                        .accessibilityLabel("\(displayedStamps) Stamps earned")
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("FINISHED WITH")
                    .font(Print.caption(10))
                    .tracking(1.4)
                    .foregroundStyle(Paper.inkFaint)
                Text(summary.loadout.isEmpty ? "No held Bookmarks, Markers, Buffs, or Subscriptions."
                     : summary.loadout.joined(separator: " · "))
                    .font(Print.body(12))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let nextBook = summary.nextBook, nextBook.isWritten {
                Label("\(nextBook.title) is now unlocked", systemImage: "lock.open.fill")
                    .font(Print.subheading(13))
                    .foregroundStyle(Paper.sageDeep)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("Next Book unlocked: \(nextBook.title)")
            }

            PaperButton(title: "Return to Shelf", kind: .primary, action: onReturnToShelf)
        }
        .padding(22)
        .frame(maxWidth: 390)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Paper.page)
                .shadow(color: .black.opacity(0.36), radius: 24, y: 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Paper.rule, lineWidth: 1)
        }
        .padding(22)
        .onAppear {
            guard displayedStamps != summary.stampsEarned else { return }
            // One rendered zero establishes the counter's starting point.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(16))
                withAnimation(.snappy(duration: 0.45)) { displayedStamps = summary.stampsEarned }
            }
        }
    }
}

private struct CompletionMetric: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
            Spacer()
            Text(value)
                .font(Print.numeral(16, weight: .bold))
                .foregroundStyle(Paper.ink)
        }
        .accessibilityElement(children: .combine)
    }
}
