import AVKit
import SwiftUI

/// A field guide to the controls the player actually sees, not a second game.
/// Every example is a crop of a captured game screen; opening this guide never
/// reads or changes the player's run, inventory, or tutorial progress.
struct HelpSlip: View {
    var onClose: () -> Void

    @State private var selectedTopic: HowToPlayTopic = .place
    @State private var selectedFilm: GuideFilm?

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
        .sheet(item: $selectedFilm) { film in
            GuideTurnMovie(film: film)
        }
        .accessibilityIdentifier("how-to-play-guide")
    }

    private var navigation: some View {
        VStack(spacing: 8) {
            Rectangle().fill(Paper.rule).frame(height: 1)
                .accessibilityHidden(true)
            Menu {
                Picker("Choose a topic", selection: $selectedTopic) {
                    ForEach(HowToPlayTopic.allCases) { topic in
                        Text(topic.title).tag(topic)
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet")
                        .accessibilityHidden(true)
                    Text("Topics")
                    Spacer(minLength: 8)
                    Text("\(selectedTopic.pageNumber) of \(HowToPlayTopic.allCases.count)")
                        .monospacedDigit()
                    Image(systemName: "chevron.up.chevron.down")
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .accessibilityLabel("Choose a how to play topic")
            .accessibilityValue("\(selectedTopic.title), \(selectedTopic.pageNumber) of \(HowToPlayTopic.allCases.count)")
            .accessibilityIdentifier("guide-topic-picker")

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
        case .bosses: "Each Level has two Puzzles and a Boss. Read the route before you play."
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
                .init(1, "Pick from Numbers Drawn", "Tap a number in your Hand. Matching numbers on the board light up to help you look."),
                .init(2, "Tap an empty square", "Use the row, column and 3×3 box to work out where it belongs. The game checks the Puzzle's solution."),
                .init(3, "Keep playing, then End Turn", "Place more of your Hand when you can. End Turn banks your queued points and draws replacement numbers. Correctly playing your last Hand card ends the turn automatically.")
            ]
        case .pool:
            [
                .init(1, "Look at what you have", "Numbers Drawn is your Hand. A selected number stays highlighted until you play it or change your selection."),
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
                .init(1, "Check score and target", "The large score is banked. The queued amount is still waiting for End Turn. Meet the target by the end of your last available turn."),
                .init(2, "Plan a clear", "Complete a row, column or 3×3 box for a bigger payout. Bookmarks, Markers and Buffs can change the points and multipliers."),
                .init(3, "Avoid guesses", "Before item and Boss effects, a correct placement starts at 10 × the number; a wrong placement costs 50 × the number and returns it to the Pool.")
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
                .init(1, "Choose the effect", "Read a Marker's Shop card. In this example, Sapphire draws a number from the Pool when you correctly place on its square; Crimson multiplies that placement."),
                .init(2, "Choose a position", "Tap a square on the blank placement grid. An occupied position removes the other Marker, so choose an unused square to keep both. The next Puzzle supplies the numbers."),
                .init(3, "Use it through the Book", "The marked position carries into later Puzzles. A Given there does not trigger it. Owned Markers gain another square as you complete Levels, up to nine each.")
            ]
        case .bosses:
            [
                .init(1, "Read Next Puzzle", "The highlighted card is the Puzzle you can play now. Its neighbours show what comes next in this Level."),
                .init(2, "Check the Boss power", "Every third Puzzle is a Boss. Its name and power are shown before play. That rule can affect scoring, turns, your Hand or the board."),
                .init(3, "Choose your route", "When offered, a Clipping can skip an ordinary Puzzle for its printed reward. Bosses must be played. The Book's major final Boss appears only at the very last Puzzle.")
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
        case .markers: "A coloured mark shows an effect's position. It is not a clue to the correct number."
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

/// Coordinates refer to the original 1284×2778 capture, never a resized phone
/// thumbnail. Cropping in the view preserves legible pixels and excludes HUD
/// controls unrelated to the explanation.
enum GuideFigure: String, CaseIterable, Identifiable {
    case board, hand, turnControls, score, route, shop, markerOffers, buffOffer

    var id: String { rawValue }
    var asset: String {
        switch self {
        case .board, .hand, .turnControls, .score: "GuideGameplay"
        case .route: "GuideRoute"
        case .shop, .markerOffers, .buffOffer: "GuideShop"
        }
    }

    var crop: CGRect {
        switch self {
        case .board: CGRect(x: 0.08, y: 0.28, width: 0.83, height: 0.38)
        case .hand: CGRect(x: 0.075, y: 0.72, width: 0.84, height: 0.083)
        case .turnControls: CGRect(x: 0.075, y: 0.72, width: 0.84, height: 0.165)
        case .score: CGRect(x: 0.075, y: 0.19, width: 0.84, height: 0.085)
        case .route: CGRect(x: 0.075, y: 0.188, width: 0.84, height: 0.18)
        case .shop: CGRect(x: 0.075, y: 0.292, width: 0.84, height: 0.19)
        case .markerOffers: CGRect(x: 0.075, y: 0.485, width: 0.84, height: 0.188)
        case .buffOffer: CGRect(x: 0.075, y: 0.679, width: 0.84, height: 0.163)
        }
    }

    var aspectRatio: CGFloat { crop.width * 1284 / (crop.height * 2778) }

    var caption: String {
        switch self {
        case .board: "The board: read the row, column and box together."
        case .hand: "Numbers Drawn: tap one card to select it."
        case .turnControls: "Select a card for Toss. Use End Turn to bank and refill."
        case .score: "Here, 290 points are banked toward a target of 1,000."
        case .route: "Your route: two ordinary Puzzles, then the Boss."
        case .shop: "Bookmark offers print their effect and coin price."
        case .markerOffers: "Marker cards explain what their squares will do."
        case .buffOffer: "In the Shop, tap Details to read a Buff's complete effect."
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .board: "Actual game board with nine rows, nine columns and bold borders around the 3 by 3 boxes. Some squares are filled, and others are empty."
        case .hand: "Actual Hand of number cards under Numbers Drawn: 5, 8, 2, 8, 8, 1, and 6."
        case .turnControls: "Actual Hand, Toss button, End Turn button and turn counter."
        case .score: "Actual score area showing banked score against the target and a progress bar."
        case .route: "Actual Next Puzzle route with Puzzle 1, Puzzle 2 and a dark Boss card with its power."
        case .shop: "Actual Bookmark offers in the Shop: Front Page Splash for 6 coins and Op-Ed Column for 5 coins."
        case .markerOffers: "Actual coloured Marker offers and their effect descriptions in the Shop."
        case .buffOffer: "Actual Paper Crane Buff offer for 3 coins, with a Details link."
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if !symbolAfter { Image(systemName: symbol).accessibilityHidden(true) }
                Text(title)
                if symbolAfter { Image(systemName: symbol).accessibilityHidden(true) }
            }
            .font(.body.weight(.semibold))
            .foregroundStyle(enabled ? Paper.ink : Paper.inkSoft)
            .frame(maxWidth: .infinity, minHeight: 44)
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var player: AVPlayer?
    let film: GuideFilm

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VideoPlayer(player: player)
                    .accessibilityLabel("Game recording: select a number, place it, and bank the turn")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("Tap a Hand card, tap its correct blank, then use End Turn to bank the queued points. You can pause or replay using the video controls.")
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(Paper.ink)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
            .background(Paper.page)
            .navigationTitle("Watch a turn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Paper.page, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .tint(Paper.ink)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: close)
                }
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
