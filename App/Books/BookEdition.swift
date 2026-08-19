import SwiftUI

/// A Book is a published thing with a personality, not just a difficulty tier.
/// The first one is cheerful and faintly unsure of itself, and it talks to the
/// player in the margins.
struct BookEdition: Identifiable, Equatable {
    let id: String
    let title: String
    /// Printed on the shelf under the cover.
    let shelfLabel: String
    let blurb: String
    /// Asset name of the cover photograph, or nil while a Book is unwritten.
    let cover: String?
    /// The Book's own colour, used for its spine and its accents.
    let accent: Color
    /// §2 leaves the ladder of harder Books undecided, so the rest are shelved
    /// rather than pretended into existence.
    var isWritten: Bool { cover != nil }

    /// Lines the Book writes in the margins while you play.
    let marginalia: [String]

    static func == (a: BookEdition, b: BookEdition) -> Bool { a.id == b.id }

    static let first = BookEdition(
        id: "probably",
        title: "You\u{2019}ve Got This, Probably",
        shelfLabel: "Volume 1",
        blurb: "Relaxed puzzles. Encouragement not guaranteed.",
        cover: "BookProbably",
        accent: Color(hex: 0x7C8C73),
        marginalia: firstBookLines
    )

    /// Placeholders for the ladder above it. They can be picked up and looked
    /// at — the cover changes behind them — but not opened.
    static let unwritten: [BookEdition] = [
        BookEdition(
            id: "sharpen",
            title: "Sharpen Up",
            shelfLabel: "Volume 2",
            blurb: "Not yet written.",
            cover: nil,
            accent: Color(hex: 0xC8853F),
            marginalia: []
        ),
        BookEdition(
            id: "nonsense",
            title: "No More Nonsense",
            shelfLabel: "Volume 3",
            blurb: "Not yet written.",
            cover: nil,
            accent: Color(hex: 0xB4544A),
            marginalia: []
        ),
    ]

    static let shelf: [BookEdition] = [first] + unwritten

    static func edition(forBookTier tier: Int) -> BookEdition {
        shelf.indices.contains(tier - 1) ? shelf[tier - 1] : first
    }
}

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
