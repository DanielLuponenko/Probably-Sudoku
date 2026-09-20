import SwiftUI
import ProbablySudokuEngine

/// The app's front door. The bookstore owns presentation only; choosing a
/// volume or continuing the current Book goes through ContentView's save guard.
struct MainMenuView: View {
    var onBookSelected: (BookEdition, Obstacle) -> Void
    var onContinueBook: () -> Void = {}
    var onFirstFrame: (() -> Void)? = nil
    var isSceneVisible = true
    var completedBookSelection: CompletedBookSelection? = nil

    var body: some View {
        BookstoreOpeningView(onOpenBook: onBookSelected, onContinueBook: onContinueBook,
                             onFirstFrame: onFirstFrame,
                             isSceneVisible: isSceneVisible,
                             completedBookSelection: completedBookSelection)
    }
}
