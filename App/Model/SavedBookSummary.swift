import ProbablySudokuEngine

/// Presentation of the one saved attempt. Reading this never creates or
/// advances a Game; Continue re-reads the durable state when accepted.
struct SavedBookSummary: Equatable {
    let bookTitle: String
    let location: String
    let detail: String
    let compactLocation: String
    let isCompleted: Bool

    init?(game: Game?) {
        guard let game, game.run.outcome != .failed else { return nil }
        let run = game.run
        bookTitle = BookEdition.edition(for: run.book).title
        isCompleted = run.outcome == .bookCompleted
        if isCompleted {
            location = "Book \(run.book.volume) completed"
            detail = "Your final page is ready"
            compactLocation = location
        } else {
            location = "Book \(run.book.volume) · Chapter \(run.level) of 9"
            let place = run.shop != nil ? "Shop"
                : run.slot == .boss ? "Boss puzzle" : "Puzzle \(run.slot.rawValue + 1)"
            compactLocation = "Book \(run.book.volume) · Chapter \(run.level) · \(run.slot == .boss && run.shop == nil ? "Boss" : place)"
            let phase = game.puzzle.map { puzzle in
                switch puzzle.phase {
                case .won: " · Target met"
                case .cashedOut: " · Cashed out"
                case .outOfTurns: " · Out of turns"
                case .failed: ""
                case .playing, .keepFilling: " · Turn \(puzzle.turnNumber)/\(puzzle.turnsMax)"
                }
            } ?? ""
            detail = "\(place)\(phase) · \(run.coins) coins"
        }
    }

    var actionTitle: String { isCompleted ? "View final page" : "Continue" }
    var decisionLabel: String { "\(bookTitle)\n\(location)\n\(detail)" }
}
