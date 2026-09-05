import SwiftUI

/// How a Book's cover is set, so it can be drawn live instead of photographed.
///
/// A photograph of a cover is a photograph of one size, one light and one
/// title. Setting it means the type stays sharp at any size, every volume can
/// have its own words without another generation, and the whole thing costs
/// bytes rather than megabytes.
struct CoverDesign {
    /// The title, broken the way it is set — the line breaks are part of the
    /// design, not something to be worked out from the string.
    let titleLines: [String]
    /// The last line, set in the Book's own hand and colour.
    let flourish: String
    let banner: String
    let strapline: String
    let volume: String
    let imprint: String

    let stock: Color
    let ink: Color
    let accent: Color
    let secondAccent: Color
    let cloth: Color
    let notes: [Note]
    /// Bare covers are cloth and stamped type, with none of the furniture.
    let isBare: Bool
    /// Longer titles keep their deliberate line breaks at the same cover size.
    var titleScale: CGFloat = 1
    var flourishScale: CGFloat = 1

    struct Note {
        /// Where on the Book it is stuck. Named for the place rather than for
        /// a corner, because two of them hang half off the edge.
        enum Corner { case headLeft, fore, underTheFlourish }
        let lines: [String]
        let colour: Color
        let corner: Corner
        let tilt: Double
        /// Ticked lines read as a checklist rather than a scribble.
        var ticked: Bool = false
    }

    static let probably = CoverDesign(
        titleLines: ["You’ve", "Got This,"],
        flourish: "Probably",
        banner: "A Sudoku Book",
        strapline: "Relaxed Puzzles",
        volume: "Volume 1",
        imprint: "Probably Sudoku",
        stock: Color(hex: 0xEFE9D8),
        ink: Color(hex: 0x33322D),
        accent: Color(hex: 0x6E8560),
        secondAccent: Color(hex: 0xD9913F),
        cloth: Color(hex: 0x76856A),
        notes: [
            Note(lines: ["One square", "at a time."],
                 colour: Color(hex: 0xF2E3A8), corner: .fore, tilt: 2.5),
            Note(lines: ["Mistakes", "are proof", "you’re", "trying."],
                 colour: Color(hex: 0xF0A165), corner: .headLeft, tilt: -7),
            Note(lines: ["Stay calm", "Check the row", "Find the 7", "Be awesome"],
                 colour: Color(hex: 0xEFE6CC), corner: .underTheFlourish, tilt: 3, ticked: true),
        ],
        isBare: false
    )

    static let slightlyHarder = CoverDesign(
        titleLines: ["Slightly", "Harder,"],
        flourish: "Sorry",
        banner: "A Sudoku Book",
        strapline: "Brisk Puzzles",
        volume: "Volume 2",
        imprint: "Probably Sudoku",
        stock: Color(hex: 0xF1E6CE),
        ink: Color(hex: 0x322A20),
        accent: Color(hex: 0xB86628),
        secondAccent: Color(hex: 0x4E7B78),
        cloth: Color(hex: 0x9B5628),
        notes: [
            Note(lines: ["Check", "the column."],
                 colour: Color(hex: 0xE9D78C), corner: .fore, tilt: -2),
            Note(lines: ["Method", "beats", "momentum."],
                 colour: Color(hex: 0xC7DBD3), corner: .headLeft, tilt: 4),
            Note(lines: ["No guessing", "Necessary", "Today"],
                 colour: Color(hex: 0xF4D2A4), corner: .underTheFlourish, tilt: -3, ticked: true),
        ],
        isBare: false
    )

    static let noPressure = CoverDesign(
        titleLines: ["No Pressure,"],
        flourish: "Obviously",
        banner: "A Sudoku Book",
        strapline: "Editorial Puzzles",
        volume: "Volume 3",
        imprint: "Probably Sudoku",
        stock: Color(hex: 0xE7EDF1), ink: Color(hex: 0x263747),
        accent: Color(hex: 0x3E779F), secondAccent: Color(hex: 0xB34D4A),
        cloth: Color(hex: 0x385E79),
        notes: [
            Note(lines: ["Evidence", "first."], colour: Color(hex: 0xEFD694), corner: .fore, tilt: 1),
            Note(lines: ["This row", "requires", "editing."], colour: Color(hex: 0xD0E1E5), corner: .headLeft, tilt: -4),
            Note(lines: ["No", "speculation", "please."], colour: Color(hex: 0xF1C8BE), corner: .underTheFlourish, tilt: 3, ticked: true),
        ], isBare: false, titleScale: 0.86
    )

    static let bites = CoverDesign(
        titleLines: ["This One"], flourish: "Bites", banner: "A Sudoku Book",
        strapline: "Cold Puzzles", volume: "Volume 4", imprint: "Probably Sudoku",
        stock: Color(hex: 0xE7DFDE), ink: Color(hex: 0x352323),
        accent: Color(hex: 0x9E3F3C), secondAccent: Color(hex: 0x565B72), cloth: Color(hex: 0x642D2C),
        notes: [
            Note(lines: ["No", "mercy."], colour: Color(hex: 0xD8C4C2), corner: .fore, tilt: 0),
            Note(lines: ["It was", "not", "complicated."], colour: Color(hex: 0xC7CBD7), corner: .headLeft, tilt: 2),
            Note(lines: ["Check", "again."], colour: Color(hex: 0xE5C7A6), corner: .underTheFlourish, tilt: -2, ticked: true),
        ], isBare: false
    )

    static let genuinely = CoverDesign(
        titleLines: ["Good Luck."], flourish: "Genuinely.", banner: "A Sudoku Book",
        strapline: "Fresh Possibilities", volume: "Volume 5", imprint: "Probably Sudoku",
        stock: Color(hex: 0xEDE7E4), ink: Color(hex: 0x39313E),
        accent: Color(hex: 0x806392), secondAccent: Color(hex: 0x718953),
        cloth: Color(hex: 0x655073),
        notes: [
            Note(lines: ["A fresh", "start."], colour: Color(hex: 0xD4DFB9), corner: .fore, tilt: -3),
            Note(lines: ["No", "sarcasm.", "This time."], colour: Color(hex: 0xDFCDE8), corner: .headLeft, tilt: 5),
            Note(lines: ["Keep hope", "Lose the 8", "Try again"], colour: Color(hex: 0xEFE3BE), corner: .underTheFlourish, tilt: -2, ticked: true),
        ], isBare: false, flourishScale: 0.88
    )

    static let snackBreak = CoverDesign(
        titleLines: ["This Calls"], flourish: "for Snacks", banner: "A Sudoku Book",
        strapline: "Snackable Puzzles", volume: "Volume 6", imprint: "Probably Sudoku",
        stock: Color(hex: 0xF0E5CB), ink: Color(hex: 0x3B3427),
        accent: Color(hex: 0xA8792D), secondAccent: Color(hex: 0x66846A),
        cloth: Color(hex: 0x927039),
        notes: [
            Note(lines: ["Crumbs", "happen."], colour: Color(hex: 0xEBD18D), corner: .fore, tilt: 4),
            Note(lines: ["Feed", "the brain.", "Then the", "other bit."], colour: Color(hex: 0xC7DCC8), corner: .headLeft, tilt: -5),
            Note(lines: ["Finish a box", "Put kettle on", "Act casual"], colour: Color(hex: 0xF2D8B6), corner: .underTheFlourish, tilt: 2, ticked: true),
        ], isBare: false, titleScale: 0.92, flourishScale: 0.90
    )

    static let trustMe = CoverDesign(
        titleLines: ["Trust Me,"], flourish: "I Guessed", banner: "A Sudoku Book",
        strapline: "Cautious Confidence", volume: "Volume 7", imprint: "Probably Sudoku",
        stock: Color(hex: 0xE5ECE4), ink: Color(hex: 0x2A3834),
        accent: Color(hex: 0x3F807A), secondAccent: Color(hex: 0xAA8140),
        cloth: Color(hex: 0x34645E),
        notes: [
            Note(lines: ["Probably", "a 4."], colour: Color(hex: 0xEEDBA3), corner: .fore, tilt: -4),
            Note(lines: ["Source:", "a feeling.", "Check it."], colour: Color(hex: 0xC8DDD8), corner: .headLeft, tilt: 3),
            Note(lines: ["Look certain", "Check twice", "Say nothing"], colour: Color(hex: 0xE9D5C4), corner: .underTheFlourish, tilt: -3, ticked: true),
        ], isBare: false, flourishScale: 0.96
    )

    static let overthinking = CoverDesign(
        titleLines: ["Professionally"], flourish: "Overthinking", banner: "A Sudoku Book",
        strapline: "Billable Puzzles", volume: "Volume 8", imprint: "Probably Sudoku",
        stock: Color(hex: 0xE5E9ED), ink: Color(hex: 0x303943),
        accent: Color(hex: 0x586F88), secondAccent: Color(hex: 0x997841),
        cloth: Color(hex: 0x475D71),
        notes: [
            Note(lines: ["Per my", "last 7."], colour: Color(hex: 0xEAD9AD), corner: .fore, tilt: 2),
            Note(lines: ["Could be", "a meeting.", "Is a 3."], colour: Color(hex: 0xCBD8E4), corner: .headLeft, tilt: -4),
            Note(lines: ["Make a plan", "Revise plan", "Place number"], colour: Color(hex: 0xDFD4E2), corner: .underTheFlourish, tilt: 3, ticked: true),
        ], isBare: false, titleScale: 0.65, flourishScale: 0.64
    )

    static let smallVictories = CoverDesign(
        titleLines: ["Small", "Victories,"], flourish: "Big Ego", banner: "A Sudoku Book",
        strapline: "Modest Triumphs", volume: "Volume 9", imprint: "Probably Sudoku",
        stock: Color(hex: 0xEBEBDD), ink: Color(hex: 0x33372D),
        accent: Color(hex: 0x6E8560), secondAccent: Color(hex: 0xAB853A),
        cloth: Color(hex: 0x526447),
        notes: [
            Note(lines: ["Tiny", "parade."], colour: Color(hex: 0xEED996), corner: .fore, tilt: 3),
            Note(lines: ["One row.", "Standing", "ovation."], colour: Color(hex: 0xCDDCB9), corner: .headLeft, tilt: -6),
            Note(lines: ["Clear a line", "Take a bow", "Remain humble"], colour: Color(hex: 0xE8D2BC), corner: .underTheFlourish, tilt: 2, ticked: true),
        ], isBare: false, titleScale: 0.92
    )

    static let rainyDay = CoverDesign(
        titleLines: ["Panic, But"], flourish: "Economically", banner: "A Sudoku Book",
        strapline: "Prudent Puzzles", volume: "Volume 10", imprint: "Probably Sudoku",
        stock: Color(hex: 0xE2E9E4), ink: Color(hex: 0x2D3935),
        accent: Color(hex: 0x4D7771), secondAccent: Color(hex: 0xA78746),
        cloth: Color(hex: 0x3B5955),
        notes: [
            Note(lines: ["Rainy-day", "money."], colour: Color(hex: 0xD4E0CB), corner: .fore, tilt: -2),
            Note(lines: ["Keep calm.", "Keep the", "receipt."], colour: Color(hex: 0xDDD4B5), corner: .headLeft, tilt: 4),
            Note(lines: ["Count coins", "Breathe in", "Spend wisely"], colour: Color(hex: 0xC5DADA), corner: .underTheFlourish, tilt: -3, ticked: true),
        ], isBare: false, titleScale: 0.92, flourishScale: 0.64
    )

    static let secondThoughts = CoverDesign(
        titleLines: ["On Second", "Thought,"], flourish: "Nope", banner: "A Sudoku Book",
        strapline: "Selective Puzzles", volume: "Volume 11", imprint: "Probably Sudoku",
        stock: Color(hex: 0xEDE3E8), ink: Color(hex: 0x3F303D),
        accent: Color(hex: 0x8B607D), secondAccent: Color(hex: 0x5F8B84),
        cloth: Color(hex: 0x714A64),
        notes: [
            Note(lines: ["Next", "please."], colour: Color(hex: 0xC7DEDA), corner: .fore, tilt: 2),
            Note(lines: ["Love the", "confidence.", "Hate the", "selection."], colour: Color(hex: 0xE0C9D9), corner: .headLeft, tilt: -5),
            Note(lines: ["Browse once", "Raise eyebrow", "Browse again"], colour: Color(hex: 0xEFE0B9), corner: .underTheFlourish, tilt: 3, ticked: true),
        ], isBare: false, titleScale: 0.88
    )

    static let wellEarned = CoverDesign(
        titleLines: ["I Deserve"], flourish: "a Biscuit", banner: "A Sudoku Book",
        strapline: "Earned Indulgence", volume: "Volume 12", imprint: "Probably Sudoku",
        stock: Color(hex: 0xEFE5CF), ink: Color(hex: 0x3B3226),
        accent: Color(hex: 0xAA7A32), secondAccent: Color(hex: 0x837095),
        cloth: Color(hex: 0x856234),
        notes: [
            Note(lines: ["The good", "tin."], colour: Color(hex: 0xE4CEE1), corner: .fore, tilt: -3),
            Note(lines: ["Earned it.", "No further", "questions."], colour: Color(hex: 0xEBD39F), corner: .headLeft, tilt: 5),
            Note(lines: ["Finish page", "Make tea", "Claim biscuit"], colour: Color(hex: 0xD5DFC1), corner: .underTheFlourish, tilt: -2, ticked: true),
        ], isBare: false, titleScale: 0.96, flourishScale: 0.96
    )
}
