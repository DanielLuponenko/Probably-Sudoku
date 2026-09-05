import Foundation
import ProbablySudokuEngine

/// One opt-in presentation, bound to the puzzle that requested it. The SDK
/// never holds authority over whichever puzzle happens to be open later.
struct RewardedRescueSession {
    private struct PuzzleIdentity: Equatable {
        let seed: String
        let book: Book
        let obstacle: Obstacle
        let level: Int
        let slot: PuzzleSlot
        let turn: Int

        init?(_ game: Game) {
            guard let puzzle = game.puzzle else { return nil }
            seed = game.run.seed
            book = game.run.book
            obstacle = game.run.obstacle
            level = puzzle.level
            slot = puzzle.slot
            turn = puzzle.turnNumber
        }
    }

    private struct Presentation {
        let ticket: UUID
        let puzzle: PuzzleIdentity
        var earned = false
    }

    private var presentation: Presentation?
    var isActive: Bool { presentation != nil }

    mutating func begin(for game: Game) -> UUID? {
        guard presentation == nil, game.canClaimRewardedRescue,
              let identity = PuzzleIdentity(game) else { return nil }
        let ticket = UUID()
        presentation = Presentation(ticket: ticket, puzzle: identity)
        return ticket
    }

    /// Called only by the SDK's earned-reward callback, never by dismissal.
    mutating func receive(_ ticket: UUID, game: inout Game) -> Bool {
        guard let current = presentation, current.ticket == ticket,
              !current.earned, current.puzzle == PuzzleIdentity(game),
              game.claimRewardedRescue() else { return false }
        presentation?.earned = true
        return true
    }

    func hasEarned(_ ticket: UUID) -> Bool {
        presentation?.ticket == ticket && presentation?.earned == true
    }

    /// Closing early keeps the offer. An earned reward returns to the same
    /// board, but only after the full-screen ad has actually gone away.
    mutating func finish(_ ticket: UUID, game: Game) -> Bool {
        guard let current = presentation, current.ticket == ticket else { return false }
        presentation = nil
        return current.earned && current.puzzle == PuzzleIdentity(game)
            && game.run.outcome == nil && game.puzzle?.phase == .playing
    }

    mutating func invalidate() { presentation = nil }
}
