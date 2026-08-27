import Foundation

/// The fixed teaching beats for a player's very first Puzzle. The engine owns
/// the position of each beat so the app can render it without guessing at
/// mutable presentation state.
public enum FirstRunTutorial {
    public static let lineCount = 6

    /// Returns the teaching-line index for the first six Turns of Book 1's
    /// first Puzzle. Every other Puzzle is left to its Book's ordinary seeded
    /// marginalia.
    public static func lineIndex(book: Book, level: Int, slot: PuzzleSlot, turn: Int) -> Int? {
        guard book == .probably, level == 1, slot == .easy,
              (1...lineCount).contains(turn) else { return nil }
        return turn - 1
    }
}
