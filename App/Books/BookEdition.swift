import SwiftUI
import ProbablySudokuEngine

/// A Book is a published thing with a personality, not just a difficulty tier.
/// The first one is cheerful and faintly unsure of itself, and it talks to the
/// player in the margins.
struct BookEdition: Identifiable, Equatable {
    let id: String
    let rule: Book
    let title: String
    /// Printed on the shelf under the cover.
    let shelfLabel: String
    let blurb: String
    /// The Book photographed on the desk, already in phone format. This is the
    /// whole screen: no cover is composited onto a separate background, because
    /// two woods leave a seam and cutting the Book out fragments its index
    /// tabs. Nil while a Book is unwritten.
    let cover: String?
    /// The Book's own colour, used for its spine and its accents.
    let accent: Color
    /// §3 — what this Book gives you for the whole run. The board is not a
    /// separate choice: it is what the Book is.
    let bonus: StartingBoard

    var bonusText: String { bonus.text }
    var design: CoverDesign {
        guard isWritten else {
            let volume = Int(shelfLabel.replacingOccurrences(of: "Volume ", with: "")) ?? 1
            return .unwritten(title: title, volume: volume, accent: accent)
        }
        switch rule {
        case .probably: return .probably
        case .slightlyHarder: return .slightlyHarder
        case .noPressure: return .noPressure
        case .bites: return .bites
        }
    }
    /// A written Book can be opened; a future volume stays visibly shelved.
    var isWritten: Bool { cover != nil }
    var isUnlocked: Bool {
        guard isWritten else { return false }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-unlockAll") { return true }
        #endif
        return RunStore.booksCompleted >= rule.volume - 1
    }

    /// Lines the Book writes in the margins while you play.
    let marginalia: [String]

    static func == (a: BookEdition, b: BookEdition) -> Bool { a.id == b.id }

    static let first = BookEdition(
        id: "probably",
        rule: .probably,
        title: "You\u{2019}ve Got This, Probably",
        shelfLabel: "Volume 1",
        blurb: "Relaxed puzzles. Encouragement not guaranteed.",
        cover: "SceneProbably",
        accent: Color(hex: 0x7C8C73),
        // A relaxed Book hands you more to work with.
        bonus: .scholar,
        marginalia: firstBookLines
    )

    static let second = BookEdition(
        id: "sorry",
        rule: .slightlyHarder,
        title: "Slightly Harder, Sorry",
        shelfLabel: "Volume 2",
        blurb: "Brisk puzzles. Professional disappointment included.",
        cover: "SceneSorry",
        accent: Color(hex: 0xC8853F),
        // The second Book keeps the first Book's Board: its only rule change
        // is three fewer givens at every slot.
        bonus: .scholar,
        marginalia: secondBookLines
    )

    static let third = BookEdition(
        id: "pressure",
        rule: .noPressure,
        title: "No Pressure, Obviously",
        shelfLabel: "Volume 3",
        blurb: "Editorial puzzles. The board has notes.",
        cover: "ScenePressure",
        accent: Color(hex: 0x6F9EC4),
        bonus: .scholar,
        marginalia: thirdBookLines
    )

    static let fourth = BookEdition(
        id: "bites",
        rule: .bites,
        title: "This One Bites",
        shelfLabel: "Volume 4",
        blurb: "Cold puzzles. The board does not care.",
        cover: "SceneBites",
        accent: Color(hex: 0xB4544A),
        bonus: .scholar,
        marginalia: fourthBookLines
    )

    /// The remaining unwritten volumes still show their place in the ladder,
    /// but do not claim rules or voices that belong to their own tickets.
    static let unwritten: [BookEdition] = [
        unwritten(id: "genuinely", title: "Good Luck. Genuinely.",
                  volume: 5, accent: Color(hex: 0x8E7BA8), bonus: .oracle),
        unwritten(id: "future-6", title: "Not Written Yet",
                  volume: 6, accent: Color(hex: 0x857D70), bonus: .oracle),
        unwritten(id: "future-7", title: "Not Written Yet",
                  volume: 7, accent: Color(hex: 0x708F86), bonus: .oracle),
        unwritten(id: "future-8", title: "Not Written Yet",
                  volume: 8, accent: Color(hex: 0x8D758F), bonus: .oracle),
        unwritten(id: "future-9", title: "Not Written Yet",
                  volume: 9, accent: Color(hex: 0x8C946C), bonus: .oracle),
    ]

    private static func unwritten(id: String, title: String, volume: Int,
                                  accent: Color, bonus: StartingBoard) -> BookEdition {
        BookEdition(
            id: id,
            rule: .slightlyHarder,
            title: title,
            shelfLabel: "Volume \(volume)",
            blurb: "Not written yet.",
            cover: nil,
            accent: accent,
            bonus: bonus,
            marginalia: []
        )
    }

    static let shelf: [BookEdition] = [first, second, third, fourth] + unwritten

    static func edition(for book: Book) -> BookEdition {
        shelf.first { $0.rule == book && $0.isWritten } ?? first
    }
}

private let fourthBookLines: [String] = (1...100).map { note in
    let openings = [
        "", "Still, ", "Again, ", "Plainly, ", "Naturally, ",
        "Predictably, ", "Unfortunately, ", "Of course, ", "Quietly, ", "Finally, "
    ]
    let observations = [
        "The row remains incomplete.", "That candidate is wrong.", "The column has no sympathy.",
        "There is one legal square.", "The board has not changed its mind.",
        "A guess is still a guess.", "The box rejects that number.", "Continue.",
        "The solution is indifferent to effort.", "Find the constraint."
    ]
    return "\(openings[(note - 1) / 10])\(observations[(note - 1) % 10])"
}

private let thirdBookLines: [String] = (1...100).map { note in
    let openings = [
        "Editorial note:", "For the record:", "A small correction:", "As expected:",
        "Let us be precise:", "Unsurprisingly:", "A reminder:", "In brief:",
        "The evidence says:", "Please observe:"
    ]
    let observations = [
        "the row already rules that out.", "the column has made its position clear.",
        "this box has only one credible option.", "the candidate list is not decorative.",
        "the 7 cannot be everywhere at once.", "the givens are sufficient.",
        "a guess would add nothing useful.", "the intersection resolves this neatly.",
        "the remaining square is constrained.", "the board prefers a defensible move."
    ]
    return "\(openings[(note - 1) / 10]) \(observations[(note - 1) % 10])"
}

private let secondBookLines: [String] = [
    "Proceed methodically.", "The row has not improved by being ignored.",
    "Check the column, please.", "A pencil mark is not a commitment.",
    "There is a correct answer. Locate it.", "Try the obvious square first.",
    "One clean deduction will do.", "The box is waiting for your attention.",
    "You have enough information.", "Re-read the givens.",
    "A pause is acceptable. A guess is not.", "Start with the constrained digit.",
    "The 7 is not going to place itself.", "Verify before you commit.",
    "That candidate has consequences.", "Work the smallest possibility set.",
    "A tidy grid supports a tidy mind.", "There is no prize for rushing.",
    "This is solvable. Continue.", "The numbers are being quite clear.",
    "Check the box intersection.", "Use the information already present.",
    "A single exclusion is progress.", "You may begin with the easy part.",
    "The row needs one number. Find it.", "Keep the pencil marks useful.",
    "That square has narrowed nicely.", "Do not overcomplicate a 4.",
    "The column disagrees. Resolve it.", "A correction now saves time later.",
    "Please inspect the middle box.", "The candidates are a map, not decoration.",
    "Good. Now repeat that reasoning.", "The answer is constrained, not hidden.",
    "No need for theatrics; use the givens.", "This deduction is available to you.",
    "Compare the two remaining positions.", "The next step is smaller than it looks.",
    "You can eliminate more than one option here.", "The row is nearly complete.",
    "Take the cleanest available move.", "A blank square is a request for analysis.",
    "The 3x3 box has an opinion.", "Check whether the 6 can travel.",
    "The contradiction is informative.", "That was a sound placement.",
    "Continue while the pattern is visible.", "The grid rewards consistency.",
    "Look for the lone candidate.", "You have seen this shape before.",
    "The column is more constrained than it appears.", "Write down the candidates that matter.",
    "This is not a speed test.", "There is a clean line through this box.",
    "The givens have already done the hard part.", "Review the peer squares.",
    "A measured move is still a move.", "The 8 has only one sensible home.",
    "Keep going; the structure is holding.", "You can rule that out immediately.",
    "The remaining choices are not equal.", "Trust the constraint, then verify it.",
    "This row is ready for a decision.", "One deduction at a time is sufficient.",
    "The pattern is not accidental.", "Make the placement you can defend.",
    "You are narrowing the board correctly.", "The box is simpler than the whole grid.",
    "Check the pairs before expanding the search.", "A reliable method scales.",
    "Nothing is gained by placing a hopeful 9.", "That intersection is worth another look.",
    "The next number is earned, not guessed.", "Keep the evidence on the page.",
    "The candidate list has become useful.", "This is a good place to slow down.",
    "The row and column agree on one thing.", "A clear exclusion is a clear advance.",
    "The puzzle is offering you a simple move.", "Stay with the local constraints.",
    "You are one check away from certainty.", "The 5 has been accounted for.",
    "A correct square improves three units at once.", "The board is becoming more cooperative.",
    "Please do not invent extra difficulty.", "There is no ambiguity in that box.",
    "The clean solution is usually nearby.", "Good work. Continue the process.",
    "This candidate cannot survive the column.", "The remaining blank has a limited future.",
    "A careful check is faster than an undo.", "The grid is not negotiating.",
    "That move was appropriately justified.", "Use the row to settle the box.",
    "The answer has fewer places to hide now.", "You are making the puzzle smaller.",
    "Finish the deduction before changing tactics.", "The last few blanks are still governed by rules.",
    "Complete the line, then inspect the next one.", "Correctness first. Momentum second."
]

private let firstBookLines: [String] = [
        "Confidence first. Double-checking second.",
        "You are only one correct 7 away from greatness.",
        "Mistakes were made. Progress was also made.",
        "This looks difficult, which is rude.",
        "One square at a time. Preferably the correct square.",
        "You absolutely know what you're doing. Mostly.",
        "Trust yourself. Then check the column.",
        "Every blank square is just an answer being dramatic.",
        "Deep breath. Tiny numbers.",
        "You've solved harder things than this. Probably.",
        "If in doubt, blame the 8.",
        "Today feels like a good day to find a 6.",
        "Progress is progress, even when it looks suspicious.",
        "The answer is in there somewhere. Very reassuring.",
        "You don't need luck. But we included some anyway.",
        "That empty square believes in you.",
        "Try logic first. Mild panic can come later.",
        "One row closer to pretending this was easy.",
        "Look at you, doing mathematics voluntarily.",
        "Stay calm. The numbers can smell fear.",
        "Every great puzzle begins with several blank stares.",
        "If everything fits, act like you planned it.",
        "You are doing better than the empty cells.",
        "The 4 is out there. Find it.",
        "Sometimes the smartest move is staring at the page longer.",
        "One correct number can fix an entire afternoon.",
        "There are only nine numbers. How bad could it be?",
        "Don't rush. The puzzle isn't going anywhere.",
        "That row is almost impressed with you.",
        "You're not stuck. You're gathering dramatic tension.",
        "Check the box. Then check your confidence.",
        "Somewhere on this page is an embarrassingly obvious answer.",
        "The good news: there is definitely a solution.",
        "The bad news: you still have to find it.",
        "You came here to solve numbers. So solve some numbers.",
        "The first answer is always the hardest. Except when it isn't.",
        "Be patient. Even geniuses stare at squares.",
        "One tiny breakthrough can make you feel unreasonably powerful.",
        "This puzzle has underestimated you.",
        "It's okay to guess emotionally. Just don't place it yet.",
        "Your future self already knows this answer.",
        "That suspicious-looking 5 might actually be useful.",
        "You are one pencil mark away from clarity.",
        "Keep going. The satisfying part is coming.",
        "Nobody needs to know how long that 3 took.",
        "A correct number is a correct number. Take the win.",
        "The page is blank. Your brain is not.",
        "You've got nine options and at least one good idea.",
        "Slow is smooth. Smooth is somehow still Sudoku.",
        "The puzzle is testing your patience. Very original.",
        "When one corner makes no sense, bother another corner.",
        "You don't have to solve everything at once.",
        "Start with what you know. Pretend the rest is intentional suspense.",
        "Some answers arrive quickly. Others demand snacks.",
        "You're closer than you were thirty seconds ago.",
        "The solution hasn't moved. That helps.",
        "There is no shame in checking the row again.",
        "You are allowed to feel proud of a single square.",
        "Today's goal: fewer blanks than yesterday.",
        "A difficult puzzle is just an easy puzzle with an attitude.",
        "If this were obvious, it wouldn't be nearly as satisfying.",
        "Keep your standards high and your pencil nearby.",
        "One number. Then another. Very advanced strategy.",
        "You're doing excellent work for someone surrounded by empty boxes.",
        "That 9 is definitely hiding something.",
        "The puzzle wants patience. Give it slightly less than requested.",
        "There's always a moment when suddenly everything makes sense.",
        "We are patiently waiting for that moment too.",
        "You don't need to be brilliant. Just annoyingly persistent.",
        "Persistence is basically intelligence that refuses to leave.",
        "Check the row. Check the column. Become unstoppable.",
        "That was either a breakthrough or a very confident mistake.",
        "If it works, congratulations. If not, character development.",
        "Every mistake removes at least one terrible idea.",
        "The puzzle cannot win. It doesn't even have thumbs.",
        "You're allowed to celebrate finding a 2.",
        "Tiny victories are still victories.",
        "The last few squares always think they're special.",
        "Don't let one stubborn box ruin your whole page.",
        "Your brain is doing more than it looks like.",
        "The answer may be obvious after you find it. How convenient.",
        "Keep going until the page admits defeat.",
        "There is something deeply satisfying about proving a square wrong.",
        "You're doing fine. The dramatic staring is part of the process.",
        "No pressure. Except the entirely self-imposed pressure.",
        "Maybe take another look at the 3x3 box pretending not to matter.",
        "Good decisions sometimes begin with “Wait a second…”",
        "One day you'll look back and wonder why that 6 took so long.",
        "Today is not that day.",
        "Clear row, clear mind. Sort of.",
        "If the numbers start looking weird, blink.",
        "Strong puzzle solving. Questionable posture.",
        "You don't need a perfect start to get a perfect finish.",
        "The page doesn't care how many times you erased it.",
        "Keep solving. We'll pretend you never hesitated.",
        "Somewhere between “I have no idea” and “obviously” is the answer.",
        "That next square could change everything. No pressure.",
        "You're one good observation away from looking extremely clever.",
        "Finished is just a lot of tiny correct choices stacked together.",
        "You've got this. Probably. And honestly, probably is enough.",
    ]
