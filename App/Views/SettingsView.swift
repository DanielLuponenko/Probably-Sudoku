import SwiftUI
import ProbablySudokuEngine

/// Anything that is about the run rather than in it is printed on a slip and
/// laid on the desk over the book. A system settings list would be the one
/// place the game stops being an object.
struct PaperSlip<Content: View>: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var cardHasAppeared = false
    @ScaledMetric(relativeTo: .title2) private var headingSize: CGFloat = 22
    @ScaledMetric(relativeTo: .subheadline) private var subtitleSize: CGFloat = 13
    var title: String
    var subtitle: String?
    var closeLabel: String = "Close"
    var showsCloseButton: Bool = true
    /// Tapping the desk behind the slip puts it down. Off for slips that are
    /// asking a question rather than showing something.
    var dismissesOnBackground: Bool = true
    /// Native sheets already dim the underlying Book; never stack two veils.
    var dimsBackground = true
    var closeAccessibilityID: String? = nil
    var revealsCardOnArrival = false
    var maximumWidth: CGFloat? = 440
    var maximumHeight: CGFloat = 620
    /// Short decisions should look like slips, not empty full-page articles.
    /// Long content still falls back to scrolling within the available height.
    var fitsContent = true
    /// A small, stable optional footer keeps guide navigation outside the
    /// scrolling article. Existing slips retain their original layout.
    var footer: AnyView? = nil
    var onClose: () -> Void
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            // The desk dims, the way it would under a lamp turned to the slip.
            if dimsBackground {
                Rectangle()
                    .fill(.black.opacity(0.48))
                    .ignoresSafeArea()
                    .onTapGesture { if dismissesOnBackground { onClose() } }
                    .accessibilityHidden(true)
            }

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).pageHeading(headingSize)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle {
                        Text(subtitle)
                            .font(Print.body(subtitleSize))
                            .foregroundStyle(theme.paper.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Rectangle().fill(theme.paper.ruleInk).frame(height: 1).padding(.top, 3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 12)

                if fitsContent {
                    ViewThatFits(in: .vertical) {
                        paddedContent.fixedSize(horizontal: false, vertical: true)
                        ScrollView { paddedContent }
                    }
                } else {
                    ScrollView { paddedContent }
                }

                if let footer {
                    footer
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }

                if showsCloseButton {
                    PaperButton(title: closeLabel, kind: .quiet, action: onClose)
                        .accessibilityIdentifier(closeAccessibilityID ?? "paper-slip.close")
                        .padding(.horizontal, 18)
                        .padding(.bottom, 18)
                }
            }
            .frame(maxWidth: maximumWidth)
            .paperSurface(kind: .slip)
            // Constrain the proposal without painting the constraint's empty
            // space as paper. Content-fitting decisions keep their own height;
            // scrolling articles still fill the capped height as before.
            .frame(maxHeight: dimsBackground ? maximumHeight : nil)
            .padding(.horizontal, dimsBackground ? 22 : 0)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
            .accessibilityAction(.escape) {
                if showsCloseButton || dismissesOnBackground { onClose() }
            }
            // Only the new card fades in. Its dimming layer stays steady, and
            // no removed Settings/Help modal is retained for a crossfade.
            .opacity(revealsCardOnArrival && !cardHasAppeared ? 0 : 1)
            .onAppear {
                guard revealsCardOnArrival else { return }
                withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.12)) {
                    cardHasAppeared = true
                }
            }
        }
        // A full-screen dimming layer must not shrink with the paper and
        // expose an undimmed border. Fade the slip in place on every device;
        // its presenter shortens this same non-spatial motion for Reduce Motion.
        .transition(.opacity)
    }

    private var paddedContent: some View {
        content
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
    }
}

/// A printed index line: label, dotted leader, value.
struct LeaderRow: View {
    @Environment(\.cosmeticTheme) private var theme
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(Print.body(13.5))
                .foregroundStyle(theme.paper.ink)
                .layoutPriority(1)
            Line()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [1.5, 3.5]))
                .foregroundStyle(theme.paper.ruleInk)
                .frame(height: 1)
                .offset(y: -3)
            Text(value)
                .font(Print.numeral(13.5, weight: .semibold))
                .foregroundStyle(theme.paper.softInk)
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
    @Environment(\.cosmeticTheme) private var theme
    var title: String
    var note: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title)
                    .font(Print.caption(10)).tracking(1.6).textCase(.uppercase)
                    .foregroundStyle(theme.paper.faintInk)
                Rectangle().fill(theme.paper.ruleInk.opacity(0.5)).frame(height: 1)
            }
            content
            if let note {
                Text(note)
                    .font(Print.body(11.5))
                    .foregroundStyle(theme.paper.faintInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, 14)
    }
}

// MARK: - Settings

struct SettingsSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: GameModel
    var onAbandon: () -> Void
    var onClose: () -> Void
    @State private var confirmingAbandon = false
    @State private var copied = false
    @State private var showingBookDetails = false
    #if DEBUG && targetEnvironment(simulator)
    @State private var showingQA = false
    #endif

    var body: some View {
        settings
        #if DEBUG && targetEnvironment(simulator)
        .sheet(isPresented: $showingQA) { QAPanel(model: model) }
        #endif
    }

    private var settings: some View {
        PaperSlip(title: "Settings", subtitle: nil,
                  revealsCardOnArrival: true, maximumWidth: 540, maximumHeight: 740,
                  onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCommonContent()
                bookDetails

                SlipSection(
                    title: "Leave this Book",
                    note: confirmingAbandon
                        ? nil
                        : "Ends this attempt permanently. Your achievements stay saved."
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
                                    withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                                        confirmingAbandon = false
                                    }
                                }
                                PaperButton(title: "Abandon", kind: .danger) {
                                    onAbandon()
                                }
                            }
                        }
                    } else {
                        PaperButton(title: "Abandon Book", kind: .danger) {
                            withAnimation(reduceMotion ? nil : .snappy(duration: 0.18)) {
                                confirmingAbandon = true
                            }
                        }
                        .accessibilityIdentifier("settings.abandonBook")
                    }
                }

                #if DEBUG && targetEnvironment(simulator)
                SlipSection(title: "Development") {
                    PaperButton(title: "QA tools", kind: .quiet) { showingQA = true }
                }
                #endif
            }
        }
        // Learning and achievement destinations are owned by the settings
        // content. This slip stays mounted beneath their full-screen cover,
        // preserving its scroll position and the presenter's paused game.
    }

    private var bookDetails: some View {
        SlipSection(title: "This Book") {
            DisclosureGroup(isExpanded: $showingBookDetails) {
                VStack(alignment: .leading, spacing: 10) {
                    LeaderRow(label: "Level", value: "\(model.run.level) of 9")
                    LeaderRow(label: "Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    LeaderRow(label: "Coins", value: "\(model.coins)")
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Seed").font(Print.caption(11)).foregroundStyle(theme.paper.softInk)
                            Text(model.run.seed)
                                .font(Print.numeral(15, weight: .semibold))
                                .foregroundStyle(theme.paper.ink)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button {
                            UIPasteboard.general.string = model.run.seed
                            copied = true
                        } label: {
                            Text(copied ? "Copied" : "Copy")
                                .font(Print.caption(12))
                                .foregroundStyle(theme.paper.ink)
                                .padding(.horizontal, 12)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(theme.paper.warm, in: .rect(cornerRadius: 3))
                        }
                        .buttonStyle(PressedPaperStyle())
                        .accessibilityLabel(copied ? "Seed copied" : "Copy Book seed")
                    }
                    Text("The same seed and choices produce the same Book.")
                        .font(Print.body(11.5)).foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            } label: {
                Text("Progress & seed")
                    .font(Print.body(14))
                    .foregroundStyle(theme.paper.ink)
                    .frame(minHeight: 44)
            }
            .tint(theme.paper.ink)
            .accessibilityIdentifier("settings.bookDetails")
        }
    }
}


/// The same privacy entry stays available at the front door and inside a Book.
/// Opening Settings refreshes consent status, but never loads or shows an ad.
struct AdsPrivacySection: View {
    private let ads = RewardedAdService.shared
    @Environment(\.cosmeticTheme) private var theme

    var body: some View {
        if ads.isEnabled {
            SlipSection(title: "Optional ads") {
                Text("Choose whether to watch a video for three extra turns, once per puzzle. No purchase is needed.")
                    .font(Print.body(12.5))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                if ads.privacyOptionsRequired {
                    PaperButton(title: "Ad privacy choices", kind: .quiet,
                                isEnabled: !ads.isPresentingPrivacyOptions && !ads.isPresenting) {
                        Task { await ads.presentPrivacyOptions() }
                    }
                }
                Link("Google advertising privacy information",
                     destination: URL(string: "https://policies.google.com/technologies/ads")!)
                    .font(Print.body(12.5))
                    .foregroundStyle(theme.paper.ink)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .task { await ads.refreshPrivacyStatus() }
        }
    }
}
