import SwiftUI
import NumberClubEngine

/// The shelf. You arrive here on launch, and come back whenever a Book ends or
/// is abandoned — §3 makes the Starting Board a choice you make when you open a
/// Book, so one is never dealt silently.
///
/// Books are swiped through rather than listed. Only the written one can be
/// opened; the rest are locked and shown anyway, so the ladder §2 leaves
/// undecided is visible instead of implied.
struct StartBookView: View {
    var onStart: (StartingBoard) -> Void

    @State private var index = 0
    @State private var choosingBoard = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var books: [BookEdition] { BookEdition.shelf }
    private var book: BookEdition { books[min(index, books.count - 1)] }

    var body: some View {
        ZStack(alignment: .bottom) {
            ShelfBackdrop(accent: book.accent, reduceMotion: reduceMotion)

            TabView(selection: $index) {
                ForEach(Array(books.enumerated()), id: \.offset) { position, edition in
                    BookOnDesk(book: edition)
                        .tag(position)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            controls
        }
        .background(Paper.deskDark)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .animation(.easeInOut(duration: 0.35), value: index)
        .overlay {
            if choosingBoard {
                BoardChoiceSlip { board in
                    choosingBoard = false
                    onStart(board)
                } onClose: {
                    withAnimation(.snappy(duration: 0.2)) { choosingBoard = false }
                }
            }
        }
        .animation(.snappy(duration: 0.22), value: choosingBoard)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            PageDots(count: books.count, index: index)

            Text(book.isWritten ? book.shelfLabel : "Not written yet")
                .font(Print.caption(10))
                .tracking(1.8)
                .textCase(.uppercase)
                .foregroundStyle(Paper.page.opacity(0.5))

            if book.isWritten {
                PaperButton(title: "Open the Book", kind: .primary) {
                    withAnimation(.snappy(duration: 0.22)) { choosingBoard = true }
                }
            } else {
                PaperButton(title: "Locked", kind: .quiet, isEnabled: false) {}
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 26)
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

/// Deliberately not a photograph of a desk: the covers are already
/// photographed lying on one, and two desks read as a picture of a book rather
/// than as a book. It takes a wash of whichever Book is in front of you.
private struct ShelfBackdrop: View {
    var accent: Color
    var reduceMotion: Bool
    @State private var drifted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2A1E17), Color(hex: 0x120D0A)],
                               startPoint: .top, endPoint: .bottom)

                RadialGradient(
                    colors: [accent.opacity(0.20), .clear],
                    center: .init(x: 0.14, y: 0.08),
                    startRadius: 10, endRadius: proxy.size.height * 0.75
                )
                .blendMode(.plusLighter)
                .scaleEffect(drifted ? 1.06 : 1.0)

                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.58),
                        .init(color: .black.opacity(0.62), location: 0.80),
                        .init(color: .black.opacity(0.94), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.5), value: accent)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) {
                drifted = true
            }
        }
    }
}

/// One Book lying on the desk, whole. It is a cover — cropping it to fill a
/// phone throws away the tabs, the notes and half the title.
private struct BookOnDesk: View {
    var book: BookEdition

    var body: some View {
        VStack {
            Group {
                if let cover = book.cover {
                    Image(cover)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    UnwrittenCover(book: book)
                        .aspectRatio(968.0 / 1330.0, contentMode: .fit)
                }
            }
            .frame(maxWidth: 336)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.65), radius: 26, x: 6, y: 16)

            Spacer(minLength: 0)
        }
        .padding(.top, 40)
        .padding(.horizontal, 26)
        .padding(.bottom, 190)
        .accessibilityLabel(book.isWritten
            ? "\(book.title), \(book.shelfLabel)"
            : "\(book.title), not written yet")
    }
}

/// A Book that has not been written: cloth, a blocked title, a lock, and
/// nothing else that would promise something which does not exist.
private struct UnwrittenCover: View {
    var book: BookEdition

    var body: some View {
        ZStack {
            LinearGradient(colors: [book.accent.opacity(0.55), Color(hex: 0x221E1A)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            // Blind-stamped rules, the way a plain cloth binding is finished.
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                .padding(18)

            VStack(spacing: 14) {
                Image(systemName: "lock")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Paper.page.opacity(0.45))
                Text(book.title)
                    .font(Print.heading(27))
                    .foregroundStyle(Paper.page.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 26)
                Text(book.shelfLabel)
                    .font(Print.caption(10))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.page.opacity(0.35))
            }
        }
    }
}

// MARK: - Starting Board

/// §3 — chosen once, when you open a Book. It moved off the shelf so the Book
/// is the only thing on it, and it is asked on a slip because that is what the
/// rest of the game does.
private struct BoardChoiceSlip: View {
    var onChoose: (StartingBoard) -> Void
    var onClose: () -> Void
    @State private var choice: StartingBoard = .scholar

    var body: some View {
        PaperSlip(title: "Which board?",
                  subtitle: "Chosen once, for the whole Book.",
                  onClose: onClose) {
            VStack(spacing: 9) {
                ForEach(StartingBoard.allCases, id: \.self) { board in
                    Button {
                        withAnimation(.snappy(duration: 0.16)) { choice = board }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: symbol(board))
                                .font(.system(size: 17))
                                .foregroundStyle(Paper.ink)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(board.name)
                                    .font(Print.subheading(14.5))
                                    .foregroundStyle(Paper.ink)
                                Text(board.text)
                                    .font(Print.body(12))
                                    .foregroundStyle(Paper.inkSoft)
                            }
                            Spacer()
                            Image(systemName: choice == board ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18))
                                .foregroundStyle(choice == board ? Paper.sageDeep : Paper.rule)
                        }
                        .padding(11)
                        .background {
                            RoundedRectangle(cornerRadius: 5).fill(Paper.pageWarm.opacity(0.6))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(choice == board ? Paper.sageDeep : Paper.pageEdge,
                                              lineWidth: choice == board ? 2 : 1)
                        }
                    }
                    .buttonStyle(PressedPaperStyle())
                    .accessibilityLabel("\(board.name). \(board.text)")
                    .accessibilityAddTraits(choice == board ? [.isSelected] : [])
                }

                PaperButton(title: "Begin", kind: .primary) { onChoose(choice) }
                    .padding(.top, 6)
            }
        }
    }

    private func symbol(_ board: StartingBoard) -> String {
        switch board {
        case .scholar: return "graduationcap"
        case .merchant: return "bag"
        case .oracle: return "eye"
        }
    }
}
