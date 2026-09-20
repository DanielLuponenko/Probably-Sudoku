import ProbablySudokuEngine

/// Read-only text shared by a held board square and the question-mark map.
/// Only public board state is read: inspection never consults the solution,
/// resolves an effect, or touches a random stream.
struct MarkerInspectionInfo {
    enum Availability: Equatable {
        case available
        case givenCovered
        case filled
        case temporarilyBarred
        case betweenPuzzles
    }

    let marker: OwnedMarker
    let square: Square
    let availability: Availability

    var title: String { marker.def.name }
    var explanation: String { marker.def.text }
    /// The held popup stays readable; the question-mark map retains full rules.
    /// Jade's explicit penalty distinction is essential even in a short read.
    var compactExplanation: String {
        if marker.defID == Markers.jade { return explanation }
        return CatalogueDetails.item(marker.defID)?.shortEffect ?? explanation
    }

    /// The board already shows occupancy. Only ambiguous restrictions need
    /// an extra note in the compact, held explanation.
    var inspectionNotice: String? {
        switch availability {
        case .givenCovered: return "Inactive under a given."
        case .temporarilyBarred: return "Temporarily barred."
        case .available, .filled, .betweenPuzzles: return nil
        }
    }

    var availabilityText: String {
        switch availability {
        case .available:
            return "This square is available."
        case .givenCovered:
            return "A printed number covers this square, so this Marker cannot trigger here in this puzzle. It stays yours for later puzzles."
        case .filled:
            return "This square is filled and cannot take another number. Effects already earned keep their stated duration."
        case .temporarilyBarred:
            return "This square is temporarily barred. Its Marker can trigger when the square becomes available again."
        case .betweenPuzzles:
            return "This position stays marked for later puzzles."
        }
    }

    static func visibleMarkers(in run: RunState) -> [Square: OwnedMarker] {
        guard run.puzzle?.boss?.hidesMarkedSquares != true else { return [:] }
        return run.markedSquares
    }

    static func make(square: Square, run: RunState) -> MarkerInspectionInfo? {
        guard let marker = visibleMarkers(in: run)[square] else { return nil }
        let availability: Availability
        if let puzzle = run.puzzle {
            if puzzle.board.filledBy[square.index] == .given {
                availability = .givenCovered
            } else if puzzle.board[square] != nil {
                availability = .filled
            } else if puzzle.isBarred(square) {
                availability = .temporarilyBarred
            } else {
                availability = .available
            }
        } else {
            availability = .betweenPuzzles
        }
        return MarkerInspectionInfo(marker: marker, square: square, availability: availability)
    }
}
