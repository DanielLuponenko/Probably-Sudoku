import SwiftUI

/// Shared by menu and in-Book Settings. Practice owns a fresh engine Game and
/// dismisses back to its presenter; it never resolves first-run onboarding.
struct LearningSection: View {
    @State private var destination: Destination?

    enum Destination: String, Identifiable {
        case guide, practice
        var id: String { rawValue }
    }

    var body: some View {
        SlipSection(title: "Learn & practice",
                    note: "A quick refresher or a fresh practice page. Your current Book stays exactly where you left it.") {
            PaperButton(title: "How to play", kind: .quiet) { destination = .guide }
                .accessibilityIdentifier("learning-how-to-play")
            PaperButton(title: "Replay tutorial", kind: .quiet) { destination = .practice }
                .accessibilityIdentifier("learning-replay-tutorial")
                .accessibilityHint("About 90 seconds. Practice without changing your saved Book or achievements. Exit at any time.")
        }
        .fullScreenCover(item: $destination) { destination in
            LearningPresentation(destination: destination)
        }
    }
}

struct LearningPresentation: View {
    let destination: LearningSection.Destination
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch destination {
        case .guide:
            HelpSlip { dismiss() }
                .background(Paper.pageWarm.ignoresSafeArea())
        case .practice:
            TutorialView(presentation: .replay) { _ in dismiss() }
        }
    }
}
