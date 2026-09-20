import ProbablySudokuEngine

/// A pure presentation snapshot of information the player has already paid to
/// reveal. Reading it cannot consume a token, advance RNG, or inspect a solution.
struct CatalogueReadings: Equatable {
    struct Row: Identifiable, Equatable {
        let id: String
        let label: String
        let value: String
    }

    struct Reading: Identifiable, Equatable {
        let id: String
        let title: String
        let scope: String
        let rows: [Row]
        let usesCountGrid: Bool
    }

    let entries: [Reading]
    var isEmpty: Bool { entries.isEmpty }

    init(run: RunState, visibleValues: [Digit?]? = nil) {
        guard let puzzle = run.puzzle, puzzle.phase == .playing else {
            entries = []; return
        }
        // `placed` is the board shown to the player, not its hidden solution.
        // Callers concealing board values can supply their actual visible grid.
        let visible = visibleValues ?? puzzle.board.placed
        var result: [Reading] = []
        func append(_ definition: String, scope: String, rows: [Row], countGrid: Bool = false) {
            guard !rows.isEmpty, let item = Catalog.item(definition) else { return }
            result.append(Reading(id: definition, title: item.name, scope: scope,
                                  rows: rows, usesCountGrid: countGrid))
        }
        func coordinate(_ square: Square) -> String { "R\(square.row + 1) C\(square.col + 1)" }
        func candidates(_ digits: [Digit]) -> String {
            digits.isEmpty ? "No candidates" : digits.map { String($0.rawValue) }.joined(separator: " · ")
        }
        if let counts = BuffRuntime.poolCounts(puzzle) {
            append(Buffs.inventoryCount, scope: "Pool counts · this Turn", rows: Digit.all.map {
                Row(id: String($0.rawValue), label: String($0.rawValue), value: String(counts[$0, default: 0]))
            }, countGrid: true)
        }
        if let proof = puzzle.buffState.proof, proof.turn == puzzle.turnNumber {
            let unit: String
            switch proof.unit { case .row: unit = "Row"; case .col: unit = "Column"; case .box: unit = "Box" }
            let values = BuffRuntime.proofCandidates(puzzle: puzzle, visibleValues: visible)
            append(Buffs.proofSheet, scope: "\(unit) \(proof.index + 1) · visible candidates · this Turn",
                   rows: values.keys.sorted().map {
                Row(id: String($0.index), label: coordinate($0), value: candidates(values[$0, default: []]))
            })
        }
        let parity = puzzle.buffState.parity.filter { puzzle.board.isBlank($0.key) }
        append(Buffs.foldTest, scope: "Until these squares are filled", rows: parity.keys.sorted().map {
            Row(id: String($0.index), label: coordinate($0), value: parity[$0] == true ? "Even" : "Odd")
        })

        // Fog conceals Marker identity, locations, and their information hooks.
        // Independently purchased Buff readings above remain available.
        if puzzle.boss?.hidesMarkedSquares != true {
            if let digit = MarkerRuntime.forecast(run: run, puzzle: puzzle) {
                append(Markers.forecast, scope: "Until the next random draw or Turn end", rows: [
                    Row(id: "next", label: "Next Pool draw", value: String(digit.rawValue))
                ])
            }
            if let census = MarkerRuntime.census(puzzle: puzzle) {
                append(Markers.census, scope: "Pool count · this Turn", rows: [
                    Row(id: "count", label: String(census.digit.rawValue), value: String(census.count))
                ], countGrid: true)
            }
            if let target = puzzle.markerState.turn.crosscheck, puzzle.board.isBlank(target.square) {
                append(Markers.crosscheck, scope: "Visible candidates · this Turn", rows: [
                    Row(id: String(target.square.index), label: coordinate(target.square),
                        value: candidates(MarkerRuntime.visibleCandidates(at: target.square, puzzle: puzzle,
                                                                         visibleValues: visible)))
                ])
            }
            if let target = puzzle.markerState.turn.bounty, puzzle.board.isBlank(target.square) {
                append(Markers.bounty, scope: "Correct placement without a Clue · this Turn", rows: [
                    Row(id: String(target.square.index), label: coordinate(target.square), value: "+120 Points")
                ])
            }
        }
        entries = result
    }
}
