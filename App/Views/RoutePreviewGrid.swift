import SwiftUI
import ProbablySudokuEngine

private enum RouteGridCenter: AlignmentID {
    static func defaultValue(in dimensions: ViewDimensions) -> CGFloat { dimensions.height / 2 }
}

extension VerticalAlignment {
    static let routeGridCenter = VerticalAlignment(RouteGridCenter.self)
}

/// Illustrations only: never generates or discloses a future deal. Each is a
/// subset of a legal Sudoku, with fewer clues as the route gets harder.
enum RoutePreviewGrid {
    static let solution = [
        5,3,4,6,7,8,9,1,2, 6,7,2,1,9,5,3,4,8, 1,9,8,3,4,2,5,6,7,
        8,5,9,7,6,1,4,2,3, 4,2,6,8,5,3,7,9,1, 7,1,3,9,2,4,8,5,6,
        9,6,1,5,3,7,2,8,4, 2,8,7,4,1,9,6,3,5, 3,4,5,2,8,6,1,7,9
    ]

    static func digits(for slot: PuzzleSlot, book: Book = .probably) -> [Int?] {
        let count = book.givens(for: slot.difficulty)
        let visible = Set((0..<count).map { ($0 * 37 + 1) % 81 })
        return solution.enumerated().map { visible.contains($0.offset) ? $0.element : nil }
    }
}
