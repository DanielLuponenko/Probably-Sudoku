import AVKit
import SwiftUI

/// A field guide to the controls the player actually sees, not a second game.
/// Every example is a crop of a captured game screen; opening this guide never
/// reads or changes the player's run, inventory, or tutorial progress.
struct HelpSlip: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var onClose: () -> Void

    @State private var selectedTopic: HowToPlayTopic = .place
    @State private var selectedFilm: GuideFilm?
    @State private var showingTopics = false

    var body: some View {
        ScrollViewReader { scroll in
            PaperSlip(title: "How to play",
                      subtitle: "A pocket guide, illustrated with the real game.",
                      revealsCardOnArrival: true,
                      maximumHeight: 900,
                      footer: AnyView(navigation),
                      onClose: onClose) {
                GuideTopicPage(topic: selectedTopic, watchTurn: watchTurn)
                    .id(selectedTopic)
            }
            .onChange(of: selectedTopic) {
                scroll.scrollTo(selectedTopic, anchor: .top)
            }
        }
        .paperPanel(item: $selectedFilm) { film in
            GuideTurnMovie(film: film)
        }
        .paperPanel(isPresented: $showingTopics) {
            PaperSlip(title: "Topics", subtitle: nil, maximumWidth: 460,
                      onClose: { showingTopics = false }) {
                VStack(spacing: 8) {
                    ForEach(HowToPlayTopic.allCases) { topic in
                        PaperButton(title: topic.title,
                                    kind: selectedTopic == topic ? .primary : .quiet) {
                            select(topic)
                            showingTopics = false
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("how-to-play-guide")
    }

    private var navigation: some View {
        VStack(spacing: 8) {
            Rectangle().fill(Paper.rule).frame(height: 1)
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                // Symbols retain the full spoken names while leaving room for
                // enlarged page progress and the guide's scrollable article.
                HStack(spacing: 8) {
                    GuideNavigationButton(title: "Previous", symbol: "chevron.left",
                                          enabled: selectedTopic.previous != nil,
                                          compact: true) {
                        select(selectedTopic.previous)
                    }
                    .frame(width: 52)
                    topicPicker(compact: true)
                    GuideNavigationButton(title: "Next", symbol: "chevron.right",
                                          enabled: selectedTopic.next != nil,
                                          compact: true) {
                        select(selectedTopic.next)
                    }
                    .frame(width: 52)
                }
            } else {
                topicPicker(compact: false)
                HStack(spacing: 12) {
                    GuideNavigationButton(title: "Previous", symbol: "chevron.left",
                                          enabled: selectedTopic.previous != nil) {
                        select(selectedTopic.previous)
                    }
                    GuideNavigationButton(title: "Next", symbol: "chevron.right",
                                          enabled: selectedTopic.next != nil, symbolAfter: true) {
                        select(selectedTopic.next)
                    }
                }
            }
        }
    }

    private func topicPicker(compact: Bool) -> some View {
        Button { showingTopics = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet")
                    .font(compact ? .system(size: 28, weight: .semibold) : .subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                if compact {
                    Text("\(selectedTopic.pageNumber)/\(HowToPlayTopic.allCases.count)")
                        .font(.body.weight(.semibold))
                        .monospacedDigit()
                        .fixedSize()
                } else {
                    Text("Topics")
                    Spacer(minLength: 8)
                    Text("\(selectedTopic.pageNumber) of \(HowToPlayTopic.allCases.count)")
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .accessibilityHidden(true)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Paper.ink)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 44)
            .contentShape(.rect)
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel("Choose a how to play topic")
        .accessibilityValue("\(selectedTopic.title), \(selectedTopic.pageNumber) of \(HowToPlayTopic.allCases.count)")
        .accessibilityIdentifier("guide-topic-picker")
    }

    private func select(_ topic: HowToPlayTopic?) {
        guard let topic else { return }
        // No page-flip or large transition in a reference guide. Replacing the
        // identified page also returns its scroll content to the beginning.
        selectedTopic = topic
    }

    private func watchTurn() {
        guard let film = GuideFilm.placeAndBank else { return }
        selectedFilm = film
    }
}

enum HowToPlayTopic: String, CaseIterable, Identifiable {
    case place, pool, turns, scoring, cashOut, shop, markers, bosses, finishing

    var id: String { rawValue }
    var pageNumber: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    var previous: Self? { pageNumber > 1 ? Self.allCases[pageNumber - 2] : nil }
    var next: Self? { pageNumber < Self.allCases.count ? Self.allCases[pageNumber] : nil }

    var title: String {
        switch self {
        case .place: "Place a number"
        case .pool: "Your Hand & the Pool"
        case .turns: "Toss & End Turn"
        case .scoring: "Reach the target"
        case .cashOut: "Cash Out or Keep Filling"
        case .shop: "Make the Shop work for you"
        case .markers: "Choose a Marker square"
        case .bosses: "Read the road ahead"
        case .finishing: "When a Book ends"
        }
    }

    var introduction: String {
        switch self {
        case .place: "A Sudoku board, a handful of numbers, and a score to beat."
        case .pool: "The numbers you hold are the numbers you can play."
        case .turns: "A placement is not a whole turn. Use your Hand before banking."
        case .scoring: "Finishing rows, columns and boxes is how small numbers earn big scores."
        case .cashOut: "Once you win, choose between moving on and earning more coins."
        case .shop: "Spend the coins you earn on a plan for the next Puzzle."
        case .markers: "A Marker belongs to a position on the board, not to a particular number."
        case .bosses: "Each Chapter has two Puzzles and a Boss. Read the route before you play."
        case .finishing: "Every Book is its own challenge, with its own Obstacle progress."
        }
    }

    var figures: [GuideFigure] {
        switch self {
        case .place: [.board, .hand]
        case .pool: [.hand]
        case .turns: [.turnControls]
        case .scoring: [.score, .board]
        case .cashOut: [.score]
        case .shop: [.shop, .buffOffer]
        case .markers: [.markerOffers]
        case .bosses, .finishing: [.route]
        }
    }

    var steps: [GuideInstruction] {
        switch self {
        case .place:
            [
                .init(1, "Pick from your Hand", "Tap a number card below the board. Matching numbers on the board light up to help you look."),
                .init(2, "Tap an empty square", "Read the row, column and 3×3 box, then tap where the number belongs. For a Clue, tap the lightbulb control, choose a number from your Hand, then tap its revealed square. Revealing a new destination spends a Clue; its placement normally scores zero."),
                .init(3, "Keep playing, then End Turn", "Place more of your Hand when you can. The live score updates as you play. End Turn banks it and draws replacement numbers. Correctly playing your last Hand card ends the turn automatically.")
            ]
        case .pool:
            [
                .init(1, "Look at what you have", "The number cards below the board are your Hand. A selected number stays highlighted until you play it or change your selection."),
                .init(2, "Think about what remains", "The Pool holds the undrawn numbers. There are nine copies of each number in a finished grid: subtract the copies on the board and in your Hand."),
                .init(3, "Hold on to a useful number", "End Turn keeps unplayed numbers and refills the empty spaces in your Hand. You do not have to throw away a good number.")
            ]
        case .turns:
            [
                .init(1, "Select a number to Toss", "Tap one Hand card, then Toss. It returns that number to the Pool and spends one Toss, not one turn."),
                .init(2, "Finish what you can", "Toss does not immediately draw a replacement. Play other useful numbers first."),
                .init(3, "Tap End Turn", "Your pending score is banked and missing Hand cards are drawn. Correctly playing the last card does this automatically. The turn counter below the buttons shows your budget.")
            ]
        case .scoring:
            [
                .init(1, "Check score and target", "Your live Turn score shows Points × Mult, plus direct bonuses. End Turn banks that total. Complete rows, columns and boxes for more Points. Tap the score to inspect each step."),
                .init(2, "Arrange your Bookmarks", "Bookmarks resolve from left to right. +Mult before ×Mult can score more. Your first correct placement locks this Turn's order; later rearrangements affect the next Turn."),
                .init(3, "Avoid guesses", "A correct placement starts at 10 × the number. A wrong placement takes 50 × the number from this Turn's Points first, then banked score, and returns the number to the Pool.")
            ]
        case .cashOut:
            [
                .init(1, "Bank enough points", "Reach the target with End Turn to win the Puzzle. You do not need to fill the entire board."),
                .init(2, "Choose Cash Out", "Collect your coin payout and move on. Unused turns contribute to the payout."),
                .init(3, "Or choose Keep Filling", "If you still have empty squares and turns, continue with the same board. Score is frozen; each completed row, column or box earns 1 extra coin. Filling the whole board earns 3 more. Boss rules still apply.")
            ]
        case .shop:
            [
                .init(1, "Read the effect and price", "Shop prices use the coins earned in the game, not real money. Choose effects that help the way you are scoring."),
                .init(2, "Build your combination", "Bookmarks work for the rest of this Book. Markers reward their squares. Buffs are consumed when used; their text tells you how long the effect lasts."),
                .init(3, "Mind your slots", "Bookmarks and Buffs have limited space. In the Shop, you can sell one for a partial coin refund. Reroll changes the offers for the displayed cost.")
            ]
        case .markers:
            [
                .init(1, "Choose the effect", "Read a Marker's Shop card. Sapphire draws a number after a correct fill. Echo draws another copy of the digit placed there, if one remains in the Pool; it can draw up to 3 copies per Puzzle."),
                .init(2, "Choose a position", "Tap a square on the blank placement grid. An occupied position removes the other Marker, so choose an unused square to keep both. The next Puzzle supplies the numbers."),
                .init(3, "Use it through the Book", "The marked position carries into later Puzzles. A Given there does not trigger it. Owned Markers gain another square as you complete Chapters, up to nine each.")
            ]
        case .bosses:
            [
                .init(1, "Read Next Puzzle", "The highlighted card is the Puzzle you can play now. Its neighbours show what comes next in this Chapter."),
                .init(2, "Check the Boss power", "Every third Puzzle is a Boss. Its name and power are shown before play. That rule can affect scoring, turns, your Hand or the board."),
                .init(3, "Choose your route", "Skip any ordinary Puzzle to collect the Buff shown on its ticket. If your Buff slots are full, choose one to replace or cancel. Bosses must be played. The Book's major final Boss appears only at the very last Puzzle.")
            ]
        case .finishing:
            [
                .init(1, "If you run out of turns", "When available, watch an optional ad for 3 extra turns, once per Puzzle. The reward resumes the same board, score and Hand. Closing the ad before earning its reward grants no extra turns."),
                .init(2, "Or end this attempt", "You can always choose End Book without watching an ad. A full board below target also ends the attempt: there are no empty squares left to score from."),
                .init(3, "Complete your Book", "Beat the final Boss to reach the congratulations page, not another Shop. Completing an Obstacle unlocks the next Obstacle for this same Book only. Other Books keep their own progress.")
            ]
        }
    }

    var note: String {
        switch self {
        case .place: "The green wash is a reading aid, not a promise that a blank square is correct."
        case .pool: "No new numbers are created: the Pool and Hand together match the remaining blanks."
        case .turns: "Check the printed allowance: Books, items and Bosses can change turns or Tosses."
        case .scoring: "One well-planned placement can complete a row and a box together."
        case .cashOut: "No empty squares, or no turns left? There is nothing more to fill; take your result."
        case .shop: "A cheap item that fits your plan can be better than a rare one that does not."
        case .markers: "Hold a visible marked square to read its effect; release to dismiss. Inspection never places your selected number. With VoiceOver, use the square's Inspect marker action, then Dismiss."
        case .bosses: "A Boss power and a Book's selected Obstacle are different rules; both can be active."
        case .finishing: "To practise without risking a Book, replay the Tutorial from Settings."
        }
    }
}

struct GuideInstruction: Identifiable {
    let id: Int
    let title: String
    let detail: String

    init(_ number: Int, _ title: String, _ detail: String) {
        self.id = number
        self.title = title
        self.detail = detail
    }
}

/// Coordinates refer to the original 750×1334 native captures, never a resized phone
/// thumbnail. Cropping in the view preserves legible pixels and excludes HUD
/// controls unrelated to the explanation.
enum GuideFigure: String, CaseIterable, Identifiable {
    case board, hand, turnControls, score, route, shop, markerOffers, buffOffer

    var id: String { rawValue }
    var asset: String {
        switch self {
        case .board, .hand, .turnControls, .score: "GuideGameplay"
        case .route: "GuideRoute"
        case .shop: "GuideShop"
        case .markerOffers, .buffOffer: "GuideShopItems"
        }
    }

    var captureSize: CGSize { CGSize(width: 750, height: 1334) }

    var crop: CGRect {
        // Native SE captures, refreshed with the current catalogue and live
        // score HUD. Crop only; never redraw or simulate the game artwork.
        let pixels: CGRect = switch self {
        case .board: CGRect(x: 72, y: 396, width: 606, height: 612)
        case .hand: CGRect(x: 16, y: 1080, width: 718, height: 108)
        case .turnControls: CGRect(x: 16, y: 1080, width: 718, height: 250)
        case .score: CGRect(x: 20, y: 275, width: 340, height: 110)
        case .route: CGRect(x: 16, y: 352, width: 718, height: 974)
        case .shop: CGRect(x: 20, y: 346, width: 714, height: 282)
        case .markerOffers: CGRect(x: 20, y: 632, width: 714, height: 282)
        case .buffOffer: CGRect(x: 20, y: 922, width: 714, height: 274)
        }
        return CGRect(x: pixels.minX / captureSize.width,
                      y: pixels.minY / captureSize.height,
                      width: pixels.width / captureSize.width,
                      height: pixels.height / captureSize.height)
    }

    var aspectRatio: CGFloat {
        crop.width * captureSize.width / (crop.height * captureSize.height)
    }

    var caption: String {
        switch self {
        case .board: "The board: read the row, column and box together."
        case .hand: "Your Hand: tap one number card to select it."
        case .turnControls: "Select a card for Toss. Use End Turn to bank and refill."
        case .score: "The live calculation shows 40 × 1 = +40 for this Turn, toward a target of 1,000."
        case .route: "Two ordinary Puzzles, then the Boss. This ordinary Puzzle offers Careful Cut if you skip."
        case .shop: "Bookmark offers print their effect and coin price."
        case .markerOffers: "Marker cards explain what their squares will do."
        case .buffOffer: "Tap a Buff offer to read its effect. This Inventory Count has already been bought and is stamped Sold."
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .board: "Actual game board with nine rows, nine columns and bold borders around the 3 by 3 boxes. Some squares are filled, and others are empty."
        case .hand: "Actual Hand of number cards below the board: 8, 2, 3, 7, 9, and 9."
        case .turnControls: "Actual Hand, Toss with 4 left, End Turn, and Turn 1 of 10."
        case .score: "Actual score area showing 0 of 1,000 banked, with a live gain of 40 from 40 times 1."
        case .route: "Actual route with Easy, Easy but hard, and Boss The Mirror, which removes Line Clear bonuses. Careful Cut is offered for skipping; it returns up to 3 selected cards without spending Tosses and draws no replacements."
        case .shop: "Actual Bookmark offers: Local Gossip for 5 coins adds 30 flat points per correct placement; Auction Notices for 8 coins makes the first reroll in each Shop free."
        case .markerOffers: "Actual Sapphire Marker for 7 coins draws one number after a correct fill; Echo Marker for 7 coins draws another copy of the digit placed here, if available."
        case .buffOffer: "Actual Inventory Count Buff for 3 coins, stamped Sold. It reveals the remaining Pool counts of digits 1 through 9 for this Turn."
        }
    }
}

struct GuideTopicPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var headingSize: CGFloat = 25
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16
    let topic: HowToPlayTopic
    let watchTurn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(topic.title)
                    .font(Print.heading(headingSize))
                    .foregroundStyle(Paper.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(topic.introduction)
                    .font(Print.body(bodySize))
                    .foregroundStyle(Paper.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }

            watchTurnControl

            ViewThatFits(in: .horizontal) {
                if !dynamicTypeSize.isAccessibilitySize {
                    HStack(alignment: .top, spacing: 24) {
                        // Bounded reading columns give ViewThatFits a real
                        // ideal width (684pt). Flexible maximums previously
                        // asked for 824pt and incorrectly fell back on iPad.
                        illustrations.frame(width: 320)
                        instructions.frame(width: 340)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 18) {
                    instructions
                    illustrations
                }
            }

            Text(topic.note)
                .font(Print.body(bodySize - 1))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Paper.sageDeep).frame(width: 3)
                        .accessibilityHidden(true)
                }
        }
        .padding(.top, 2)
    }

    private var illustrations: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(topic.figures) { figure in
                GuideGameImage(figure: figure)
            }
        }
    }

    @ViewBuilder
    private var watchTurnControl: some View {
        if topic == .place || topic == .turns || topic == .scoring {
            if GuideFilm.placeAndBank != nil {
                Button(action: watchTurn) {
                    Label("Watch a turn", systemImage: "play.rectangle")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Paper.page)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Paper.sageDeep, in: .rect(cornerRadius: 6))
                }
                .frame(maxWidth: 360, alignment: .leading)
                .buttonStyle(.plain)
                .accessibilityHint("Opens a recording from the game showing number placement and End Turn. Written instructions remain available.")
                .accessibilityIdentifier("guide-watch-turn")
            }
        }
    }

    private var instructions: some View {
        VStack(alignment: .leading, spacing: 17) {
            ForEach(topic.steps) { step in
                GuideStepRow(step: step)
            }
        }
    }
}

private struct GuideGameImage: View {
    let figure: GuideFigure

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            GeometryReader { proxy in
                Image(figure.asset)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: proxy.size.width / figure.crop.width,
                           height: proxy.size.height / figure.crop.height)
                    .offset(x: -figure.crop.minX * proxy.size.width / figure.crop.width,
                            y: -figure.crop.minY * proxy.size.height / figure.crop.height)
            }
            .aspectRatio(figure.aspectRatio, contentMode: .fit)
            .clipped()
            .clipShape(.rect(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule.opacity(0.7), lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(figure.accessibilityDescription)
            .accessibilityAddTraits(.isImage)

            Text(figure.caption)
                .font(.caption)
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GuideStepRow: View {
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 16
    @ScaledMetric(relativeTo: .body) private var numberSize: CGFloat = 29
    let step: GuideInstruction

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text("\(step.id)")
                .font(Print.numeral(bodySize, weight: .semibold))
                .foregroundStyle(Paper.page)
                .frame(width: numberSize, height: numberSize)
                .background(Paper.sageDeep, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(step.title)
                    .font(Print.subheading(bodySize))
                    .foregroundStyle(Paper.ink)
                Text(step.detail)
                    .font(Print.body(bodySize))
                    .foregroundStyle(Paper.inkSoft)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(step.id). \(step.title). \(step.detail)")
    }
}

private struct GuideNavigationButton: View {
    let title: String
    let symbol: String
    let enabled: Bool
    var symbolAfter = false
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if compact {
                    Image(systemName: symbol)
                        .font(.system(size: 28, weight: .semibold))
                        .accessibilityHidden(true)
                } else {
                    if !symbolAfter { Image(systemName: symbol).accessibilityHidden(true) }
                    Text(title)
                    if symbolAfter { Image(systemName: symbol).accessibilityHidden(true) }
                }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(enabled ? Paper.ink : Paper.inkSoft)
            .frame(maxWidth: .infinity, minHeight: compact ? 52 : 44)
            .padding(.horizontal, 8)
            .background(enabled ? Paper.pageWarm : Paper.page, in: .rect(cornerRadius: 5))
            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.rule, lineWidth: 1) }
            .opacity(enabled ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("\(title) topic")
        .accessibilityIdentifier("guide-\(title.lowercased())")
    }
}

private struct GuideFilm: Identifiable {
    let url: URL
    var id: URL { url }

    static var placeAndBank: GuideFilm? {
        Bundle.main.url(forResource: "guide-place-and-bank", withExtension: "mp4")
            .map { GuideFilm(url: $0) }
    }
}

private struct GuideTurnMovie: View {
    @Environment(\.paperPanelDismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    let film: GuideFilm

    var body: some View {
        PaperSlip(title: "Watch a turn", subtitle: nil,
                  maximumWidth: 600, maximumHeight: 800, onClose: close) {
            VStack(spacing: 12) {
                VideoPlayer(player: player)
                    .accessibilityLabel("Game recording: select a number, place it, and bank the turn")
                    .aspectRatio(750.0 / 1334.0, contentMode: .fit)
                    .frame(maxHeight: 480)
                Text("Placing 1 earns 10 Points plus 30 from Local Gossip. End Turn adds Morning Edition's first-turn bonus of 100 and banks 140 Points, then refills the Hand. This recording plays at 3× speed; pause or replay with the video controls.")
                    .font(Print.body(14))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Paper.ink)
            }
        }
        .task {
            guard player == nil else { return }
            let recording = AVPlayer(url: film.url)
            // Playback is explicitly requested by Watch a turn. No background
            // autoplay, looping observer, or change to the game's audio mix.
            recording.isMuted = true
            player = recording
            recording.play()
        }
        .onChange(of: scenePhase) {
            if scenePhase != .active { player?.pause() }
        }
        .onDisappear {
            player?.pause()
            player?.replaceCurrentItem(with: nil)
        }
    }

    private func close() {
        player?.pause()
        dismiss()
    }
}
