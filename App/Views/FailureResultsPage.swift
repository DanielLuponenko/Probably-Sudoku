import SwiftUI
import ProbablySudokuEngine

/// The failure page owns presentation only. The engine still owns eligibility,
/// and only Google's earned callback can change the saved turn allowance.
struct FailureResultsPage: View {
    let model: GameModel
    let offersRescue: Bool
    let onAbandon: () -> Void
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    private let ads = RewardedAdService.shared
    @State private var loadRequest = 0

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                ViewThatFits(in: .vertical) {
                    content(section: .article, available: geometry.size)
                        .fixedSize(horizontal: false, vertical: true)
                    ScrollView {
                        content(section: .article, available: geometry.size)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicators(.hidden)
                }
                .frame(maxHeight: .infinity, alignment: .top)
                content(section: .decisions, available: geometry.size)
                    .accessibilityIdentifier("failure.decisions")
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Declining keeps this page mounted for its terminal design, but must
        // still cancel a pending consent/ad request from the rescue offer.
        .task(id: offersRescue && ads.isEnabled ? loadRequest : -1) {
            guard ads.isEnabled, offersRescue, model.canOfferRewardedRescue,
                  scenePhase == .active else { return }
            await ads.prepare()
        }
        .onChange(of: scenePhase) { _, phase in
            if ads.isEnabled, offersRescue, phase == .active, ads.state == .idle { loadRequest += 1 }
        }
    }

    private func content(section: FailurePageContents.Section, available: CGSize) -> some View {
        FailurePageContents(score: model.puzzle?.score ?? 0,
                            target: model.puzzle?.target ?? 0,
                            offersRescue: offersRescue && ads.isEnabled,
                            adState: ads.state,
                            canWatchAd: buttonEnabled,
                            isBusy: model.hasRewardedRescueInFlight,
                            compact: available.width < 500,
                            onWatchAd: watchAd,
                            onEndBook: endBook,
                            board: model.puzzle?.board,
                            markers: model.visibleMarkers,
                            puzzle: model.puzzle,
                            boardSide: min(max(0, available.width - 16), max(240, available.height - 330)),
                            section: section)
    }

    private var buttonEnabled: Bool {
        guard ads.isEnabled, model.canOfferRewardedRescue, !model.hasRewardedRescueInFlight,
              scenePhase == .active else { return false }
        switch ads.state {
        case .idle, .ready, .unavailable: return true
        case .preparing, .presenting: return false
        }
    }

    func endBook() {
        if offersRescue { model.declineRewardedRescue() }
        // The ad-free edition already shows the terminal page. Its New book
        // action must return to the menu in one tap, not reveal this page again.
        if !offersRescue || !ads.isEnabled { onAbandon() }
    }

    private func watchAd() {
        guard ads.isEnabled else { return }
        if ads.isReady { presentAd() }
        else { loadRequest += 1 }
    }

    private func presentAd() {
        guard ads.isEnabled, let ticket = model.beginRewardedRescue() else { return }
        let presented = ads.present(onReward: {
            model.receiveRewardedRescue(ticket)
        }, onDismiss: {
            guard model.hasEarnedRewardedRescue(ticket) else {
                model.finishRewardedRescue(ticket)
                return
            }
            Task { @MainActor in
                await flipper.flip(from: model, reduceMotion: reduceMotion) {
                    model.finishRewardedRescue(ticket)
                }
                // A cancelled/backgrounded curl cannot take away earned turns.
                model.finishRewardedRescue(ticket)
            }
        })
        if !presented { model.finishRewardedRescue(ticket) }
    }
}

/// Pure printed content: previews and render tests never initialize the SDK.
struct FailurePageContents: View {
    let score: Int
    let target: Int
    let offersRescue: Bool
    let adState: RewardedAdService.State
    let canWatchAd: Bool
    let isBusy: Bool
    var compact = false
    var onWatchAd: () -> Void = {}
    var onEndBook: () -> Void = {}
    var board: Board? = nil
    var markers: [Square: OwnedMarker] = [:]
    var puzzle: PuzzleState? = nil
    var boardSide: CGFloat = 300
    enum Section: Equatable { case all, article, decisions }
    var section: Section = .all
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        VStack(spacing: 0) {
            if section != .decisions { article }
            if section != .article { decisions }
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(GameplaySurface.ink)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 6)
        .padding(.vertical, compact ? 6 : 4)
    }

    private var article: some View {
        VStack(spacing: 0) {
            if board == nil {
                FailureMedallion(symbol: offersRescue ? "hourglass" : "book.closed",
                                 size: compact ? 48 : 62)
                    .padding(.bottom, compact ? 6 : 8)
            }
            Text(offersRescue ? "Out of turns" : "Book over")
                .font(Print.heading((compact ? 29 : 33) * textScale))
                .tracking(-0.65)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("failure.heading")
            if board == nil {
                Text(offersRescue ? "A few more moves?" : "Not every book ends on a win.")
                    .font(Print.body((compact ? 16 : 18) * textScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .padding(.top, 6)
            }
            Group {
                if let puzzle, puzzle.boss == .splitEdition {
                    SplitEditionFailureLedger(puzzle: puzzle)
                } else {
                    FailureScorePanel(score: score, target: target, compact: compact)
                }
            }
                .padding(.horizontal, board == nil ? 14 : 0)
                .padding(.top, compact ? 10 : 14)

            if let board {
                GameplayBoardSnapshot(board: board, markers: markers, puzzle: puzzle)
                    .frame(width: boardSide, height: boardSide)
                    .padding(.top, 12)
                Text("Your board, as played")
                    .font(Print.caption(11 * textScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .padding(.top, 6)
            } else {
                FailurePageRule()
                    .padding(.horizontal, 10)
                    .padding(.vertical, compact ? 10 : 12)
            }
            if offersRescue {
                if board == nil {
                    RescueCardFan(height: compact ? 80 : 102)
                    Text("Keep this puzzle going")
                        .font(Print.subheading((compact ? 21 : 23) * textScale))
                        .tracking(-0.45)
                        .padding(.top, compact ? 10 : 12)
                }
                Text([BossFailureExplanation.text(for: puzzle),
                      "Watch an ad for 3 extra turns.\nYour board, score and hand stay the same."]
                    .compactMap { $0 }.joined(separator: "\n"))
                    .font(Print.body((compact ? 14 : 15) * textScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .padding(.top, 6)
            } else {
                if board == nil {
                    FailureLastPageNote().padding(.vertical, compact ? 4 : 14)
                    Text("A fresh page is waiting.")
                        .font(Print.subheading(23 * textScale))
                        .padding(.top, 16)
                }
                Text("\(BossFailureExplanation.text(for: puzzle) ?? "This attempt is over.")\nChoose a book and try again.")
                    .font(Print.body(15 * textScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .padding(.top, 8)
            }
        }
    }

    /// Actions never belong to the scrolling board/article. Cap only this
    /// compact control band's scale so both decisions fit even on an SE.
    private var decisions: some View {
        VStack(spacing: 0) {
            if offersRescue {
                FailurePageButton(title: buttonTitle, symbol: "play.rectangle",
                                  primary: true, isEnabled: canWatchAd,
                                  compact: compact, action: onWatchAd)
                    .accessibilityLabel(adState == .ready ? "Watch an ad for three extra turns" : buttonTitle)
                    .accessibilityHint("Only a completed ad earns the extra turns. You can end the book without watching.")
                    .accessibilityIdentifier("failure.watchAd")
                    .padding(.top, section == .all ? (compact ? 14 : 18) : 0)
                Text("Optional · Once per puzzle")
                    .font(Print.body(12.5 * footerScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .padding(.top, 6)
                Text(statusText)
                    .font(Print.body(11 * footerScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .accessibilityIdentifier("failure.adStatus")
                    .padding(.top, 4)
                FailurePageButton(title: "End book", primary: false,
                                  isEnabled: !isBusy, compact: compact, action: onEndBook)
                    .accessibilityIdentifier("failure.endBook")
                    .padding(.top, compact ? 8 : 12)
                Text("Finish this attempt without an ad.")
                    .font(Print.body(12 * footerScale))
                    .foregroundStyle(GameplaySurface.softInk)
                    .padding(.top, 6)
            } else {
                FailurePageButton(title: "New book", primary: true,
                                  isEnabled: !isBusy, compact: compact, action: onEndBook)
                    .accessibilityIdentifier("failure.newBook")
                    .padding(.top, section == .all ? 28 : 0)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var footerScale: Double { section == .all ? textScale : min(textScale, 1.4) }

    private var buttonTitle: String {
        switch adState {
        case .ready: return "Watch ad · +3 turns"
        case .preparing: return "Loading ad…"
        case .presenting: return "Ad in progress"
        case .idle: return "Load ad · +3 turns"
        case .unavailable: return "Try loading again"
        }
    }

    private var statusText: String {
        switch adState {
        case let .unavailable(reason): return reason
        case .preparing: return "Getting your optional ad ready."
        default: return "No purchases or ad clicks required."
        }
    }
}

/// A combined score is insufficient for bosses with separate qualifications.
/// Explain the saved condition, without inferring success from that total.
enum BossFailureExplanation {
    static func text(for puzzle: PuzzleState?) -> String? {
        guard let puzzle else { return nil }
        if puzzle.boss == .splitEdition {
            let targets = BossEncounterRules.editionTargets(puzzle: puzzle)
            let unfinished = (0..<2).filter {
                puzzle.bossState.encounter.editionScores[$0] < targets[$0]
            }
            if unfinished.count == 2 { return "Both editions are unfinished." }
            if let edition = unfinished.first {
                return "Edition \(edition == 0 ? "A" : "B") is unfinished."
            }
        }
        if puzzle.boss == .reviewBoard, !BossRuntime.reviewQualified(puzzle: puzzle) {
            let missing = BossReviewUnit.allCases.filter {
                !puzzle.bossState.reviewApproved.contains($0)
            }.map { unit in
                switch unit {
                case .row: "row"
                case .col: "column"
                case .box: "box"
                }
            }
            return "Still needs approval: \(missing.joined(separator: ", "))."
        }
        return nil
    }
}

/// Replace the single score/target pair with the two actual win conditions.
/// The final ledgers stay legible after the live boss controls have left.
struct SplitEditionFailureLedger: View {
    let puzzle: PuzzleState
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 0) {
                    edition(0)
                    Rectangle().fill(theme.paper.ruleInk).frame(height: 0.8)
                    edition(1)
                }
            } else {
                HStack(spacing: 0) {
                    edition(0)
                    Rectangle().fill(theme.paper.ruleInk).frame(width: 0.8)
                        .padding(.vertical, 10)
                    edition(1)
                }
            }
        }
        .frame(height: 84 * textScale * (dynamicTypeSize.isAccessibilitySize ? 2 : 1))
        .background(theme.paper.warm.opacity(0.4), in: .rect(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.paper.ruleInk, lineWidth: 0.8))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("failure.edition-ledgers")
    }

    private func edition(_ index: Int) -> some View {
        let name = index == 0 ? "A" : "B"
        let score = puzzle.bossState.encounter.editionScores[index]
        let target = BossEncounterRules.editionTargets(puzzle: puzzle)[index]
        let complete = score >= target
        return VStack(spacing: 2) {
            HStack(spacing: 4) {
                Text("EDITION \(name)").font(Print.caption(11 * textScale))
                Image(systemName: complete ? "checkmark.seal.fill" : "circle")
                    .font(.system(size: 11 * textScale)).accessibilityHidden(true)
            }
            .foregroundStyle(complete ? GameplaySurface.sage : Paper.redPencil)
            Text(score.formatted()).font(Print.numeral(22 * textScale, weight: .semibold))
                .foregroundStyle(GameplaySurface.ink)
            Text("/ \(target.formatted())").font(Print.numeral(13 * textScale, weight: .medium))
                .foregroundStyle(GameplaySurface.softInk)
        }
        .lineLimit(1).minimumScaleFactor(0.6)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Edition \(name), \(score) of \(target) points. \(complete ? "Complete." : "Unfinished.")")
    }
}

private struct FailureScorePanel: View {
    let score: Int
    let target: Int
    let compact: Bool
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Large numerals need the whole paper width. Shrinking two
                // columns past their font floor silently drops score digits.
                // The failure page already scrolls at accessibility sizes.
                VStack(spacing: 0) {
                    scoreColumn("YOUR SCORE", value: score)
                    Rectangle().fill(theme.paper.ruleInk.opacity(0.8)).frame(height: 0.8)
                        .padding(.horizontal, 10)
                    scoreColumn("TARGET", value: target)
                }
            } else {
                HStack(spacing: 0) {
                    scoreColumn("YOUR SCORE", value: score)
                    Rectangle().fill(theme.paper.ruleInk.opacity(0.8)).frame(width: 0.8)
                        .padding(.vertical, 10)
                    scoreColumn("TARGET", value: target)
                }
            }
        }
        .frame(height: (compact ? 76 : 88) * textScale
               * (dynamicTypeSize.isAccessibilitySize ? 2 : 1))
        .background(theme.paper.warm.opacity(0.4), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.paper.ruleInk, lineWidth: 0.8)
            RoundedRectangle(cornerRadius: 9)
                .inset(by: 1.5).strokeBorder(.white.opacity(0.65), lineWidth: 0.7)
        }
    }

    private func scoreColumn(_ title: String, value: Int) -> some View {
        VStack(spacing: 4) {
            Text(title).font(Print.caption(11 * textScale))
                .foregroundStyle(theme.paper.softInk)
            Text(value, format: .number)
                .font(.system(size: (compact ? 32 : 36) * textScale, weight: .medium, design: .serif))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.45)
        }
        .padding(.horizontal, 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title == "TARGET" ? "Target" : "Your score")
        .accessibilityValue(value.formatted())
    }
}

private struct FailurePageRule: View {
    @Environment(\.cosmeticTheme) private var theme
    var body: some View {
        HStack(spacing: 5) {
            Rectangle().frame(height: 0.8)
            Rectangle().frame(width: 7, height: 7).rotationEffect(.degrees(45))
            Rectangle().frame(height: 0.8)
        }
        .foregroundStyle(theme.paper.ruleInk)
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}

private struct FailurePageButton: View {
    static let oliveInk = Color(hex: 0x4F5D43)
    let title: String
    var symbol: String? = nil
    let primary: Bool
    let isEnabled: Bool
    let compact: Bool
    var action: () -> Void
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 25 * textScale, weight: .medium))
                        .accessibilityHidden(true)
                }
                Text(title).font(Print.subheading((compact ? 20 : 22) * textScale))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: compact ? 50 : (primary ? 60 : 52))
            .foregroundStyle(primary ? GameplaySurface.ivory : GameplaySurface.sage)
            .background {
                RoundedRectangle(cornerRadius: 9)
                    .fill(primary ? GameplaySurface.sage : GameplaySurface.ivory)
                    .overlay {
                        if primary {
                            LinearGradient(colors: [.white.opacity(0.12), .clear, .black.opacity(0.16)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                            FailurePaperTexture(opacity: 0.13)
                        }
                    }
                    .compositingGroup()
                    .clipShape(.rect(cornerRadius: 9))
                    .shadow(color: .black.opacity(primary ? 0.2 : 0), radius: 3, x: 0, y: 3)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(GameplaySurface.sage.opacity(0.8), lineWidth: 1.2)
                RoundedRectangle(cornerRadius: 7).inset(by: 3)
                    .strokeBorder(.white.opacity(primary ? 0.3 : 0.5), lineWidth: 0.65)
            }
            .contentShape(.rect(cornerRadius: 9))
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

private struct FailureLastPageNote: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("THE END").font(.system(size: 29, weight: .bold, design: .serif))
            Text("(for now)").font(Print.handwritten(19))
        }
        .foregroundStyle(Paper.ink)
        // This fixed-size, decorative paper is hidden from VoiceOver. Keep
        // its handwriting intact while the surrounding reading text scales.
        .dynamicTypeSize(.large)
        .frame(width: 170, height: 112)
        .background(Paper.page, in: .rect(cornerRadius: 3))
        .overlay { FailurePaperTexture(opacity: 0.22) }
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.rule, lineWidth: 0.7) }
        .shadow(color: Paper.deskDark.opacity(0.2), radius: 3, x: 1, y: 4)
        .rotationEffect(.degrees(-4))
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }
}

private struct FailurePaperTexture: View {
    var opacity: Double
    var body: some View {
        GeometryReader { geometry in
            Image(decorative: "BetweenPuzzlesPaper").resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .opacity(opacity)
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
