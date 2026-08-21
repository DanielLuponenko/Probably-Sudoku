import XCTest
@testable import NumberClubEngine

final class FirstRunTutorialTests: XCTestCase {
    func testFirstPuzzleMapsTheFirstSixTurnsToTeachingBeats() {
        for turn in 1...FirstRunTutorial.lineCount {
            XCTAssertEqual(FirstRunTutorial.lineIndex(book: .probably, level: 1,
                                                      slot: .easy, turn: turn), turn - 1)
        }
    }

    func testTeachingDoesNotLeakIntoOtherBooksPuzzlesOrTurns() {
        XCTAssertNil(FirstRunTutorial.lineIndex(book: .probably, level: 1, slot: .easy, turn: 7))
        XCTAssertNil(FirstRunTutorial.lineIndex(book: .probably, level: 1, slot: .medium, turn: 1))
        XCTAssertNil(FirstRunTutorial.lineIndex(book: .probably, level: 2, slot: .easy, turn: 1))
        XCTAssertNil(FirstRunTutorial.lineIndex(book: .slightlyHarder, level: 1, slot: .easy, turn: 1))
    }
}
