import Foundation
import ProbablySudokuEngine

/// Ephemeral receipts, never a second scoring system or part of a saved run.
struct ScorePerformance: Identifiable {
    struct Beat: Identifiable {
        enum Kind { case points, multiplier, coins, queued, bank }
        let id = UUID()
        var source: String
        var value: String
        var kind: Kind
        var sourceID: String? = nil
        var square: Square? = nil
        var queuedBase: Int? = nil
    }

    let id = UUID()
    var beats: [Beat]
    var bankedFrom: Int? = nil
    var finalScore: Int? = nil
    var queuedFrom: Int? = nil
    var summary: String { beats.map { "\($0.source), \($0.value)" }.joined(separator: ". ") }

    static func placement(_ outcome: PlacementOutcome, square: Square,
                          previousScore: Int, finalScore: Int, previousQueue: Int = 0) -> Self {
        var beats: [Beat] = []
        var queue = previousQueue
        for receipt in outcome.scoreReceipts {
            let label = receipt.event == .place ? "Number placed"
                : receipt.event == .lineClear ? "Line complete" : "Full board"
            beats.append(Beat(source: label, value: signed(receipt.base), kind: .points,
                              square: receipt.event == .place ? square : nil))
            beats += contributionBeats(receipt.contributions)
            // The resolver's result includes square multipliers, rounding and
            // one-shots. Never invent a running sum from raw hook deltas.
            queue += receipt.points
            beats.append(Beat(source: "Added to queue", value: signed(receipt.points), kind: .queued,
                              queuedBase: queue))
        }
        if let turn = outcome.automaticTurn {
            let bank = banking(turn, previousScore: previousScore, finalScore: finalScore)
            beats += bank.beats
            return Self(beats: beats, bankedFrom: previousScore, finalScore: finalScore,
                        queuedFrom: previousQueue)
        }
        return Self(beats: beats, queuedFrom: previousQueue)
    }

    static func banking(_ turn: Actions.TurnResult, previousScore: Int, finalScore: Int) -> Self {
        guard turn.pointsGained != 0 else { return Self(beats: []) }
        var beats = [Beat(source: "Turn points", value: turn.queuedBase.formatted(), kind: .points)]
        if turn.multiplier != 1 {
            beats.append(Beat(source: "Turn multiplier", value: "×\(number(turn.multiplier))", kind: .multiplier))
        }
        beats += contributionBeats(turn.contributions)
        beats.append(Beat(source: "BANKED", value: signed(turn.pointsGained), kind: .bank, queuedBase: 0))
        return Self(beats: beats, bankedFrom: previousScore, finalScore: finalScore)
    }

    private static func contributionBeats(_ contributions: [ScoreContribution]) -> [Beat] {
        contributions.flatMap { contribution -> [Beat] in
            var result: [Beat] = []
            func append(_ value: String, _ kind: Beat.Kind) {
                result.append(Beat(source: contribution.name, value: value, kind: kind,
                                   sourceID: contribution.sourceID))
            }
            if contribution.flat != 0 { append(signed(contribution.flat), .points) }
            if contribution.multAdd != 0 { append("+\(number(contribution.multAdd)) mult", .multiplier) }
            if contribution.multX != 1 { append("×\(number(contribution.multX))", .multiplier) }
            if contribution.directScore != 0 { append(signed(contribution.directScore), .points) }
            if contribution.coins != 0 { append("\(signed(contribution.coins)) coins", .coins) }
            return result
        }
    }

    private static func signed(_ value: Int) -> String { value >= 0 ? "+\(value.formatted())" : value.formatted() }
    private static func number(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...2))) }
}
