import SwiftUI

/// Settings for the app, as opposed to settings for a Book.
///
/// Separate from `SettingsSlip` on purpose: that one is built round a
/// `GameModel` and offers to abandon the run, print its seed and count its
/// coins. None of that exists at the front door, and a settings screen that
/// says "Level 0 of 9" is worse than no settings screen at all.
///
/// Nothing here is a switch that does nothing. If the game gains music, the
/// music row arrives with it.
struct AppSettingsSlip: View {
    var onClose: () -> Void

    @AppStorage(AppPreferences.Key.haptics) private var haptics = true
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingHelp = false

    var body: some View {
        PaperSlip(title: "Settings",
                  subtitle: "The Number Club, everywhere — not just this Book.",
                  onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                SlipSection(title: "The room") {
                    SlipToggle(label: "Haptics",
                               note: "What the buttons and the board feel like.",
                               isOn: $haptics)
                    SlipToggle(label: "Ambient animation",
                               note: "The lamp, the dust and the plant. The numbers stay "
                                   + "either way.",
                               isOn: $ambientMotion)
                }

                if reduceMotion {
                    SlipSection(title: "Reduce Motion") {
                        Text("Reduce Motion is on in iOS, so the room is already still. "
                             + "That setting always wins — this slip cannot turn movement "
                             + "back on, and should not pretend to.")
                            .font(Print.body(12.5))
                            .foregroundStyle(Paper.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                SlipSection(title: "The rules") {
                    PaperButton(title: "How to play", kind: .quiet) { showingHelp = true }
                }

                SlipSection(title: "Accessibility",
                            note: "Every number, price and label in the game is live text, so "
                                + "Dynamic Type, VoiceOver and Increase Contrast all reach it. "
                                + "The room itself is scenery and is skipped by VoiceOver.") {
                    EmptyView()
                }

                SlipSection(title: "The club") {
                    LeaderRow(label: "Version", value: Self.version)
                    LeaderRow(label: "Numbers", value: "1 to 9")
                }
            }
        }
        .overlay {
            if showingHelp {
                HelpSlip { withAnimation(.snappy(duration: 0.2)) { showingHelp = false } }
            }
        }
        .animation(.snappy(duration: 0.22), value: showingHelp)
    }

    private static var version: String {
        let marketing = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return marketing ?? "0.1"
    }
}
/// A printed checkbox with a pencil tick in it. A system `Toggle` here would
/// be the one iOS control in a room made of wood and paper.
struct SlipToggle: View {
    var label: String
    var note: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
            if isOn { Haptics.menuOpen() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 11) {
                box
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Print.body(14))
                        .foregroundStyle(Paper.ink)
                    if let note {
                        Text(note)
                            .font(Print.body(11.5))
                            .foregroundStyle(Paper.inkFaint)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: 2)
            .strokeBorder(Paper.rule, lineWidth: 1.2)
            .background(RoundedRectangle(cornerRadius: 2).fill(Paper.pageWarm))
            .frame(width: 20, height: 20)
            .overlay {
                if isOn {
                    Tick()
                        .stroke(Paper.sageDeep,
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                                   lineJoin: .round))
                        .padding(4)
                }
            }
            .offset(y: 2)
    }
}

/// A tick, drawn the way one is drawn: down, then up and out past the box.
private struct Tick: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.14, y: rect.minY - rect.height * 0.2))
        return path
    }
}
