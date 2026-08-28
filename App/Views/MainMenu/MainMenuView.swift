import SwiftUI
import ProbablySudokuEngine

/// The app's front door. The bookstore owns presentation only; choosing a
/// volume still exits through ContentView's existing run-conflict callback.
struct MainMenuView: View {
    var onBookSelected: (BookEdition, Obstacle) -> Void

    var body: some View {
        BookstoreOpeningView(onOpenBook: onBookSelected)
    }
}
