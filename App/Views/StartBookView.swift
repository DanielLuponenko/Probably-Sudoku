import SwiftUI
import NumberClubEngine

/// The shelf. You arrive here on launch, and come back whenever a Book ends or
/// is abandoned — §3 makes the Starting Board a choice you make when you open a
/// Book, so one is never dealt silently.
///
/// Picking up a Book puts it on the desk in front of you. Only the written one
/// can be opened; the rest are there so the ladder above it is visible rather
/// than implied.
struct StartBookView: View {
    var onStart: (StartingBoard) -> Void

    @State private var book: BookEdition = .first
    @State private var choice: StartingBoard = .scholar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .bottom) {
            DeskBackdrop(reduceMotion: reduceMotion)
            BookOnDesk(book: book)
            controls
        }
        .background(Paper.deskDark)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var controls: some View {
        VStack(spacing: 14) {
            ShelfRow(books: BookEdition.shelf, selected: book) { picked in
                withAnimation(.snappy(duration: 0.28)) { book = picked }
            }

            if book.isWritten {
                VStack(spacing: 8) {
                    BoardChips(choice: $choice)
                    PaperButton(title: "Open the Book", kind: .primary) { onStart(choice) }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                Text(book.blurb)
                    .font(Print.body(13))
                    .foregroundStyle(Paper.page.opacity(0.6))
                    .frame(height: 106)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .animation(.snappy(duration: 0.28), value: book)
    }
}

// MARK: - Backdrop

/// The desk the Books sit on. Constant across Books; only the Book changes.
private struct DeskBackdrop: View {
    var reduceMotion: Bool
    @State private var drifted = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Deliberately not a photograph of a desk: the cover is
                // already photographed lying on one, and two desks read as a
                // picture of a book rather than a book.
                LinearGradient(
                    colors: [Color(hex: 0x2A1E17), Color(hex: 0x120D0A)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(drifted ? 1.04 : 1.0)

                RadialGradient(
                    colors: [Color(hex: 0xFFD9A0).opacity(0.16), .clear],
                    center: .init(x: 0.14, y: 0.06),
                    startRadius: 10, endRadius: proxy.size.height * 0.8
                )
                .blendMode(.plusLighter)

                // Deep shade at the foot, so the shelf and the chips sit on
                // desk rather than on artwork.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.52),
                        .init(color: .black.opacity(0.55), location: 0.74),
                        .init(color: .black.opacity(0.92), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 30).repeatForever(autoreverses: true)) {
                drifted = true
            }
        }
    }
}

/// The Book lying on the desk, whole. It is a cover — cropping it to fill a
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
                        .aspectRatio(2.0 / 3.0, contentMode: .fit)
                }
            }
            .frame(maxWidth: 348)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .shadow(color: .black.opacity(0.65), radius: 26, x: 6, y: 16)
            .id(book.id)
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
            .padding(.top, 34)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 250)
        .accessibilityLabel(book.title)
    }
}

/// A Book that has not been written yet: cloth, a blocked title, and nothing
/// else to promise something that does not exist.
private struct UnwrittenCover: View {
    var book: BookEdition

    var body: some View {
        ZStack {
            LinearGradient(colors: [book.accent.opacity(0.55), Color(hex: 0x24201C)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 12) {
                Image(systemName: "lock")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(Paper.page.opacity(0.5))
                Text(book.title)
                    .font(Print.heading(26))
                    .foregroundStyle(Paper.page.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
        }
    }
}

// MARK: - Shelf

private struct ShelfRow: View {
    var books: [BookEdition]
    var selected: BookEdition
    var pick: (BookEdition) -> Void

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 12) {
                ForEach(books) { book in
                    Button { pick(book) } label: {
                        ShelfSpine(book: book, isSelected: book == selected)
                    }
                    .buttonStyle(PressedPaperStyle())
                    .accessibilityLabel(book.isWritten
                        ? "\(book.title), \(book.shelfLabel)"
                        : "\(book.title), not yet written")
                    .accessibilityAddTraits(book == selected ? [.isSelected] : [])
                }
            }

            if !selected.isWritten {
                Text("Not yet written")
                    .font(Print.caption(10))
                    .tracking(1.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.page.opacity(0.5))
            }
        }
    }
}

private struct ShelfSpine: View {
    var book: BookEdition
    var isSelected: Bool

    var body: some View {
        Group {
            if let cover = book.cover {
                Image(cover)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(colors: [book.accent.opacity(0.7), Color(hex: 0x24201C)],
                               startPoint: .top, endPoint: .bottom)
                    .overlay {
                        Image(systemName: "lock")
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(Paper.page.opacity(0.5))
                    }
            }
        }
        .frame(width: 52, height: 74)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(isSelected ? Paper.page.opacity(0.85) : .black.opacity(0.4),
                              lineWidth: isSelected ? 2 : 1)
        }
        .saturation(book.isWritten ? 1 : 0.6)
        .opacity(isSelected ? 1 : 0.55)
        .scaleEffect(isSelected ? 1 : 0.92)
        .shadow(color: .black.opacity(0.6), radius: isSelected ? 10 : 4, y: 4)
    }
}

// MARK: - Starting Board

/// §3, compressed to a row: three chips rather than three cards, so the Book
/// behind them stays the thing you are looking at.
private struct BoardChips: View {
    @Binding var choice: StartingBoard

    var body: some View {
        HStack(spacing: 8) {
            ForEach(StartingBoard.allCases, id: \.self) { board in
                Button {
                    withAnimation(.snappy(duration: 0.18)) { choice = board }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: symbol(board))
                            .font(.system(size: 15, weight: .regular))
                        Text(board.name.replacingOccurrences(of: "'s Board", with: ""))
                            .font(Print.caption(11))
                            .tracking(0.4)
                        Text(board.text)
                            .font(Print.body(9.5))
                            .foregroundStyle(Paper.inkSoft)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(Paper.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 74)
                    .padding(.horizontal, 4)
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Paper.page.opacity(choice == board ? 1 : 0.88))
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
