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
    /// Locked Books are cloth and a stamped title, with none of the furniture.
    let isBare: Bool

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
        imprint: "The Number Club",
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

    static func unwritten(title: String, volume: Int, accent: Color) -> CoverDesign {
        CoverDesign(
            titleLines: title.split(separator: " ").map(String.init),
            flourish: "",
            banner: "",
            strapline: "",
            volume: "Volume \(volume)",
            imprint: "The Number Club",
            // Bound but not printed: cloth boards, and the little that is on
            // them blocked in foil. Nothing that would promise a cover which
            // has not been designed yet.
            stock: Color(hex: 0x2E2A26),
            ink: Color(hex: 0xE6DFCD),
            accent: accent,
            secondAccent: accent,
            cloth: Color(hex: 0x241F1B),
            notes: [],
            isBare: true
        )
    }
}
