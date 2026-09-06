import Foundation

/// One app-specific destination shared by both Settings entry points.
/// Release preflight must verify that these pages are publicly accessible.
enum AppLinks {
    static let support = URL(string: "https://probably-sudoku-support.dannyluponenko.chatgpt.site")!
    static let privacyPolicy = support.appendingPathComponent("privacy")
}
