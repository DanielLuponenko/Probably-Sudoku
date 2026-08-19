#if DEBUG
import SwiftUI
import NumberClubEngine

/// Shortcuts for exercising the game by hand. Debug builds only — the whole
/// file is compiled out of a release build, as are the engine calls behind it.
/// Deliberately styled as a tester's tool rather than as part of the book, so
/// it can never be mistaken for a feature.
struct QAPanel: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Score") {
                    row("Add 1,000 points", "plus.circle") { model.qaAward(points: 1_000) }
                    row("Add 10,000 points", "plus.circle.fill") { model.qaAward(points: 10_000) }
                    row("Meet the target", "target") { model.qaMeetTarget() }
                    row("Fail the Puzzle", "xmark.circle", destructive: true) {
                        model.qaFailPuzzle()
                    }
                }

                Section("Coins") {
                    row("Add 1,000 coins", "circle.circle") { model.qaAward(coins: 1_000) }
                }

                Section {
                    row("Fill the board", "square.grid.3x3.fill") { model.qaFillBoard() }
                } header: {
                    Text("Board")
                } footer: {
                    Text("Fills every Blank from the Pool without scoring — for reaching "
                         + "the Full Clear and the results page, not for checking their value.")
                }

                Section("Run") {
                    row("New Book", "book.closed") { model.startNewBook() }
                }

                Section("State") {
                    LabeledContent("Seed", value: model.run.seed)
                    LabeledContent("Level", value: "\(model.run.level)")
                    LabeledContent("Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    if let puzzle = model.puzzle {
                        LabeledContent("Score", value: "\(puzzle.score) / \(puzzle.target)")
                        LabeledContent("Turn", value: "\(puzzle.turnNumber) of \(puzzle.turnsMax)")
                        LabeledContent("Phase", value: puzzle.phase.rawValue)
                        LabeledContent("Pool", value: "\(puzzle.pool.total) left")
                        if let boss = puzzle.boss {
                            LabeledContent("Boss", value: boss.name)
                        }
                    }
                    LabeledContent("Coins", value: "\(model.coins)")
                }
            }
            .navigationTitle("QA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ symbol: String,
                     destructive: Bool = false,
                     action: @escaping () -> Void) -> some View {
        Button {
            action()
            dismiss()
        } label: {
            Label(title, systemImage: symbol)
        }
        .foregroundStyle(destructive ? Color.red : Color.accentColor)
    }
}
#endif
