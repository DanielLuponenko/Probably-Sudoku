import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BossBoardVisualTests: XCTestCase {
    func testAllNineteenBossesHaveDistinctRenderableBoardTreatments() throws {
        var symbols = Set<String>()
        var renderedBoards = Set<Data>()
        for boss in BossModifier.allCases {
            let design = BossBoardDesign(boss: boss)
            XCTAssertNotNil(UIImage(systemName: design.symbol), "Missing Boss symbol: \(boss.name)")
            symbols.insert(design.symbol)
            let game = try makeGame(boss: boss)
            let image = try render(game)
            renderedBoards.insert(try XCTUnwrap(image.pngData()))
            XCTAssertEqual(image.size, CGSize(width: 360, height: 360))
            attach(image, name: "boss-board-\(boss.rawValue)")
        }
        XCTAssertEqual(symbols.count, BossModifier.allCases.count)
        XCTAssertEqual(renderedBoards.count, BossModifier.allCases.count,
                       "Standing modifiers must not silently reuse an identical board treatment")
    }

    func testFogHidesMarkerDecorationsWithoutRevealingTheirLocations() throws {
        let original = try makeGame(boss: .fog)
        let blanks = try XCTUnwrap(original.puzzle?.board.blanks)
        let first = try XCTUnwrap(blanks.first)
        let last = try XCTUnwrap(blanks.last)
        XCTAssertNotEqual(first, last)
        let withoutMarkers = try render(original)

        for square in [first, last] {
            var run = original.run
            run.markers = [OwnedMarker(defID: "mk_copper", boughtAtLevel: 1,
                                       pricePaid: 0, squares: [square])]
            let game = Game(run: run)
            let model = GameModel(frozen: game, page: .puzzle)
            XCTAssertTrue(model.markersAreHidden)
            XCTAssertTrue(model.visibleMarkers.isEmpty)
            XCTAssertEqual(try render(game).pngData(), withoutMarkers.pngData(),
                           "Fog's pattern must not trace hidden Marker positions")
        }
        attach(withoutMarkers, name: "fog-marker-locations-remain-hidden")
    }

    func testFogIsVisibleOverGivenCellBackgroundsAndLeavesNumberContrast() throws {
        let fog = try makeGame(boss: .fog)
        var clearRun = fog.run
        clearRun.puzzle?.boss = nil
        let clearImage = try render(Game(run: clearRun))
        let fogImage = try render(fog)
        let clear = try pixels(clearImage)
        let mist = try pixels(fogImage)
        let board = try XCTUnwrap(fog.puzzle?.board)
        let givens = Square.all.filter { board.isGiven[$0.index] }
        let cell = mist.width / 9
        var visiblyChanged = 0
        for square in givens {
            // Sample paper, away from the central glyph, selection or rule.
            let x = square.col * cell + cell / 5
            let y = square.row * cell + cell / 5
            let delta = (0..<3).reduce(0) {
                $0 + abs(Int(mist.channel(x: x, y: y, channel: $1))
                         - Int(clear.channel(x: x, y: y, channel: $1)))
            }
            if delta >= 8 { visiblyChanged += 1 }
        }
        XCTAssertGreaterThan(visiblyChanged, givens.count / 3,
                             "Fog must remain visible above opaque Given-cell backgrounds")

        // Dark printed pixels stay dark; the mist must not wash the numbers
        // into a low-contrast gray even in its lightest band.
        var darkCount = 0
        var retainedCount = 0
        for offset in stride(from: 0, to: clear.bytes.count, by: 4) {
            let clearRed = Int(clear.bytes[offset])
            let clearGreen = Int(clear.bytes[offset + 1])
            let clearBlue = Int(clear.bytes[offset + 2])
            guard clearRed + clearGreen + clearBlue < 180 else { continue }
            darkCount += 1
            let mistRed = Int(mist.bytes[offset])
            let mistGreen = Int(mist.bytes[offset + 1])
            let mistBlue = Int(mist.bytes[offset + 2])
            if mistRed + mistGreen + mistBlue < 330 { retainedCount += 1 }
        }
        XCTAssertGreaterThan(darkCount, 0)
        XCTAssertGreaterThan(Double(retainedCount) / Double(max(1, darkCount)), 0.90)
        attach(fogImage, name: "fog-readable-givens-and-digits")
    }

    func testReduceMotionKeepsEveryBossOverlayTreatmentVisible() throws {
        for boss in BossModifier.allCases {
            let puzzle = try XCTUnwrap(makeGame(boss: boss).puzzle)
            XCTAssertEqual(try renderOverlay(puzzle, reduceMotion: false).pngData(),
                           try renderOverlay(puzzle, reduceMotion: true).pngData(),
                           "Reduce Motion removes movement, not \(boss.name)'s rule cues")
        }
    }

    func testCensorUnderlinesOnlyNumbersAlreadyVisibleOnTheBoard() throws {
        let game = try makeGame(boss: .censor)
        let puzzle = try XCTUnwrap(game.puzzle)
        let censored = try XCTUnwrap(puzzle.censoredDigit)
        let feedback = BossBoardFeedback(puzzle: puzzle)
        XCTAssertEqual(feedback.censoredSquares,
                       Set(Square.all.filter { puzzle.board[$0] == censored }))
        XCTAssertTrue(feedback.censoredSquares.isDisjoint(with: Set(puzzle.board.blanks)))
        XCTAssertFalse(feedback.censoredSquares.isEmpty)
    }

    func testGarryAndOverPusherFeedbackUsesOnlyTheirActualRuleState() throws {
        for boss in [BossModifier.grayTheGarry, .garryTheGray, .overPusher] {
            let puzzle = try XCTUnwrap(makeGame(boss: boss).puzzle)
            let feedback = BossBoardFeedback(puzzle: puzzle)
            if boss == .overPusher {
                XCTAssertEqual(feedback.fouled, Set(puzzle.bossTurn?.fouled.keys.map { $0 } ?? []))
                XCTAssertFalse(feedback.fouled.isEmpty)
                XCTAssertTrue(feedback.greyed.isEmpty)
            } else {
                XCTAssertEqual(feedback.greyed, puzzle.bossTurn?.greyed)
                XCTAssertFalse(feedback.greyed.isEmpty)
                XCTAssertTrue(feedback.fouled.isEmpty)
            }
        }
        var unrelated = try XCTUnwrap(makeGame(boss: .grayTheGarry).puzzle)
        unrelated.boss = .editor
        let feedback = BossBoardFeedback(puzzle: unrelated)
        XCTAssertTrue(feedback.greyed.isEmpty, "Stale QA state must not invent an Editor board lock")
        XCTAssertTrue(feedback.fouled.isEmpty)
    }

    func testRestrictionOutlinesFollowMovedRowsAndBoxesNotTheCenter() {
        let rect = CGRect(x: 0, y: 0, width: 360, height: 360)
        let row = BossRestrictionOutline(squares: Set(Geometry.rows[7])).path(in: rect)
        let box = BossRestrictionOutline(squares: Set(Geometry.boxes[8])).path(in: rect)
        XCTAssertEqual(row.boundingRect, CGRect(x: 0, y: 280, width: 360, height: 40))
        XCTAssertEqual(box.boundingRect, CGRect(x: 240, y: 240, width: 120, height: 120))
        XCTAssertTrue(BossRestrictionOutline(squares: []).path(in: rect).isEmpty)
    }

    func testTikTakFeedbackChangesOnlyAtUrgencyThreshold() throws {
        let puzzle = try XCTUnwrap(makeGame(boss: .tikTak).puzzle)
        let normal = BossBoardFeedback(puzzle: puzzle, secondsLeft: 180)
        XCTAssertEqual(normal, BossBoardFeedback(puzzle: puzzle, secondsLeft: 31))
        XCTAssertFalse(normal.clockIsUrgent)
        XCTAssertTrue(BossBoardFeedback(puzzle: puzzle, secondsLeft: 30).clockIsUrgent)
        XCTAssertTrue(BossBoardFeedback(puzzle: puzzle, secondsLeft: 1).clockIsUrgent)
        XCTAssertFalse(BossBoardFeedback(puzzle: puzzle).clockIsUrgent)
        let other = try XCTUnwrap(makeGame(boss: .deadline).puzzle)
        XCTAssertFalse(BossBoardFeedback(puzzle: other, secondsLeft: 1).clockIsUrgent)
    }

    func testAllBossNamesFitTwoLinesInNarrowPhoneStamps() throws {
        let font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        for width: CGFloat in [280, 300, 340] {
            // BossStamp gives its two columns equal flexible width. Keep the
            // padding, symbol and gap out of the actual title text budget.
            let titleWidth = (width - 7) / 2 - 14 - 14 - 4
            for boss in BossModifier.allCases {
                let title = NSAttributedString(string: boss.name.uppercased(),
                                               attributes: [.font: font, .kern: 0.6])
                let bounds = title.boundingRect(with: CGSize(width: titleWidth, height: 200),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                context: nil)
                XCTAssertLessThanOrEqual(bounds.height, font.lineHeight * 2 + 1,
                                         "\(boss.name) clips in a \(width)-point stamp")
            }
        }
        for boss in BossModifier.allCases {
            let renderer = ImageRenderer(content:
                BossStamp(boss: boss, censored: boss == .censor ? .seven : nil)
                    .frame(width: 280)
                    .padding(8)
                    .background(Paper.page)
            )
            renderer.scale = 2
            attach(try XCTUnwrap(renderer.uiImage), name: "boss-stamp-\(boss.rawValue)")
        }
    }

    private func makeGame(boss: BossModifier) throws -> Game {
        var run = RunState(seed: "boss-visual-regression")
        run.slot = .boss
        run.pendingBoss = boss
        var game = Game(run: run)
        try game.startPuzzle()
        return game
    }

    private func render(_ game: Game) throws -> UIImage {
        let puzzle = try XCTUnwrap(game.puzzle)
        let model = GameModel(frozen: game, page: .puzzle)
        let renderer = ImageRenderer(content:
            GridView(model: model, board: puzzle.board)
                .frame(width: 360, height: 360)
                .environment(\.cosmeticTheme, .standard)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 2
        return try XCTUnwrap(renderer.uiImage)
    }

    private func renderOverlay(_ puzzle: PuzzleState, reduceMotion: Bool) throws -> UIImage {
        let renderer = ImageRenderer(content:
            BossBoardOverlay(puzzle: puzzle, reduceMotionOverride: reduceMotion)
                .frame(width: 360, height: 360)
                .background(Paper.page)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 2
        return try XCTUnwrap(renderer.uiImage)
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private struct Pixels {
        let width: Int
        let bytes: [UInt8]

        func channel(x: Int, y: Int, channel: Int) -> UInt8 {
            bytes[(y * width + x) * 4 + channel]
        }
    }

    private func pixels(_ image: UIImage) throws -> Pixels {
        let cgImage = try XCTUnwrap(image.cgImage)
        var bytes = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let rendered = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress,
                                          width: cgImage.width, height: cgImage.height,
                                          bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                            | CGBitmapInfo.byteOrder32Big.rawValue) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            return true
        }
        XCTAssertTrue(rendered)
        return Pixels(width: cgImage.width, bytes: bytes)
    }
}
