import ProbablySudokuEngine

/// Return to the volume just finished, with its next earned challenge selected.
/// Only durable progress may make an obstacle available on the Bookstand.
struct CompletedBookSelection: Equatable {
    let edition: BookEdition
    let obstacle: Obstacle

    init(book: Book, completedObstacle: Obstacle, progressByBookID: [String: Int]) {
        edition = BookEdition.edition(for: book)
        let next = Obstacle(rawValue: completedObstacle.rawValue + 1) ?? completedObstacle
        obstacle = edition.availableObstacle(next, progressByBookID: progressByBookID)
    }
}
