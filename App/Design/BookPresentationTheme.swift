import SwiftUI
import UIKit
import ProbablySudokuEngine

/// A Book keeps its own ink through the entire run. The edition catalog owns
/// the hue; this small presentation value adds readable control inks and one
/// piece of marginal animation, without changing puzzle rules or save data.
struct BookPresentationTheme: Equatable {
    let book: Book
    let accent: Color
    let buttonFill: Color
    let buttonForeground: Color
    let motif: BookAmbientMotif
    private let darkPaperQuietInk: Color

    init(book: Book) {
        // Immutable palettes are prepared once. Score changes may redraw a
        // page often, but never need to run another UIColor contrast search.
        self = Self.catalog[book] ?? Self(uncachedBook: book)
    }

    private init(uncachedBook book: Book) {
        self.book = book
        accent = BookEdition.edition(for: book).accent
        buttonForeground = Paper.page
        // Quiet actions print this same ink on the warmer (darker) paper.
        // Passing contrast on the cream primary label alone is insufficient.
        buttonFill = Self.readableInk(accent, on: Paper.pageWarm)
        motif = BookAmbientMotif.forBook(book)
        darkPaperQuietInk = accent.mixed(with: Paper.page, by: 0.48)
    }

    /// Dark cosmetic paper needs the cover's lighter ink for outline buttons.
    /// The filled button always keeps its own cream-on-Book-ink treatment.
    func quietInk(onDarkPaper: Bool) -> Color {
        onDarkPaper ? darkPaperQuietInk : buttonFill
    }

    static let first = BookPresentationTheme(book: .probably)

    // Call the private initializer directly: the public initializer reads this
    // cache, so using it here would recursively initialize the static catalog.
    private static let catalog = Dictionary(uniqueKeysWithValues: Book.allCases.map {
        ($0, BookPresentationTheme(uncachedBook: $0))
    })

    private static func readableInk(_ accent: Color, on paper: Color) -> Color {
        // Keep the authored hue and saturation instead of mapping every pale
        // cover back to the same sage button. Darken only as much as necessary.
        for step in 0...20 {
            let candidate = accent.mixed(with: .black, by: Double(step) * 0.025)
            if contrast(candidate, paper) >= 4.5 { return candidate }
        }
        return accent.mixed(with: .black, by: 0.55)
    }

    static func contrast(_ first: Color, _ second: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            func linear(_ component: CGFloat) -> Double {
                let value = Double(component)
                return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

enum BookAmbientMotif: String, CaseIterable {
    case encouragementRays
    case difficultUnderlines
    case breathingRings
    case paperBites
    case luckyPetals
    case teaSteam
    case tentativeArrows
    case thinkingBrackets
    case victoryLaurels
    case rainySavings
    case revisionLoops
    case biscuitStamp

    static func forBook(_ book: Book) -> Self {
        switch book {
        case .probably: .encouragementRays
        case .slightlyHarder: .difficultUnderlines
        case .noPressure: .breathingRings
        case .bites: .paperBites
        case .genuinely: .luckyPetals
        case .snackBreak: .teaSteam
        case .trustMe: .tentativeArrows
        case .overthinking: .thinkingBrackets
        case .smallVictories: .victoryLaurels
        case .rainyDay: .rainySavings
        case .secondThoughts: .revisionLoops
        case .wellEarned: .biscuitStamp
        }
    }
}

extension EnvironmentValues {
    @Entry var bookPresentation: BookPresentationTheme = .first
}

/// Explicit gates also let snapshot/page-turn owners stop ornamental work.
enum BookAmbientMotionPolicy {
    static func shouldAnimate(isActive: Bool, sceneIsActive: Bool,
                              reduceMotion: Bool, lowPower: Bool) -> Bool {
        isActive && sceneIsActive && !reduceMotion && !lowPower
    }
}
