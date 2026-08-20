import SwiftUI
import NumberClubEngine

/// Anything that is about the run rather than in it is printed on a slip and
/// laid on the desk over the book. A system settings list would be the one
/// place the game stops being an object.
struct PaperSlip<Content: View>: View {
    var title: String
    var subtitle: String?
    var closeLabel: String = "Close"
    /// Tapping the desk behind the slip puts it down. Off for slips that are
    /// asking a question rather than showing something.
    var dismissesOnBackground: Bool = true
    var onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            // The desk dims, the way it would under a lamp turned to the slip.
            Rectangle()
                .fill(.black.opacity(0.55))
                .ignoresSafeArea()
                .onTapGesture { if dismissesOnBackground { onClose() } }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).pageHeading(26)
                    if let subtitle {
                        Text(subtitle)
                            .font(Print.body(12.5))
                            .foregroundStyle(Paper.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Rectangle().fill(Paper.rule).frame(height: 1).padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                ScrollView {
                    content
                        .padding(.horizontal, 18)
                        .padding(.bottom, 14)
                }

                PaperButton(title: closeLabel, kind: .quiet, action: onClose)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
            }
            .frame(maxHeight: 620)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Paper.page)
                    .overlay { PaperGrain(opacity: 0.06) }
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Paper.pageEdge, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.55), radius: 26, x: 4, y: 14)
            }
            .padding(.horizontal, 22)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }
}

/// A printed index line: label, dotted leader, value.
struct LeaderRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(Print.body(13.5))
                .foregroundStyle(Paper.ink)
                .layoutPriority(1)
            Line()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [1.5, 3.5]))
                .foregroundStyle(Paper.rule)
                .frame(height: 1)
                .offset(y: -3)
            Text(value)
                .font(Print.numeral(13.5, weight: .semibold))
                .foregroundStyle(Paper.inkSoft)
                .layoutPriority(1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// A small heading printed above a group, the way a form is sectioned.
struct SlipSection<Content: View>: View {
    var title: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Print.caption(10)).tracking(1.6).textCase(.uppercase)
                    .foregroundStyle(Paper.inkFaint)
                Rectangle().fill(Paper.rule.opacity(0.5)).frame(height: 1)
            }
            content
            if let note {
                Text(note)
                    .font(Print.body(11.5))
                    .foregroundStyle(Paper.inkFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 14)
    }
}

// MARK: - Settings

struct SettingsSlip: View {
    @Bindable var model: GameModel
    var onClose: () -> Void
    @State private var confirmingAbandon = false
    @State private var showingHelp = false
    @State private var copied = false
    #if DEBUG
    @State private var showingQA = false
    #endif

    var body: some View {
        PaperSlip(title: "Settings", subtitle: nil, onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                SlipSection(title: "This Book") {
                    LeaderRow(label: "Level", value: "\(model.run.level) of 9")
                    LeaderRow(label: "Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    LeaderRow(label: "Coins", value: "\(model.coins)")
                    LeaderRow(label: "Board", value: model.run.startingBoard.name)
                }

                SlipSection(
                    title: "Seed",
                    note: "A Book is decided by its seed and the choices you make, so the "
                        + "same seed played the same way gives the same Book."
                ) {
                    HStack(spacing: 10) {
                        Text(model.run.seed)
                            .font(Print.numeral(17, weight: .bold))
                            .foregroundStyle(Paper.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 3).fill(Paper.pageWarm)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Paper.rule, lineWidth: 1)
                            }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = model.run.seed
                            withAnimation { copied = true }
                        } label: {
                            Text(copied ? "Copied" : "Copy")
                                .font(Print.caption(12))
                                .textCase(.uppercase)
                                .tracking(0.8)
                                .foregroundStyle(Paper.ink)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(Paper.rule, lineWidth: 1)
                                }
                        }
                        .buttonStyle(PressedPaperStyle())
                    }
                }

                SlipSection(title: "The rules") {
                    PaperButton(title: "How to play", kind: .quiet) { showingHelp = true }
                }

                SlipSection(
                    title: "This run",
                    note: confirmingAbandon
                        ? nil
                        : "Throws the Book away. Bookmarks, Markers and Buffs do not carry "
                          + "over, Marker stacks reset, and coins go back to the starting "
                          + "amount."
                ) {
                    if confirmingAbandon {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("Abandon Level \(model.run.level), Puzzle "
                                 + "\(model.run.slot.rawValue + 1)? The Book is thrown away "
                                 + "and cannot be continued.")
                                .font(Print.body(12.5))
                                .foregroundStyle(Paper.redPencil)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 10) {
                                PaperButton(title: "Keep playing", kind: .quiet) {
                                    withAnimation { confirmingAbandon = false }
                                }
                                PaperButton(title: "Abandon", kind: .danger) {
                                    onClose()
                                    model.abandonRun()
                                }
                            }
                        }
                    } else {
                        PaperButton(title: "Abandon Book", kind: .danger) {
                            withAnimation { confirmingAbandon = true }
                        }
                    }
                }

                #if DEBUG
                SlipSection(title: "Development") {
                    PaperButton(title: "QA tools", kind: .quiet) { showingQA = true }
                }
                #endif
            }
        }
        #if DEBUG
        .sheet(isPresented: $showingQA) { QAPanel(model: model) }
        .overlay {
            if showingHelp {
                HelpSlip { withAnimation(.snappy(duration: 0.2)) { showingHelp = false } }
            }
        }
        .animation(.snappy(duration: 0.22), value: showingHelp)
        #endif
    }
}

// MARK: - Help

/// The rules, in the order you meet them.
struct HelpSlip: View {
    var onClose: () -> Void

    private struct Rule: Identifiable {
        let id = UUID()
        let heading: String
        let lines: [String]
    }

    private let rules: [Rule] = [
        Rule(heading: "The idea", lines: [
            "You are filling a sudoku for points, not for completion. Each Puzzle sets a "
            + "score target you have to beat within a fixed number of Turns.",
        ]),
        Rule(heading: "Numbers", lines: [
            "Numbers arrive at random from the Pool. Place one on a Blank: a correct "
            + "placement scores ten times the number, a wrong one costs fifty times it "
            + "and goes back.",
            "Completing a row, column or box is worth far more than a placement, so the "
            + "board is where the points are.",
            "The Pool is never shown. But a finished sudoku holds each digit nine times, "
            + "so what is left is nine, minus what is on the board, minus what is in your "
            + "hand. Counting is the one edge the game does not hand you.",
        ]),
        Rule(heading: "A Turn", lines: [
            "Ending a Turn refills your hand. Unplaced numbers carry over.",
            "Toss returns numbers to the Pool, up to the allowance each Turn. The hand "
            + "only refills at the end of a Turn, so tossing is paid for in tempo.",
        ]),
        Rule(heading: "Between Puzzles", lines: [
            "Beat the target and you choose: bank the payout, or keep filling for coins "
            + "with the Turns you have left.",
            "The Shop sells Bookmarks, which run for the whole Book; Markers, which mark a "
            + "square so whatever lands there scores more; and Buffs, used once.",
            "Targets double every Level, so multipliers are not a luxury.",
        ]),
        Rule(heading: "Losing", lines: [
            "Miss a target and the Book ends. There are exactly as many numbers as there "
            + "are Blanks, so a board that fills below target cannot be recovered.",
        ]),
    ]

    var body: some View {
        PaperSlip(title: "How to play",
                  subtitle: "The Number Club, in the order you meet it.",
                  onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(rules) { rule in
                    SlipSection(title: rule.heading) {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(rule.lines, id: \.self) { line in
                                Text(line)
                                    .font(Print.body(13))
                                    .foregroundStyle(Paper.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
