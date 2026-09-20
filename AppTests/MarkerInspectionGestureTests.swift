import XCTest
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

/// These tests deliver UIKit recognizer states to the production coordinator.
/// They verify callback arbitration and preserved game state, not physical
/// touch delivery or the operating system's recognizer competition.
@MainActor
final class MarkerInspectionGestureTests: XCTestCase {
    func testRecognizersUseFourHundredMillisecondHoldAndDoNotDelayOrdinaryTouches() throws {
        let fixture = try Fixture()
        XCTAssertEqual(fixture.coordinator.holdRecognizer.minimumPressDuration, 0.4, accuracy: 0.001)
        XCTAssertEqual(fixture.coordinator.holdRecognizer.allowableMovement, 10, accuracy: 0.001)
        XCTAssertTrue(fixture.coordinator.holdRecognizer.cancelsTouchesInView)
        XCTAssertFalse(fixture.coordinator.holdRecognizer.delaysTouchesBegan)
    }

    func testShortTapStillPlacesTheSelectedCardThroughTheOrdinaryAction() throws {
        let fixture = try Fixture()
        fixture.model.tapHand(0)
        let cardID = try XCTUnwrap(fixture.model.handCards.first?.id)
        let digit = fixture.model.selectedDigit
        fixture.hold(.failed)
        fixture.tap()
        XCTAssertEqual(fixture.taps, 1)
        XCTAssertEqual(fixture.begins, 0)
        XCTAssertEqual(fixture.ends, 0)
        XCTAssertEqual(fixture.model.puzzle?.board[fixture.square], digit)
        XCTAssertFalse(fixture.model.handCards.contains { $0.id == cardID })
        XCTAssertEqual(fixture.model.puzzle?.board.filledBy[fixture.square.index], .player)
    }

    func testRecognizedHoldConsumesReleaseAndRepeatedCallbacksWithoutPlacingSelectedCard() throws {
        let fixture = try Fixture()
        fixture.model.tapHand(0)
        let before = try Snapshot(fixture.model)
        fixture.hold(.began)
        fixture.hold(.changed)
        fixture.hold(.changed)
        XCTAssertEqual(fixture.begins, 1)
        XCTAssertEqual(fixture.ends, 0)
        XCTAssertEqual(try Snapshot(fixture.model), before)
        fixture.hold(.ended)
        fixture.hold(.ended)
        // A late delivery must not turn the inspection into ordinary play.
        fixture.tap()
        fixture.tap()
        XCTAssertEqual(fixture.taps, 0)
        XCTAssertEqual(fixture.ends, 1)
        XCTAssertEqual(try Snapshot(fixture.model), before)
    }

    func testHoldingGivenMarkerPreservesSelectedHandInsteadOfSelectingItsDigit() throws {
        let fixture = try Fixture(onGiven: true)
        fixture.model.tapHand(0)
        let before = try Snapshot(fixture.model)
        fixture.hold(.began)
        fixture.hold(.ended)
        fixture.tap()
        XCTAssertEqual(fixture.begins, 1)
        XCTAssertEqual(fixture.taps, 0)
        XCTAssertEqual(try Snapshot(fixture.model), before)
    }

    func testInspectionPreservesArmedPeekPaidClueAndLitmusThroughReleaseOrCancellation() throws {
        for mode in [InspectionState.armedPeek, .paidClue, .litmus] {
            for ending in [UIGestureRecognizer.State.ended, .cancelled] {
                let fixture = try Fixture()
                switch mode {
                case .armedPeek:
                    fixture.model.qaSetBuff(Buffs.peek)
                    XCTAssertTrue(fixture.model.useBuff(at: 0))
                    XCTAssertTrue(fixture.model.isChoosingClue)
                    XCTAssertNotNil(fixture.model.pendingPeekID)
                case .paidClue:
                    fixture.model.chooseClue()
                    fixture.model.tapHand(0)
                    XCTAssertEqual(fixture.model.puzzle?.clueReveals.count, 1)
                    XCTAssertEqual(fixture.model.selectedHandIndex, 0)
                case .litmus:
                    fixture.model.qaSetBuff(Buffs.litmus)
                    XCTAssertTrue(fixture.model.useBuff(at: 0))
                    let choice = try XCTUnwrap(fixture.model.pendingItemDecision)
                    let digit = try XCTUnwrap(fixture.model.hand.first)
                    XCTAssertTrue(fixture.model.resolveItemDecision(id: choice.id,
                                                                     selected: ["digit.\(digit.rawValue)"]))
                    XCTAssertNil(fixture.model.pendingItemDecision)
                    XCTAssertEqual(fixture.model.puzzle?.buffState.litmusDigit, digit)
                    fixture.model.tapHand(0)
                    XCTAssertTrue(fixture.model.isReadingLitmus)
                }
                let before = try Snapshot(fixture.model)
                fixture.hold(.began)
                fixture.hold(ending)
                fixture.tap()
                XCTAssertEqual(fixture.begins, 1, "\(mode), \(ending)")
                XCTAssertEqual(fixture.ends, 1, "\(mode), \(ending)")
                XCTAssertEqual(fixture.taps, 0, "\(mode), \(ending)")
                XCTAssertEqual(try Snapshot(fixture.model), before, "\(mode), \(ending)")
            }
        }
    }

    func testFogRejectsInspectionWithoutPublishingBeginOrEndFeedback() throws {
        let fixture = try Fixture(fog: true)
        fixture.model.tapHand(0)
        let before = try Snapshot(fixture.model)
        XCTAssertTrue(fixture.model.visibleMarkers.isEmpty)
        XCTAssertFalse(fixture.coordinator.gestureRecognizerShouldBegin(fixture.coordinator.holdRecognizer))
        fixture.hold(.began)
        fixture.hold(.changed)
        fixture.hold(.ended)
        XCTAssertEqual(fixture.begins, 0, "Begin feedback must not reveal a hidden marker location.")
        XCTAssertEqual(fixture.ends, 0)
        XCTAssertEqual(fixture.taps, 0)
        XCTAssertEqual(try Snapshot(fixture.model), before)
    }

    func testEligibilityIsRecheckedAtRecognitionAndCancellationIsIdempotent() throws {
        let fixture = try Fixture()
        fixture.model.tapHand(0)
        XCTAssertTrue(fixture.coordinator.gestureRecognizerShouldBegin(fixture.coordinator.holdRecognizer))
        fixture.permitsInspection = false
        fixture.hold(.began)
        XCTAssertEqual(fixture.begins, 0, "A covered/changed cell cannot open from an older eligibility decision.")

        fixture.permitsInspection = true
        fixture.coordinator.beginTouch()
        fixture.hold(.began)
        XCTAssertEqual(fixture.begins, 1)
        let before = try Snapshot(fixture.model)
        fixture.coordinator.invalidate()
        fixture.coordinator.invalidate()
        fixture.hold(.cancelled)
        fixture.hold(.ended)
        fixture.tap()
        XCTAssertEqual(fixture.ends, 1)
        XCTAssertEqual(fixture.taps, 0)
        XCTAssertEqual(try Snapshot(fixture.model), before)
    }

    func testFreshTouchAfterHoldCanTapButAnotherFingerCannotClearTheActiveHoldLatch() throws {
        let fixture = try Fixture()
        fixture.model.tapHand(0)
        let before = try Snapshot(fixture.model)
        fixture.hold(.began)
        fixture.coordinator.beginTouch()
        fixture.tap()
        XCTAssertEqual(fixture.taps, 0, "A new finger during inspection cannot turn release into play.")
        XCTAssertEqual(try Snapshot(fixture.model), before)
        fixture.hold(.ended)
        fixture.coordinator.beginTouch()
        fixture.hold(.failed)
        fixture.tap()
        XCTAssertEqual(fixture.begins, 1)
        XCTAssertEqual(fixture.ends, 1)
        XCTAssertEqual(fixture.taps, 1, "A consumed old sequence cannot poison the next ordinary tap.")
        XCTAssertEqual(fixture.model.puzzle?.board.filledBy[fixture.square.index], .player)
    }

    func testLeavingEligibilityDuringHoldClosesOnceAndNeverFallsBackToTap() throws {
        let fixture = try Fixture()
        fixture.model.tapHand(0)
        let before = try Snapshot(fixture.model)
        fixture.hold(.began)
        fixture.permitsInspection = false
        fixture.hold(.changed)
        fixture.hold(.changed)
        fixture.hold(.ended)
        fixture.tap()
        XCTAssertEqual(fixture.begins, 1)
        XCTAssertEqual(fixture.ends, 1)
        XCTAssertEqual(fixture.taps, 0)
        XCTAssertEqual(try Snapshot(fixture.model), before)
    }

    func testMovingOutsideTheHeldCellDismissesAndConsumesTheRelease() throws {
        let fixture = try Fixture()
        fixture.model.tapHand(0)
        let before = try Snapshot(fixture.model)
        fixture.hold(.began)
        fixture.moveHold(to: CGPoint(x: 40, y: 22))
        XCTAssertEqual(fixture.ends, 0)
        fixture.moveHold(to: CGPoint(x: 55, y: 22))
        fixture.hold(.ended)
        fixture.tap()
        XCTAssertEqual(fixture.begins, 1)
        XCTAssertEqual(fixture.ends, 1)
        XCTAssertEqual(fixture.taps, 0)
        XCTAssertEqual(try Snapshot(fixture.model), before)
    }

    private enum InspectionState { case armedPeek, paidClue, litmus }

    private struct Snapshot: Equatable {
        let encodedGame: Data
        let handIDs: [UUID]
        let selectedHandIndex: Int?
        let selectedSquare: Square?
        let highlightedDigit: Digit?
        let choosingClue: Bool
        let pendingPeek: UUID?
        let message: String?

        @MainActor init(_ model: GameModel) throws {
            encodedGame = try model.game.encoded()
            handIDs = model.handCards.map(\.id)
            selectedHandIndex = model.selectedHandIndex
            selectedSquare = model.selectedSquare
            highlightedDigit = model.highlightedDigit
            choosingClue = model.isChoosingClue
            pendingPeek = model.pendingPeekID
            message = model.message
        }
    }

    private final class Tap: UITapGestureRecognizer {
        var reportedState = UIGestureRecognizer.State.ended
        override var state: UIGestureRecognizer.State {
            get { reportedState }
            set { reportedState = newValue }
        }
    }

    private final class Hold: UILongPressGestureRecognizer {
        var reportedState = UIGestureRecognizer.State.possible
        var reportedLocation = CGPoint(x: 22, y: 22)
        override func location(in view: UIView?) -> CGPoint { reportedLocation }
        override var state: UIGestureRecognizer.State {
            get { reportedState }
            set { reportedState = newValue }
        }
    }

    @MainActor private final class Fixture {
        let model: GameModel
        let square: Square
        var permitsInspection = true
        var taps = 0
        var begins = 0
        var ends = 0
        private let tapEvent = Tap()
        private let holdEvent = Hold()
        private let touchView = UIView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        lazy var coordinator = MarkerCellTouchSurface.Coordinator(
            canInspect: { [unowned self] in
                permitsInspection && model.visibleMarkers[square] != nil
            },
            onTap: { [unowned self] in taps += 1; model.tapSquare(square) },
            onBegin: { [unowned self] in begins += 1 },
            onEnd: { [unowned self] in ends += 1 })

        init(onGiven: Bool = false, fog: Bool = false) throws {
            var game = Game(seed: "marker-hold-coordinator", book: .noPressure)
            try game.startPuzzle()
            let puzzle = try XCTUnwrap(game.puzzle)
            square = try XCTUnwrap(Square.all.first {
                if onGiven { return puzzle.board.isGiven[$0.index] }
                return puzzle.board.isBlank($0) && puzzle.board.correctDigit(at: $0) == puzzle.hand[0]
            })
            game.qaSetMarker("mk_onyx", at: square)
            if fog { game.qaSetBoss(.fog) }
            model = GameModel(frozen: game, page: .puzzle)
            touchView.addGestureRecognizer(holdEvent)
        }

        func moveHold(to point: CGPoint) {
            holdEvent.reportedLocation = point
            hold(.changed)
        }

        func tap() {
            let selector = NSSelectorFromString("tap:")
            XCTAssertTrue(coordinator.responds(to: selector))
            _ = coordinator.perform(selector, with: tapEvent)
        }

        func hold(_ state: UIGestureRecognizer.State) {
            holdEvent.reportedState = state
            let selector = NSSelectorFromString("hold:")
            XCTAssertTrue(coordinator.responds(to: selector))
            _ = coordinator.perform(selector, with: holdEvent)
        }
    }
}
