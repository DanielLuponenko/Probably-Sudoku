import SwiftUI
import NumberClubEngine

/// Everything that is about the run rather than in it: where you are, how to
/// leave, and how the game works.
struct SettingsView: View {
    @Bindable var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingNewBook = false
    @State private var showingHelp = false
    #if DEBUG
    @State private var showingQA = false
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Level", value: "\(model.run.level) of 9")
                    LabeledContent("Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    LabeledContent("Coins", value: "\(model.coins)")
                } header: {
                    Text("This Book")
                }

                Section {
                    LabeledContent("Seed", value: model.run.seed)
                    Button {
                        UIPasteboard.general.string = model.run.seed
                    } label: {
                        Label("Copy seed", systemImage: "doc.on.doc")
                    }
                } footer: {
                    Text("A Book is decided entirely by its seed and the choices you make, "
                         + "so the same seed played the same way gives the same Book.")
                }

                Section {
                    Button {
                        showingHelp = true
                    } label: {
                        Label("How to play", systemImage: "questionmark.circle")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        confirmingNewBook = true
                    } label: {
                        Label("Abandon Book and start again", systemImage: "arrow.counterclockwise")
                    }
                } footer: {
                    Text("Ads, Markers and Buffs do not carry over, Marker stacks reset, "
                         + "and coins go back to the starting amount.")
                }

                #if DEBUG
                Section("Development") {
                    Button {
                        showingQA = true
                    } label: {
                        Label("QA tools", systemImage: "hammer")
                    }
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Abandon this Book?",
                                isPresented: $confirmingNewBook,
                                titleVisibility: .visible) {
                Button("Abandon and start a new Book", role: .destructive) {
                    model.startNewBook()
                    dismiss()
                }
                Button("Keep playing", role: .cancel) {}
            } message: {
                Text("Level \(model.run.level), Puzzle \(model.run.slot.rawValue + 1). "
                     + "Everything you have bought is lost.")
            }
            .sheet(isPresented: $showingHelp) { HelpView() }
            #if DEBUG
            .sheet(isPresented: $showingQA) { QAPanel(model: model) }
            #endif
        }
    }
}

/// The rules, in the order you meet them.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("The idea") {
                    Text("You are filling a sudoku for points, not for completion. "
                         + "Each Puzzle sets a score target you have to beat within a "
                         + "fixed number of Turns.")
                }

                Section("Numbers") {
                    Text("Numbers arrive at random from the Pool. Place one on a Blank: "
                         + "a correct placement scores ten times the number, a wrong one "
                         + "costs fifty times it and goes back.")
                    Text("Completing a row, column or box is worth far more than a "
                         + "placement, so the board is where the points are.")
                    Text("The Pool is never shown — but a finished sudoku holds each digit "
                         + "nine times, so what is left is always nine minus what is on the "
                         + "board minus what is in your hand. Counting is the edge the game "
                         + "does not hand you.")
                }

                Section("A Turn") {
                    Text("Ending a Turn refills your hand. Unplaced numbers carry over.")
                    Text("Toss returns numbers to the Pool, up to the allowance each Turn. "
                         + "The hand only refills at the end of a Turn, so tossing costs "
                         + "tempo.")
                }

                Section("Between Puzzles") {
                    Text("Beat the target and you choose: bank the payout, or keep filling "
                         + "for coins with the Turns you have left.")
                    Text("The Shop sells Ads, which run for the whole Book, Markers, which "
                         + "mark a square so whatever lands there scores more, and Buffs, "
                         + "which are used once.")
                    Text("Targets double every Level, so multipliers are not a luxury.")
                }

                Section("Losing") {
                    Text("Miss a target and the Book ends. There are exactly as many "
                         + "numbers as there are Blanks, so a board that fills below target "
                         + "cannot be recovered.")
                }
            }
            .navigationTitle("How to play")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
