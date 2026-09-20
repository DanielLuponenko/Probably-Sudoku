import SwiftUI
import ProbablySudokuEngine

/// Anything that is about the run rather than in it is printed on a slip and
/// laid on the desk over the book. A system settings list would be the one
/// place the game stops being an object.
struct PaperSlip<Content: View>: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    /// Embedding a slip can opt out of its full-screen dimmer.
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
                if dynamicTypeSize.isAccessibilitySize {
                    // A long enlarged heading must not consume the article's
                    // entire viewport. It scrolls with the explanation, while
                    // dismissal and any decision footer stay reachable.
                    ScrollView {
                        VStack(spacing: 0) {
                            heading
                            paddedContent
                        }
                    }
                } else {
                    heading
                    if fitsContent {
                        ViewThatFits(in: .vertical) {
                            paddedContent.fixedSize(horizontal: false, vertical: true)
                            ScrollView { paddedContent }
                        }
                    } else {
                        ScrollView { paddedContent }
                    }
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

    private var heading: some View {
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
    @Environment(\.gameReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var settingsTextScale = 1.0
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
        .paperPanel(isPresented: $showingQA) {
            QAPanel(model: model).frame(maxWidth: 600, maxHeight: 760)
        }
        #endif
    }

    private var settings: some View {
        SettingsNavigationHost { destination in
            PaperSlip(title: "Settings", subtitle: nil,
                  revealsCardOnArrival: true, maximumWidth: 540, maximumHeight: 740,
                  onClose: onClose) {
            VStack(alignment: .leading, spacing: 0) {
                SettingsCommonContent(destination: destination)
                bookDetails

                SettingsSection(
                    title: "Leave this Book",
                    note: confirmingAbandon
                        ? nil
                        : "Ends this attempt permanently. Your achievements stay saved."
                ) {
                    if confirmingAbandon {
                        AbandonBookDecision(level: model.run.level, puzzle: model.run.slot.rawValue + 1,
                                            onKeepPlaying: {
                            confirmingAbandon = false
                            onClose()
                        }, onAbandon: onAbandon)
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
                SettingsSection(title: "Development") {
                    PaperButton(title: "QA tools", kind: .quiet) { showingQA = true }
                }
                #endif
            }
        }
        }
        // The stable Settings host owns child panels above the article's
        // compact/enlarged layouts. Practice survives a text-size change,
        // and the presenter's game remains paused underneath.
    }

    private var bookDetails: some View {
        SettingsSection(title: "This Book") {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    showingBookDetails.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Text("Progress & seed")
                        .font(Print.caption(14 * settingsTextScale))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .rotationEffect(.degrees(showingBookDetails ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(theme.paper.ink)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(PressedPaperStyle())
            .accessibilityValue(showingBookDetails ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("settings.bookDetails")

            if showingBookDetails {
                VStack(alignment: .leading, spacing: 10) {
                    bookDetail("Chapter", value: "\(model.run.level) of 9")
                    bookDetail("Puzzle", value: "\(model.run.slot.rawValue + 1) of 3")
                    bookDetail("Coins", value: "\(model.coins)")
                    HStack(alignment: .center, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Seed").font(Print.caption(12 * settingsTextScale)).foregroundStyle(theme.paper.softInk)
                            Text(model.run.seed)
                                .font(Print.numeral(15 * settingsTextScale, weight: .semibold))
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
                                .font(Print.caption(12 * settingsTextScale))
                                .fixedSize(horizontal: false, vertical: true)
                                .foregroundStyle(theme.paper.ink)
                                .padding(.horizontal, 12)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(theme.paper.warm, in: .rect(cornerRadius: 3))
                        }
                        .buttonStyle(PressedPaperStyle())
                        .accessibilityLabel(copied ? "Seed copied" : "Copy Book seed")
                    }
                    Text("The same seed and choices produce the same Book.")
                        .font(Print.body(11.5 * settingsTextScale)).foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 8)
            }
        }
    }

    private func bookDetail(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label).foregroundStyle(theme.paper.softInk)
            Spacer(minLength: 0)
            Text(value).font(Print.numeral(14 * settingsTextScale, weight: .semibold))
        }
        .font(Print.body(14 * settingsTextScale))
        .foregroundStyle(theme.paper.ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// Destructive choices need whole words and a readable consequence. At large
/// text sizes the article can scroll, so use its full width for each action.
struct AbandonBookDecision: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var explanationSize: CGFloat = 12.5
    let level: Int
    let puzzle: Int
    var onKeepPlaying: () -> Void
    var onAbandon: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Abandon Chapter \(level), Puzzle \(puzzle)? The Book is thrown away and cannot be continued.")
                .font(Print.body(explanationSize))
                .foregroundStyle(Paper.redPencil)
                .fixedSize(horizontal: false, vertical: true)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: 10)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                PaperButton(title: "Keep playing", kind: .quiet, action: onKeepPlaying)
                    .accessibilityIdentifier("settings.keepPlaying")
                PaperButton(title: "Abandon", kind: .danger, action: onAbandon)
                    .accessibilityIdentifier("settings.confirmAbandon")
            }
            // Keep these short choices whole at the minimum 240pt article
            // width. They still grow beyond twice the ordinary type size;
            // the consequence above retains the full requested text size.
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
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
