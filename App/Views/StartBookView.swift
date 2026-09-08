import Combine
import SwiftUI
import ProbablySudokuEngine

/// The shelf. You arrive here on launch, and come back whenever a Book ends or
/// is abandoned — a Book carries its own rules and benefit, so one is never
/// dealt silently.
///
/// Books are swiped through rather than listed. Only the written one can be
/// opened; the rest are locked and shown anyway, so the ladder §2 leaves
/// undecided is visible instead of implied.
struct StartBookView: View {
    var onStart: (BookEdition, Obstacle) -> Void
    var onContinue: () -> Void
    /// Back to the club room. Optional so the shelf still stands on its own in
    /// a preview, and so nothing about the Books themselves changed.
    var onBack: (() -> Void)? = nil
    /// A finished Book returns the shelf focused on its own next obstacle.
    /// Normal shelf entry retains its existing debug/default position.
    private let initialIndex: Int

    init(onStart: @escaping (BookEdition, Obstacle) -> Void,
         onContinue: @escaping () -> Void,
         onBack: (() -> Void)? = nil,
         initialIndex: Int? = nil) {
        self.onStart = onStart
        self.onContinue = onContinue
        self.onBack = onBack
        self.initialIndex = initialIndex ?? Self.debugIndex()
        _index = State(initialValue: self.initialIndex)
        _resumable = State(initialValue: RunStore.displayedRun())
    }

    /// A Book left part-finished. Continuing it is the first thing offered,
    /// because it is almost always what the player came back for.
    /// iCloud arrives asynchronously, so this must be state rather than a
    /// construction-time snapshot. CloudSync tells us when to refresh it;
    /// `RunStore` remains the sole authority for whether it is local or remote.
    @State private var resumable: Game?

    @State private var index: Int
    /// One clock for the whole desk, so nothing moves against anything else.
    @State private var phase: Double = 0
    /// A slower one, counted in whole turns, for the boxes at the head of the
    /// desk: each turn is one of them solving itself.
    @State private var solve: Double = 0
    @State private var idleClock = BossMotionClock()
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// `-shelfPage 5` opens on that page of the shelf.
    private static func debugIndex() -> Int {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let at = arguments.firstIndex(of: "-shelfPage"), at + 1 < arguments.count,
           let page = Int(arguments[at + 1]) { return page }
        #endif
        return 0
    }
    @State private var obstacle: Obstacle = StartBookView.debugObstacle()
    /// A locked ribbon explains the obstacle on a paper slip rather than in a
    /// system presentation. The shelf owns it because the slip lives on the
    /// desk, above whichever Book is currently in hand.
    @State private var obstacleInfo: Obstacle?

    /// `-obstacle 3` opens on that level, so each one can be looked at.
    private static func debugObstacle() -> Obstacle {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-obstacle"), index + 1 < arguments.count,
           let raw = Int(arguments[index + 1]), let level = Obstacle(rawValue: raw) {
            return level
        }
        #endif
        return .none
    }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerProfileStore.self) private var profile
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true

    private var unlockedThrough: Int {
        book.unlockedObstacleRawValue(progressByBookID: BookEdition.obstacleUnlocks(
            for: profile.profile.achievementProgress, arguments: ProcessInfo.processInfo.arguments
        ))
    }

    private var books: [BookEdition] { BookEdition.shelf }
    private var book: BookEdition { books[min(max(index, 0), books.count - 1)] }
    var selectedBookTheme: BookPresentationTheme { BookPresentationTheme(book: book.rule) }
    private var animatesIdle: Bool {
        BookAmbientMotionPolicy.shouldAnimate(
            isActive: ambientMotion && obstacleInfo == nil,
            sceneIsActive: scenePhase == .active, reduceMotion: reduceMotion, lowPower: lowPower)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // The desk stays put. Only the Books move across it, which is the
            // whole reason they are built rather than photographed: a
            // photographed Book is welded to the desk it was shot on, so
            // browsing the shelf could only slide the entire picture.
            ShelfBackdrop(book: book)

            BookShelf(books: books, index: $index, phase: phase,
                      obstacle: $obstacle, unlockedThrough: unlockedThrough,
                      onShowObstacleInfo: { obstacleInfo = $0 })

            // The bare wood above the Book, given something to do.
            SolvingBoxes(phase: solve)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 44)

            if let onBack {
                backToTheRoom(onBack)
            }

            controls

            if let obstacleInfo {
                ObstacleInfoPopup(obstacle: obstacleInfo,
                                  isLocked: ObstacleInfoPopup.lockedState(
                                      obstacle: obstacleInfo, unlockedThrough: unlockedThrough)) {
                    withAnimation(.snappy(duration: 0.2)) { self.obstacleInfo = nil }
                }
                .zIndex(2)
            }
        }
        .background(Paper.deskDark)
        .environment(\.bookPresentation, selectedBookTheme)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { setIdleAnimationRunning(animatesIdle) }
        .onChange(of: animatesIdle) { _, running in setIdleAnimationRunning(running) }
        .onDisappear { setIdleAnimationRunning(false) }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            let updated = ProcessInfo.processInfo.isLowPowerModeEnabled
            if lowPower != updated { lowPower = updated }
        }
        .onReceive(NotificationCenter.default.publisher(for: CloudSync.didReceiveExternalChange)) { _ in
            resumable = RunStore.displayedRun()
        }
        .onChange(of: index) {
            obstacle = book.availableObstacle(obstacle, progressUnlockedThrough: unlockedThrough)
        }
    }

    /// Keep SwiftUI's native interpolation local to the existing idle
    /// modifiers. The monotonic clock is sampled only when pausing/resuming,
    /// never published each frame to the picker or its selection controls.
    private func setIdleAnimationRunning(_ running: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        if running {
            guard idleClock.startedAt == nil else { return }
            idleClock.setRunning(true, at: now)
            withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
                phase += 1
            }
            withAnimation(.linear(duration: 63).repeatForever(autoreverses: false)) {
                solve += 9
            }
        } else {
            idleClock.setRunning(false, at: now)
            let elapsed = idleClock.elapsed(at: now)
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                phase = BookShelfIdleTiming.bookPhase(at: elapsed)
                solve = BookShelfIdleTiming.solvingPhase(at: elapsed)
            }
        }
    }

    /// The way out of the shelf. Small, at the top corner, and quiet — the
    /// Books are what this screen is for.
    private func backToTheRoom(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.menuOpen()
            action()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Paper.page.opacity(0.8))
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.28)))
                .contentShape(Circle())
        }
        .buttonStyle(PressedPaperStyle())
        .padding(.leading, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityLabel("Back to the main menu")
    }

    private var controls: some View {
        VStack(spacing: 10) {
            PageDots(count: books.count, index: index)

            // What the Book gives you. §3's boards are not a separate choice
            // — the Book you pick up is the board you play on.
            HStack(spacing: 8) {
                Text(book.shelfLabel)
                    .font(Print.caption(10))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.page.opacity(0.5))
                Text("·")
                    .foregroundStyle(Paper.page.opacity(0.3))
                Text(book.benefitText)
                    .font(Print.body(13))
                    .foregroundStyle(Paper.page.opacity(0.82))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            if let saved = resumable,
               saved.run.book == book.rule {
                VStack(spacing: 8) {
                    PaperButton(title: saved.run.outcome == .bookCompleted ? "See Completed Book" : "Continue the Book",
                                subtitle: saved.run.outcome == .bookCompleted ? "Your final page is ready"
                                    : "Level \(saved.run.level), Puzzle \(saved.run.slot.rawValue + 1)",
                                kind: .primary) { onContinue() }
                    PaperButton(title: "Start a New Book", kind: .quiet) {
                        onStart(book, obstacle)
                    }
                }
            } else {
                PaperButton(title: "Open the Book", kind: .primary) { onStart(book, obstacle) }
            }

        }
        .padding(.horizontal, 24)
        .padding(.bottom, 18)
    }

}

enum BookShelfIdleTiming {
    static func bookPhase(at elapsed: TimeInterval) -> Double {
        max(0, elapsed).truncatingRemainder(dividingBy: 18) / 18
    }

    static func solvingPhase(at elapsed: TimeInterval) -> Double {
        max(0, elapsed).truncatingRemainder(dividingBy: 63) / 7
    }
}

/// A locked ribbon gets a small desk card — enough to explain the rule without
/// covering the Book the player was looking at.
struct ObstacleInfoPopup: View {
    var obstacle: Obstacle
    var isLocked: Bool
    var onClose: () -> Void

    static let closeHitTarget: CGFloat = 44
    static let closeIconSize: CGFloat = 28

    static func lockedState(obstacle: Obstacle, unlockedThrough: Int) -> Bool {
        obstacle.rawValue > unlockedThrough
    }

    var statusText: String { isLocked ? "LOCKED" : "AVAILABLE" }

    var detailFooter: String {
        guard isLocked else { return "Ready to play in this Book." }
        guard let preceding = Obstacle(rawValue: obstacle.rawValue - 1) else {
            return "Finish this Book to unlock it."
        }
        return "Finish \(preceding.name) in this Book to unlock \(obstacle.name)."
    }

    var body: some View {
        ZStack {
            Button(action: onClose) {
                Color.black.opacity(0.28).ignoresSafeArea()
            }
            .buttonStyle(.plain)
            // Sighted players can tap the dimmed room to dismiss; VoiceOver
            // gets the named close control below instead of a duplicate full-
            // screen button competing with the popup's content.
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(obstacle.name)
                            .font(Print.heading(20))
                            .tracking(-0.5)
                            .foregroundStyle(Paper.ink)
                            .textCase(.uppercase)
                        Text(statusText)
                            .font(Print.caption(9)).tracking(1.4)
                            .foregroundStyle(Paper.inkFaint)
                    }
                    Spacer()
                    Button(action: onClose) {
                        ZStack {
                            Color.clear
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Paper.inkSoft)
                                .frame(width: Self.closeIconSize, height: Self.closeIconSize)
                                .background(Circle().fill(Paper.rule.opacity(0.35)))
                        }
                        .frame(width: Self.closeHitTarget, height: Self.closeHitTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close obstacle details")
                }

                Rectangle().fill(Paper.rule).frame(height: 1).padding(.vertical, 12)

                Text(obstacle.text)
                    .font(Print.body(16))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailFooter)
                    .font(Print.body(12.5))
                    .foregroundStyle(Paper.inkSoft)
                    .padding(.top, 8)
            }
            .padding(18)
            .frame(maxWidth: 280, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Paper.page)
                    .overlay { PaperGrain(opacity: 0.045) }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15)
                            .strokeBorder(Paper.pageEdge, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.42), radius: 18, x: 2, y: 10)
            }
            .padding(.horizontal, 40)
        }
        .accessibilityElement(children: .contain)
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }
}

/// The Books, laid along the desk and slid across it.
///
/// Deliberately not a paging TabView: that moves a whole screen at a time,
/// which is what made the desk travel with the Book. Here the desk is behind
/// and still, and only this row of Books moves — so the shelf reads as objects
/// on a surface rather than as a slideshow of pictures.
private struct BookShelf: View {
    var books: [BookEdition]
    @Binding var index: Int
    var phase: Double
    @Binding var obstacle: Obstacle
    var unlockedThrough: Int
    var onShowObstacleInfo: (Obstacle) -> Void

    @State private var drag: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Full screen, not the safe area: the notch is deeper than the home
        // indicator, so centring inside the insets puts the Book off-centre.
        GeometryReader { proxy in
            let width = proxy.size.width
            let bookWidth = width * 0.84
            let bookHeight = bookWidth * 1.4
            let step = width * 0.98          // neighbours peek in at both edges

            HStack(spacing: step - bookWidth) {
                ForEach(Array(books.enumerated()), id: \.offset) { position, edition in
                    LiveBook(edition: edition, phase: phase,
                             ribbons: ribbons(for: edition, at: position))
                        .frame(width: bookWidth)
                        // The Book in hand is full size and lit; the others are
                        // further off along the desk.
                        .scaleEffect(scale(for: position, step: step))
                        .opacity(opacity(for: position, step: step))
                }
            }
            .frame(width: width, alignment: .leading)
            // A hair left of centre: the bookmarks stand out past the
            // fore-edge, so the Book's own middle is not where its weight is.
            .offset(x: (width - bookWidth) / 2 - width * 0.018
                       - CGFloat(index) * step + drag)
            .frame(width: width, height: bookHeight)
            .frame(width: width, height: proxy.size.height)
            // The Book stays in the same position whether it has one or two
            // actions below it. Moving it up hid the solving boards at the
            // top of the desk on a resumed Book.
            .offset(y: -proxy.size.height * 0.022)
            .contentShape(Rectangle())
            .gesture(
                DragGesture()
                    .onChanged { value in drag = resisted(value.translation.width) }
                    .onEnded { value in
                        // Predicted end, so a flick carries further than a drag.
                        let pages = (-value.predictedEndTranslation.width / step).rounded()
                        let target = min(max(index + Int(pages), 0), books.count - 1)
                        let settle: Animation = reduceMotion
                            ? .linear(duration: 0.01)
                            : .interactiveSpring(response: 0.26, dampingFraction: 0.86,
                                                 blendDuration: 0.1)
                        withAnimation(settle) {
                            index = target
                            drag = 0
                        }
                    }
            )
        }
        .ignoresSafeArea()
    }

    /// A Book only carries ribbons when it is the one in hand, and only a
    /// written and unlocked one can be started at all.
    private func ribbons(for edition: BookEdition, at position: Int) -> LiveBook.RibbonStrip? {
        guard edition.isWritten, edition.isUnlocked, position == index else { return nil }
        return LiveBook.RibbonStrip(
            levels: Obstacle.allCases,
            selected: obstacle,
            isUnlocked: { $0.rawValue <= unlockedThrough },
            onPick: { obstacle = $0 },
            onShowInfo: onShowObstacleInfo
        )
    }

    /// Past either end the row still gives, but grudgingly — the resistance is
    /// what says the shelf has run out, so nothing has to be shown behind it.
    private func resisted(_ translation: CGFloat) -> CGFloat {
        let atStart = index == 0 && translation > 0
        let atEnd = index == books.count - 1 && translation < 0
        return (atStart || atEnd) ? translation * 0.3 : translation
    }

    private func distance(for position: Int, step: CGFloat) -> CGFloat {
        abs(CGFloat(position - index) - drag / step)
    }

    private func scale(for position: Int, step: CGFloat) -> CGFloat {
        max(0.82, 1 - distance(for: position, step: step) * 0.14)
    }

    private func opacity(for position: Int, step: CGFloat) -> Double {
        max(0.32, 1 - distance(for: position, step: step) * 0.58)
    }
}

/// Which Book you are looking at, and how many there are.
private struct PageDots: View {
    var count: Int
    var index: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { position in
                Circle()
                    .fill(Paper.page.opacity(position == index ? 0.85 : 0.28))
                    .frame(width: position == index ? 7 : 5,
                           height: position == index ? 7 : 5)
            }
        }
        .animation(.snappy(duration: 0.2), value: index)
        .accessibilityLabel("Book \(index + 1) of \(count)")
    }
}

// MARK: - Backdrop

/// The desk. It never moves: it is the fixed thing the Books are slid across,
/// and the moment it drifts the shelf stops reading as objects on a surface.
/// It takes a wash of whichever Book is in front of you.
/// Shared with the opening: it has to be the *same* desk, or the cut from the
/// shelf to the Book opening is visible.
struct ShelfBackdrop: View {
    var book: BookEdition

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: 0x120D0A)

                // The shelf owns its own quiet space. A photographed desk
                // leaks through behind locked covers and during rubber-band
                // overscroll, which makes the carousel read as a page laid on
                // another scene rather than a shelf of its own.
                LinearGradient(colors: [Color(hex: 0x221B17), Color(hex: 0x090B0D)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)

                // The Book in front tints the light falling on the desk.
                RadialGradient(
                    colors: [book.accent.opacity(0.14), .clear],
                    center: .init(x: 0.14, y: 0.08),
                    startRadius: 10, endRadius: proxy.size.height * 0.75
                )
                .blendMode(.plusLighter)

                // Just enough shade at the foot for the controls to sit on.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.30), location: 0),
                        .init(color: .clear, location: 0.16),
                        .init(color: .clear, location: 0.66),
                        .init(color: .black.opacity(0.42), location: 0.86),
                        .init(color: .black.opacity(0.70), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.45), value: book.id)
    }
}
