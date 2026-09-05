import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class PuzzlePageLayoutTests: XCTestCase {
    func testBoardSideIsStableAcrossLevelsAndBossStagesOnEachPhone() async throws {
        let representative: [(String, Game)] = [
            ("level1-easy", try game()),
            ("level4-medium", try game(level: 4, slot: .medium)),
            ("level9-easy", try game(level: 9)),
            ("deadline", try game(slot: .boss, boss: .deadline)),
            ("gray-the-garry", try game(slot: .boss, boss: .grayTheGarry)),
            ("long-name-accountant", try game(slot: .boss, boss: .accountant)),
            ("timed-tik-tak", try game(slot: .boss, boss: .tikTak))
        ]
        var complete = [(String, Game)]()
        for level in 1...9 {
            for slot in PuzzleSlot.allCases {
                complete.append(("level\(level)-slot\(slot.rawValue)",
                                 try game(level: level, slot: slot)))
            }
        }
        for boss in BossModifier.allCases {
            complete.append(("boss-\(boss.rawValue)",
                             try game(level: boss.isFinalBoss ? 9 : 1, slot: .boss, boss: boss)))
        }
        for phone in Phone.all {
            // Full run/roster coverage on the two current target phones;
            // representative long/short/timed headers on compact phones.
            let fixtures = phone.size.width >= 402 ? complete : representative
            let baseline = try await measure(fixtures[0].1, phone: phone, name: fixtures[0].0,
                                             verifyFooter: true)
            for (name, game) in fixtures.dropFirst() {
                let keepImage = fixtures.count < 20 || name == "level9-slot2"
                    || name == "boss-accountant" || name == "boss-tikTak"
                let measured = try await measure(game, phone: phone, name: name, attachImage: keepImage,
                                                 verifyFooter: name == "boss-tikTak" || name == "timed-tik-tak")
                assertSameBoard(measured, baseline, "\(phone.name) \(name): stage content")
            }
        }
    }

    func testHandCapacityEmptySlotsAndCluePromptDoNotResizeTheBoard() async throws {
        let base = try game()
        for phone in Phone.all {
            let baseline = try await measure(base, phone: phone, name: "hand7")
            for (name, capacity, count, clues, choosing) in [
                ("hand4", 4, 4, 0, false),
                ("hand9", 9, 9, 0, false),
                ("hand9-last-card", 9, 1, 0, false),
                ("clue-ready", 7, 7, 2, false),
                ("clue-pick-number", 7, 7, 2, true)
            ] {
                var run = base.run
                run.puzzle?.handSize = capacity
                run.puzzle?.hand = Array(repeating: .five, count: count)
                run.puzzle?.cluesRemaining = clues
                let measured = try await measure(Game(run: run), phone: phone,
                                                 choosingClue: choosing, name: name)
                assertSameBoard(measured, baseline, "\(phone.name) \(name): Hand/action text")
                XCTAssertEqual(measured.hand.height, baseline.hand.height, accuracy: 1)
            }
        }
    }

    func testAccessibilitySizeKeepsTheSameBoardSideAcrossStages() async throws {
        let phone = Phone.all[1]
        let baseline = try await measure(game(), phone: phone, type: .accessibility5,
                                         name: "accessibility5-regular")
        for boss in [BossModifier.deadline, .accountant, .tikTak] {
            let measured = try await measure(game(slot: .boss, boss: boss), phone: phone,
                                             type: .accessibility5, name: "accessibility5-\(boss.rawValue)")
            assertSameBoard(measured, baseline, "Accessibility text, \(boss.rawValue)")
        }
    }

    func testLitmusQueuedScoreAndSilentMarginKeepTheSameBoardSide() async throws {
        let base = try game()
        XCTAssertNotNil(GameModel(frozen: base, page: .puzzle).marginNote)
        var litmus = base.run
        litmus.puzzle?.armedFlags.insert(.litmus)
        var queued = base.run
        queued.puzzle?.score = 987_654
        queued.puzzle?.pendingBase = 123_456
        queued.puzzle?.pendingMult = 123.5
        var silent = base.run
        let silentTurn = try XCTUnwrap((2...10).first { turn in
            MarginNote.roll(seed: base.run.seed, level: 1, slot: 0, turn: turn,
                            from: .first) == nil
        })
        silent.puzzle?.turnNumber = silentTurn
        XCTAssertNil(GameModel(frozen: Game(run: silent), page: .puzzle).marginNote)
        for phone in Phone.all {
            let baseline = try await measure(base, phone: phone, name: "note-present")
            for (name, run) in [("litmus", litmus), ("large-queued-score", queued),
                                ("note-absent", silent)] {
                let measured = try await measure(Game(run: run), phone: phone, name: name)
                assertSameBoard(measured, baseline, "\(phone.name) \(name): transient printed content")
            }
        }
    }

    func testHighScoresQueuedMultipliersAndCoinReceiptDoNotMoveTheBoard() async throws {
        let baselineGame = try game()
        let photographed = try photographedScoreWithCopperPlacement()
        var lateBook = try game(level: 9, slot: .boss, boss: .heavyLifter).run
        XCTAssertEqual(lateBook.puzzle?.target, 2_048_000)
        lateBook.puzzle?.score = 9_999_999
        lateBook.puzzle?.pendingBase = 123_456
        lateBook.puzzle?.pendingMult = 123.5
        lateBook.coins = 123_456
        var extreme = lateBook
        // Numeric stress within Int/Double bounds, not nonexistent Levels.
        extreme.puzzle?.score = 123_456_789
        extreme.puzzle?.pendingBase = 123_456_789
        extreme.puzzle?.pendingMult = 999.75
        extreme.coins = 999_999

        for phone in Phone.all {
            for type in [DynamicTypeSize.large, .accessibility5] {
                let suffix = type == .large ? "large" : "accessibility5"
                let baseline = try await measure(baselineGame, phone: phone, type: type,
                                                 name: "numeric-baseline-\(suffix)", attachImage: false)
                let photo = try await measure(photographed.game, phone: phone, type: type,
                                              placingCopperAt: photographed.square,
                                              name: "122541-target128000-495x39_75-plus6coins-\(suffix)",
                                              verifyFooter: true)
                assertSameBoard(photo, baseline, "\(phone.name) \(suffix): photographed score and coin receipt")
                for (name, run) in [("level9-heavy-lifter-seven-digits", lateBook),
                                    ("level9-nine-digits", extreme)] {
                    let measured = try await measure(Game(run: run), phone: phone, type: type,
                                                     name: "\(name)-\(suffix)")
                    assertSameBoard(measured, baseline, "\(phone.name) \(suffix): \(name)")
                    XCTAssertEqual(measured.hand.height, baseline.hand.height, accuracy: 1)
                }
            }
        }
    }

    /// Build a real two-unit Copper placement so ScoreMeter receives its +6
    /// through GameModel.lastOutcome, rather than a test-only display override.
    /// Every staged number comes from the Pool; the fixture remains conserved.
    private func photographedScoreWithCopperPlacement() throws -> (game: Game, square: Square) {
        var run = try game(level: 8).run
        var puzzle = try XCTUnwrap(run.puzzle)
        let square = try XCTUnwrap(puzzle.board.blanks.first { candidate in
            // Leave a separate blank in the Box: this move must complete just
            // its row and column, making Copper pay exactly six coins.
            Geometry.cells(of: .box, through: candidate).contains {
                $0.row != candidate.row && $0.col != candidate.col && puzzle.board.isBlank($0)
            }
        })
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        let crossing = Set(Geometry.cells(of: .row, through: square)
                           + Geometry.cells(of: .col, through: square))
        for cell in crossing where cell != square && puzzle.board.isBlank(cell) {
            let digit = puzzle.board.correctDigit(at: cell)
            XCTAssertTrue(puzzle.pool.take(digit))
            puzzle.board.fill(cell, with: digit, by: .player)
        }
        let digit = puzzle.board.correctDigit(at: square)
        XCTAssertTrue(puzzle.pool.take(digit))
        puzzle.hand = [digit]
        for _ in 1..<puzzle.handSize {
            let extra = try XCTUnwrap(Digit.all.first { puzzle.pool[$0] > 0 })
            XCTAssertTrue(puzzle.pool.take(extra))
            puzzle.hand.append(extra)
        }
        puzzle.score = 122_541
        XCTAssertEqual(puzzle.target, 128_000)
        puzzle.pendingBase = 495 - (10 * digit.rawValue + 2 * 45)
        puzzle.pendingMult = 39.75
        run.markers = [OwnedMarker(defID: "mk_copper", boughtAtLevel: run.level,
                                   pricePaid: 6, squares: [square])]
        run.coins = 99_994
        run.puzzle = puzzle
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand))
        return (Game(run: run), square)
    }

    private struct Phone {
        var name: String
        var size: CGSize
        var top: CGFloat
        var bottom: CGFloat
        var minimumBoardSide: CGFloat

        static let all = [
            Phone(name: "SE2-3", size: CGSize(width: 375, height: 667), top: 20, bottom: 0, minimumBoardSide: 240),
            Phone(name: "375", size: CGSize(width: 375, height: 812), top: 44, bottom: 34, minimumBoardSide: 280),
            Phone(name: "402", size: CGSize(width: 402, height: 874), top: 62, bottom: 34, minimumBoardSide: 300),
            Phone(name: "440", size: CGSize(width: 440, height: 956), top: 62, bottom: 34, minimumBoardSide: 350)
        ]
    }

    private struct Measurement {
        let grid: CGRect
        let hand: CGRect
        // GridView's GeometryReader draws an actual square using this exact
        // minimum. Its outer maxWidth frame alone hides vertical shrinkage.
        var boardSide: CGFloat { min(grid.width, grid.height) }
    }

    private func assertSameBoard(_ actual: Measurement, _ expected: Measurement,
                                 _ context: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.boardSide, expected.boardSide, accuracy: 1,
                       "\(context) resized the board: \(expected.grid) → \(actual.grid)", file: file, line: line)
        XCTAssertEqual(actual.grid.minY, expected.grid.minY, accuracy: 1,
                       "\(context) moved the board vertically", file: file, line: line)
        // GridView centers its square within the outer maxWidth frame. The
        // outer midpoint therefore is the visible square's horizontal center.
        XCTAssertEqual(actual.grid.midX, expected.grid.midX, accuracy: 1,
                       "\(context) moved the board horizontally", file: file, line: line)
    }

    private func game(level: Int = 1, slot: PuzzleSlot = .easy,
                      boss: BossModifier? = nil) throws -> Game {
        var run = RunState(seed: "puzzle-page-layout")
        run.level = level
        run.slot = slot
        if let boss { run.pendingBoss = boss }
        var game = Game(run: run)
        try game.startPuzzle()
        if let boss {
            XCTAssertEqual(game.puzzle?.boss, boss,
                           "The layout fixture must render the requested Boss, not a replacement from another pool")
        }
        return game
    }

    private func measure(_ game: Game, phone: Phone, type: DynamicTypeSize = .large,
                         choosingClue: Bool = false, placingCopperAt: Square? = nil, name: String,
                         attachImage: Bool = true, verifyFooter: Bool = false) async throws -> Measurement {
        let model = GameModel(frozen: game, page: .puzzle)
        if choosingClue { model.chooseClue() } // Selection only; never spends or saves.
        if let placingCopperAt {
            model.place(handIndex: 0, at: placingCopperAt) // Frozen: no save/profile tracking.
            XCTAssertEqual(model.lastOutcome?.correct, true)
            XCTAssertEqual(model.lastOutcome?.coinsEarned, 6)
            XCTAssertEqual(model.puzzle?.score, 122_541)
            XCTAssertEqual(model.puzzle?.pendingBase, 495)
            XCTAssertEqual(model.puzzle?.pendingMultiplier, 39.75)
            XCTAssertEqual(model.coins, 100_000)
            XCTAssertEqual(model.puzzle?.phase, .playing)
        }
        let puzzle = try XCTUnwrap(model.puzzle)
        let flipper = PageFlipper()
        let ready = expectation(description: "Grid and Hand frames: \(phone.name)-\(name)")
        let pageReady = expectation(description: "Allocated page frame: \(phone.name)-\(name)")
        var frames: [String: CGRect] = [:]
        var didReport = false
        var pageFrame = CGRect.zero
        var didReportPage = false
        // The same BookmarkRow, insets, tuck, BookView and PageSurface used by
        // GameView. Explicit safe areas keep every scenario on one viewport.
        let content = VStack(spacing: 0) {
            BookmarkRow(model: model, onTapBuff: { _ in })
                .padding(.horizontal, 26).padding(.top, 4)
            BookView(flipper: flipper) {
                PuzzlePageView(model: model, puzzle: puzzle, isClockRunning: false)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                        pageFrame = frame
                        if !didReportPage, frame.width > 0, frame.height > 0 {
                            didReportPage = true
                            pageReady.fulfill()
                        }
                    }
            }
            .padding(.leading, 8).padding(.trailing, 10)
            .padding(.top, -(BookmarkRow.tuck - 4))
        }
        .padding(.bottom, 8)
        .padding(.top, phone.top).padding(.bottom, phone.bottom)
        .frame(width: phone.size.width, height: phone.size.height)
        .environment(\.cosmeticTheme, .standard)
        .environment(\.levelPalette, .forDisplay(slot: puzzle.slot))
        .environment(\.dynamicTypeSize, type)
        .environment(\.colorScheme, .light)
        .environment(\.locale, Locale(identifier: "en_US"))
        .transaction { $0.disablesAnimations = true }
        .onPreferenceChange(NumberReturnMotionFrames.self) { latest in
            frames = latest
            if !didReport, latest[NumberReturnMotionAnchor.grid] != nil,
               latest[NumberReturnMotionAnchor.hand] != nil {
                didReport = true
                ready.fulfill()
            }
        }
        let controller = UIHostingController(rootView: content)
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        window.rootViewController = controller
        defer {
            flipper.cancel()
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [ready, pageReady], timeout: 5)
        window.layoutIfNeeded()
        let grid = try XCTUnwrap(frames[NumberReturnMotionAnchor.grid])
        let hand = try XCTUnwrap(frames[NumberReturnMotionAnchor.hand])
        let measurement = Measurement(grid: grid, hand: hand)
        XCTAssertGreaterThanOrEqual(measurement.boardSide, phone.minimumBoardSide,
                                   "\(phone.name) \(name): a stable but undersized board is not acceptable")
        let pageBounds = CGRect(origin: .zero, size: pageFrame.size)
        for (part, frame) in [("grid", grid), ("hand", hand)] {
            XCTAssertGreaterThanOrEqual(frame.minX, -1, "\(name): \(part) left the page on the left")
            XCTAssertGreaterThanOrEqual(frame.minY, -1, "\(name): \(part) left the page at the top")
            XCTAssertLessThanOrEqual(frame.maxX, pageBounds.maxX + 1, "\(name): \(part) overflowed the page width")
            XCTAssertLessThanOrEqual(frame.maxY, pageBounds.maxY + 1, "\(name): \(part) overflowed the page height")
        }
        XCTAssertGreaterThanOrEqual(pageFrame.minY, phone.top - 1)
        XCTAssertLessThanOrEqual(pageFrame.maxY, phone.size.height - phone.bottom + 1,
                                 "The page cannot expand beyond the phone to make the board fit")
        XCTAssertGreaterThanOrEqual(hand.minY, grid.maxY, "Hand must not overlap the board")
        if attachImage || verifyFooter {
            let image = UIGraphicsImageRenderer(size: phone.size).image { _ in
                window.drawHierarchy(in: CGRect(origin: .zero, size: phone.size), afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "puzzle-layout-\(phone.name)-\(name)-side-\(Int(measurement.boardSide))"
            attachment.lifetime = .keepAlways
            add(attachment)
            if name.hasPrefix("122541-target"), phone.name == "440", type == .large {
                try image.pngData()?.write(to: URL(fileURLWithPath: "/tmp/numberclub-high-score-full-page.png"))
            }
            if verifyFooter {
                try assertFooterVisible(in: image, puzzle: puzzle, pageFrame: pageFrame,
                                        gridFrame: grid, context: "\(phone.name) \(name)")
            }
        }
        print("PUZZLE_LAYOUT \(phone.name) \(name) grid=\(grid) visibleSide=\(measurement.boardSide) hand=\(hand)")
        return measurement
    }

    private func assertFooterVisible(in image: UIImage, puzzle: PuzzleState, pageFrame: CGRect,
                                     gridFrame: CGRect, context: String) throws {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let lines = (request.results ?? []).compactMap { result -> (text: String, frame: CGRect)? in
            guard let text = result.topCandidates(1).first?.string else { return nil }
            let box = result.boundingBox
            return (text.lowercased().filter { $0.isLetter || $0.isNumber },
                    CGRect(x: box.minX * image.size.width, y: (1 - box.maxY) * image.size.height,
                           width: box.width * image.size.width, height: box.height * image.size.height))
        }
        let expectedTurn = "turn\(min(puzzle.turnNumber, puzzle.turnsMax))\(puzzle.turnsMax)"
        for label in ["endturn", expectedTurn] {
            let line = try XCTUnwrap(lines.first { $0.text.contains(label) },
                                    "\(context): footer \(label) missing or clipped: \(lines.map(\.text))")
            XCTAssertGreaterThanOrEqual(line.frame.minY, pageFrame.minY + gridFrame.maxY - 1,
                                       "\(context): footer overlaps the board")
            XCTAssertLessThanOrEqual(line.frame.maxY, pageFrame.maxY + 1,
                                     "\(context): footer escaped the printed page")
        }
    }
}
