import Foundation

public struct GeneratedPuzzle: Sendable {
    public let solution: [Digit]      // 81, the unique solution
    public let isGiven: [Bool]        // 81, true where a number is pre-printed
}

public enum Generator {

    /// Fills an empty grid with a random complete sudoku.
    static func fullGrid(_ rng: inout RandomStream) -> [UInt8] {
        var g = [UInt8](repeating: 0, count: 81)

        func backtrack(_ cell: Int) -> Bool {
            if cell == 81 { return true }
            for v in rng.shuffled([1, 2, 3, 4, 5, 6, 7, 8, 9]) {
                guard Solver.isValid(g, cell, UInt8(v)) else { continue }
                g[cell] = UInt8(v)
                if backtrack(cell + 1) { return true }
                g[cell] = 0
            }
            return false
        }

        _ = backtrack(0)
        return g
    }

    /// Removes numbers one at a time, keeping the solution unique, until the
    /// Givens target is met. Returns nil if the random walk runs out of
    /// removable squares first — the caller just tries another board.
    static func dig(_ rng: inout RandomStream, solution: [UInt8], givensTarget: Int) -> [Bool]? {
        var g = solution
        var isGiven = [Bool](repeating: true, count: 81)
        var givens = 81

        for cell in rng.shuffled(Array(0..<81)) {
            if givens <= givensTarget { break }
            let backup = g[cell]
            g[cell] = 0
            if Solver.countSolutions(g, limit: 2) == 1 {
                isGiven[cell] = false
                givens -= 1
            } else {
                g[cell] = backup
            }
        }

        return givens <= givensTarget ? isGiven : nil
    }

    /// A board only counts as its difficulty if the technique ladder agrees:
    /// Easy must fall to singles alone, Medium must be solvable by the whole
    /// ladder, and a Boss must defeat it.
    static func passesGate(_ difficulty: Difficulty, solution: [UInt8], isGiven: [Bool]) -> Bool {
        var puzzle = [UInt8](repeating: 0, count: 81)
        for i in 0..<81 where isGiven[i] { puzzle[i] = solution[i] }
        let graded = Solver.grade(puzzle)
        switch difficulty {
        case .easy:   return graded == .nakedSingle || graded == .hiddenSingle
        case .medium: return graded != .unsolved
        case .boss:   return graded == .unsolved
        }
    }

    /// Generates a puzzle for `difficulty`, retrying until both the unique
    /// solution and the difficulty gate hold. Retries consume more of the
    /// board stream, so the result stays a pure function of the seed.
    public static func generate(_ rng: inout RandomStream,
                                difficulty: Difficulty,
                                givens: Int? = nil,
                                maxAttempts: Int = 200) throws -> GeneratedPuzzle {
        for _ in 0..<maxAttempts {
            let solution = fullGrid(&rng)
            guard let isGiven = dig(&rng, solution: solution,
                                    givensTarget: givens ?? difficulty.givens) else { continue }
            guard passesGate(difficulty, solution: solution, isGiven: isGiven) else { continue }
            return GeneratedPuzzle(
                solution: solution.map { Digit(rawValue: Int($0))! },
                isGiven: isGiven
            )
        }
        throw EngineError.generationFailed(difficulty: difficulty, attempts: maxAttempts)
    }
}

public enum EngineError: Error, CustomStringConvertible {
    case generationFailed(difficulty: Difficulty, attempts: Int)

    public var description: String {
        switch self {
        case let .generationFailed(difficulty, attempts):
            return "Could not generate a \(difficulty.rawValue) puzzle after \(attempts) attempts"
        }
    }
}
