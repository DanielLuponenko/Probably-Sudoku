import SwiftUI
import NumberClubEngine

/// Everything true about the run right now, including what is still in the Pool.
///
/// §4 designs the Pool to be invisible — "never shown, never counted for you,
/// and has no tally anywhere" — on the grounds that it is knowable anyway
/// (nine of each digit, minus the board, minus your hand) and that working it
/// out is the game's deepest source of information. Showing it here is a
/// deliberate departure from that: the counting is done for the player.
struct RunInfoSlip: View {
    @Bindable var model: GameModel
    var onClose: () -> Void

    var body: some View {
        PaperSlip(title: "The run so far", subtitle: nil, onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                if let puzzle = model.puzzle {
                    SlipSection(title: "Still in the pool",
                                note: "Nine of each number exist in a finished grid. "
                                    + "What is left is nine, minus what is on the board, "
                                    + "minus what is in your hand.") {
                        PoolTally(puzzle: puzzle)
                    }

                    SlipSection(title: "This puzzle") {
                        LeaderRow(label: "Score", value: "\(puzzle.score.formatted()) of \(puzzle.target.formatted())")
                        LeaderRow(label: "Turns left", value: "\(puzzle.turnsRemaining)")
                        LeaderRow(label: "Tosses left", value: "\(puzzle.tossesRemaining)")
                        LeaderRow(label: "Clues", value: "\(puzzle.cluesRemaining)")
                        LeaderRow(label: "Blanks left", value: "\(puzzle.board.blanks.count)")
                        if let boss = puzzle.boss {
                            LeaderRow(label: boss.name, value: boss.attacks)
                        }
                    }
                }

                SlipSection(title: "This book") {
                    LeaderRow(label: "Level", value: "\(model.run.level) of 9")
                    LeaderRow(label: "Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    LeaderRow(label: "Coins", value: "\(model.coins)")
                    LeaderRow(label: "Clippings", value: "\(model.run.skipsUsed) used · \(model.run.skipsRemaining) left")
                }

                if !model.run.takenClippings.isEmpty {
                    SlipSection(title: "Clippings taken") {
                        ForEach(model.run.takenClippings) { clipping in
                            OwnedLine(name: clipping.name, detail: clipping.detail)
                        }
                    }
                }

                if !model.run.bookmarks.isEmpty {
                    SlipSection(title: "Bookmarks") {
                        ForEach(model.run.bookmarks) { ad in
                            OwnedLine(name: ad.def.name, detail: ad.def.text)
                        }
                    }
                }

                if !model.run.markers.isEmpty {
                    SlipSection(title: "Markers") {
                        ForEach(Array(model.run.markers.enumerated()), id: \.offset) { _, marker in
                            OwnedLine(
                                name: marker.def.name,
                                detail: marker.squares.isEmpty
                                    ? "No square yet"
                                    : marker.squares.map(\.description).joined(separator: ", "),
                                swatch: Paper.markerColor(marker.defID)
                            )
                        }
                    }
                }

                if !model.run.buffs.isEmpty {
                    SlipSection(title: "Buffs") {
                        ForEach(Array(model.run.buffs.enumerated()), id: \.offset) { _, buff in
                            OwnedLine(name: buff.def.name, detail: buff.def.text)
                        }
                    }
                }

                if !model.run.subscriptions.isEmpty {
                    SlipSection(title: "Subscriptions") {
                        ForEach(model.run.subscriptions) { subscription in
                            OwnedLine(name: subscription.def.name, detail: subscription.def.text)
                        }
                    }
                }
            }
        }
    }
}

/// How many of each number are still to come, as `9 x 5`.
private struct PoolTally: View {
    var puzzle: PuzzleState

    private let columns = [GridItem(.adaptive(minimum: 62), spacing: 8)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Digit.all, id: \.self) { digit in
                    let count = puzzle.poolCount(of: digit)
                    HStack(spacing: 4) {
                        Text("\(digit.rawValue)")
                            .font(Print.numeral(19, weight: .semibold))
                            .foregroundStyle(count > 0 ? Paper.ink : Paper.inkFaint)
                        Text("x")
                            .font(Print.body(11))
                            .foregroundStyle(Paper.inkFaint)
                        Text("\(count)")
                            .font(Print.numeral(17, weight: .bold))
                            .foregroundStyle(count > 0 ? Paper.sageDeep : Paper.inkFaint)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(count > 0 ? Paper.pageWarm : Paper.pageWarm.opacity(0.4))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Paper.rule.opacity(count > 0 ? 1 : 0.4), lineWidth: 1)
                    }
                    .accessibilityLabel("\(count) \(digit.rawValue)s left in the pool")
                }
            }

            HStack {
                Text("Total")
                    .font(Print.caption(11)).tracking(1.2).textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                Spacer()
                Text("\(puzzle.pool.total)")
                    .font(Print.numeral(15, weight: .bold))
                    .foregroundStyle(Paper.ink)
            }
        }
    }
}

private struct OwnedLine: View {
    var name: String
    var detail: String
    var swatch: Color?

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if let swatch {
                RoundedRectangle(cornerRadius: 2)
                    .fill(swatch)
                    .frame(width: 12, height: 12)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(Print.subheading(13))
                    .foregroundStyle(Paper.ink)
                Text(detail)
                    .font(Print.body(11.5))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
