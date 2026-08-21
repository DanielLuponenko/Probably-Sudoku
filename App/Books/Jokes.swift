import Foundation

/// What is written on the first page, under the cover.
///
/// You see it for about a second while the board is still swinging, and only
/// if you happen to look down at the page rather than at the movement. That is
/// the whole idea: it is not a loading screen with a tip on it, it is the kind
/// of thing someone had printed inside a puzzle book because there was a page
/// spare.
///
/// So they are short. Anything that takes a sentence to land will not be read,
/// and a joke nobody reads is just clutter on a page that should look empty.
enum Jokes {
    /// Drawn fresh every time a Book is opened, so the page is never quite the
    /// same page twice.
    static func random() -> String {
        all.randomElement() ?? all[0]
    }

    static let all: [String] = [
        "Nine is enough.",
        "There is only one answer. Sorry.",
        "The 7 is always the problem.",
        "No maths required. Allegedly.",
        "Guessing counts. Nobody will know.",
        "Pencil first. Always pencil first.",
        "Every square knows something.",
        "The grid is patient. You are not.",
        "Three is a crowd. Nine is a puzzle.",
        "Row, column, box. In that order.",
        "If it fits twice, it fits never.",
        "Easy is a marketing term.",
        "You have already used that 4.",
        "Count again. You always do.",
        "The eraser is part of the kit.",
        "One wrong number ruins nine.",
        "Nobody solves the middle first.",
        "It is not luck. Mostly.",
        "The answer was there an hour ago.",
        "Blank squares are just shy.",
        "Expert means bring tea.",
        "A 5 walks into a row.",
        "Symmetry is a promise, not a rule.",
        "You are allowed to stop.",
        "Check the corner. It is the corner.",
        "Two 8s in a row is a lifestyle.",
        "Eighty-one squares, one grudge.",
        "The pencil marks are load-bearing.",
        "Confidence peaks at square 40.",
        "There is no 10. Stop looking.",
        "Half solved is fully committed.",
        "A clean grid hides nothing.",
        "The 1s are the easy part. Usually.",
        "Everyone restarts once.",
        "Numbers do not care how you feel.",
        "You can hear a wrong 6.",
        "Nine boxes, nine chances.",
        "The last square takes the longest.",
        "This grid has been solved before.",
        "Trust the row, not the feeling.",
        "Coffee counts as a technique.",
        "The puzzle is not personal.",
        "Some squares are decoration.",
        "You looked at that 3 for ten minutes.",
        "It was a 2. It was always a 2.",
        "Scanning is just slow guessing.",
        "The middle box is lying to you.",
        "Nothing here is random.",
        "A solved grid tells you nothing.",
        "Put the pen down.",
        "The 9 knows where it lives.",
        "Every mistake is nine mistakes.",
        "Doubt the 5 first.",
        "This one is easy. For someone.",
    ]
}
