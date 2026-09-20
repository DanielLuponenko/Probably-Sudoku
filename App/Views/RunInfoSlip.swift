import SwiftUI
import ProbablySudokuEngine

/// The current run, owned effects and earned history. The draw Pool stays hidden.
struct RunInfoSlip: View {
    @Bindable var model: GameModel
    var onClose: () -> Void
    @State private var showingLastScore = false

    var body: some View {
        PaperSlip(title: "The run so far", subtitle: nil, onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                SlipSection(title: "Your Marker board") {
                    RunMarkerBoard(run: model.run)
                }
                if !CatalogueReadings(run: model.run).isEmpty {
                    SlipSection(title: "Active readings") { CatalogueReadingsView(run: model.run) }
                }
                if let puzzle = model.puzzle {
                    SlipSection(title: "This puzzle") {
                        LeaderRow(label: "Score", value: "\(puzzle.score.formatted()) of \(puzzle.target.formatted())")
                        LeaderRow(label: "Turns left", value: "\(puzzle.turnsRemaining)")
                        LeaderRow(label: "Tosses left", value: "\(puzzle.tossesRemaining)")
                        LeaderRow(label: "Clues", value: "\(puzzle.cluesRemaining)")
                        LeaderRow(label: "Blanks left", value: "\(puzzle.board.blanks.count)")
                        if let boss = puzzle.boss {
                            LeaderRow(label: boss.name, value: boss.attacks)
                        }
                        if puzzle.scoringVersion < 2 {
                            Text("This saved Turn keeps its original scoring. Ordered scoring starts next Turn.")
                                .font(Print.body(12))
                        }
                        if puzzle.lastScoringLedger != nil {
                            PaperButton(title: "Last Turn's score", subtitle: "See each scoring step", kind: .quiet) {
                                showingLastScore = true
                            }
                            .accessibilityIdentifier("run-info.last-score")
                        }
                    }
                }

                SlipSection(title: "This book") {
                    LeaderRow(label: "Level", value: "\(model.run.level) of 9")
                    LeaderRow(label: "Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    LeaderRow(label: "Coins", value: "\(model.coins)")
                    LeaderRow(label: "Puzzles skipped", value: "\(model.run.skipsUsed)")
                }

                if !model.run.skipHistory.isEmpty {
                    SlipSection(title: "Skip rewards") {
                        ForEach(model.run.skipHistory) { record in
                            OwnedLine(name: record.offer.buff.name,
                                      detail: "Level \(record.level), Puzzle \(record.slot.rawValue + 1) · \(record.offer.buff.text)")
                        }
                    }
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
                            if ad.defID == Bookmarks.recycledInsert, model.shop != nil, model.canReopenRecycledChoice(bookmarkID: ad.id) {
                                PaperButton(title: "Choose a free Buff", kind: .quiet) {
                                    model.reopenRecycledChoice(bookmarkID: ad.id)
                                    onClose()
                                }
                            }
                        }
                    }
                }

                if !model.run.buffs.isEmpty {
                    SlipSection(title: "Buffs") {
                        ForEach(model.run.buffs) { buff in
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
        .paperPanel(isPresented: $showingLastScore) {
            if let ledger = model.puzzle?.lastScoringLedger {
                ScoreLedgerSlip(ledger: ledger) { showingLastScore = false }
            }
        }
    }
}

private struct OwnedLine: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
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
                    .font(Print.subheading(13 * textScale))
                    .foregroundStyle(theme.paper.ink)
                Text(detail)
                    .font(Print.body(11.5 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}
