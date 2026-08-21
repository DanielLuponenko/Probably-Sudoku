import SwiftUI
import ProbablySudokuEngine

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
        .accessibilityAddTraits(.isModal)
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
    @State private var selectedTopic: Topic = .handAndPool

    fileprivate enum Topic: String, CaseIterable, Identifiable {
        case handAndPool
        case rightAndWrong
        case turnsAndToss
        case targetsAndClears
        case cashOut
        case shop
        case markers
        case bosses
        case failure

        var id: String { rawValue }

        var heading: String {
            switch self {
            case .handAndPool: return "Hand & Pool"
            case .rightAndWrong: return "Right & wrong"
            case .turnsAndToss: return "Turns & Toss"
            case .targetsAndClears: return "Targets & clears"
            case .cashOut: return "Cash Out"
            case .shop: return "Shop & slots"
            case .markers: return "Markers"
            case .bosses: return "Bosses"
            case .failure: return "When a Book ends"
            }
        }

        var kicker: String {
            switch self {
            case .handAndPool: return "YOUR MATERIAL"
            case .rightAndWrong: return "THE RISK"
            case .turnsAndToss: return "THE CLOCK"
            case .targetsAndClears: return "THE POINT"
            case .cashOut: return "THE CHOICE"
            case .shop: return "BETWEEN PUZZLES"
            case .markers: return "ON THE BOARD"
            case .bosses: return "THE OBSTACLE"
            case .failure: return "THE STAKES"
            }
        }

        var lines: [String] {
            switch self {
            case .handAndPool: return [
                "Your Hand is what you can play now. The Pool contains every number not already on the board or in your Hand.",
                "A finished sudoku contains nine of each number, so the Pool can be counted if you pay attention."
            ]
            case .rightAndWrong: return [
                "Place a number on a Blank. A correct placement scores ten times that number.",
                "A wrong placement costs fifty times the number and sends it back to the Pool."
            ]
            case .turnsAndToss: return [
                "End Turn refills your Hand. Unplayed numbers carry over, so a good Hand is worth protecting.",
                "Toss sends a picked number back to the Pool. Its allowance is limited and the Hand does not refill until End Turn."
            ]
            case .targetsAndClears: return [
                "Each Puzzle has a target. Reach it before the final Turn to keep the Book alive.",
                "Rows, columns and 3×3 boxes pay much more than a single placement. Plan toward clears."
            ]
            case .cashOut: return [
                "After meeting the target, Cash Out banks the receipt and moves on safely.",
                "Keep Filling freezes the target score and lets clears bank extra coins, but uses the Turns you have left."
            ]
            case .shop: return [
                "The Shop appears between Puzzles. Bookmarks last the Book; Markers bind to a square; Buffs are one use.",
                "Slots are limited. Sell a Bookmark or Buff for a partial refund when the plan changes."
            ]
            case .markers: return [
                "Place a Marker on a Blank before its number lands. Its effect belongs to that square for this Book.",
                "Markers do not share squares, and some Bosses can make their marked squares harder to read."
            ]
            case .bosses: return [
                "The third Puzzle of each Level is a Boss encounter. It changes the rules of that Puzzle, not the Book's difficulty.",
                "Read the Boss stamp before playing: it tells you exactly which resource or board rule is under pressure."
            ]
            case .failure: return [
                "If a Puzzle fills below its target, the Book ends. There are exactly enough numbers for the Blanks, so it cannot recover.",
                "A completed Book unlocks the next one. Obstacles are a separate choice when you open a Book."
            ]
            }
        }
    }

    var body: some View {
        PaperSlip(title: "How to play",
                  subtitle: "Probably Sudoku, in the order you meet it.",
                  onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Text(selectedTopic.heading)
                        .font(Print.caption(10))
                        .textCase(.uppercase)
                        .tracking(0.9)
                        .foregroundStyle(Paper.page)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background(Paper.ink, in: RoundedRectangle(cornerRadius: 3))
                        .accessibilityLabel("How to play topic")
                        .accessibilityValue("\(selectedTopic.heading), \(selectedIndex + 1) of \(Topic.allCases.count)")
                }
                .padding(.bottom, 12)

                HelpTopicPage(topic: selectedTopic)

                HStack(spacing: 10) {
                    if selectedIndex > 0 {
                        PaperButton(title: "Previous", kind: .quiet) {
                            select(Topic.allCases[selectedIndex - 1])
                        }
                    }
                    if selectedIndex < Topic.allCases.count - 1 {
                        PaperButton(title: "Next", kind: .quiet) {
                            select(Topic.allCases[selectedIndex + 1])
                        }
                    }
                }
                .padding(.top, 14)
            }
        }
    }

    private var selectedIndex: Int {
        Topic.allCases.firstIndex(of: selectedTopic) ?? 0
    }

    private func select(_ topic: Topic) {
        withAnimation(.snappy(duration: 0.18)) { selectedTopic = topic }
    }
}

private struct HelpTopicPage: View {
    let topic: HelpSlip.Topic

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Image("Cover")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 96)
                .clipShape(.rect(cornerRadius: 3))
                .overlay(alignment: .bottomLeading) {
                    Text(topic.kicker)
                        .font(Print.caption(10))
                        .tracking(1.5)
                        .foregroundStyle(Paper.page)
                        .padding(9)
                        .background(.black.opacity(0.45))
                }
                .accessibilityHidden(true)

            Text(topic.heading)
                .font(Print.heading(21))
                .foregroundStyle(Paper.ink)

            ForEach(topic.lines, id: \.self) { line in
                Text(line)
                    .font(Print.body(14))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(topic.heading)
    }
}
