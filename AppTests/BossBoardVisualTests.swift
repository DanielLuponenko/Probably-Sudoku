import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BossBoardVisualTests: XCTestCase {
    func testTwentyFourPointBossSealsHaveDistinctReadableGlyphsAndMovingEdges() throws {
        var images = Set<Data>()
        for boss in BossModifier.allCases {
            func render(_ phase: Double) throws -> UIImage {
                let renderer = ImageRenderer(content:
                    BossSignatureBadge(boss: boss, side: 24, phaseOverride: phase)
                        .background(Paper.page)
                )
                renderer.scale = 3
                return try XCTUnwrap(renderer.uiImage)
            }
            let resting = try render(0)
            let moving = try render(0.25)
            XCTAssertEqual(resting.size, CGSize(width: 24, height: 24))
            images.insert(try XCTUnwrap(resting.pngData()))
            XCTAssertNotEqual(resting.pngData(), moving.pngData(), "\(boss.name)'s seal has no visible edge motion")
            let a = try pixels(resting)
            let b = try pixels(moving)
            var inkCount = 0
            var changedCenter = 0
            for y in (a.width / 4)..<(a.width * 3 / 4) {
                for x in (a.width / 4)..<(a.width * 3 / 4) {
                    if Int(a.channel(x: x, y: y, channel: 0))
                        + Int(a.channel(x: x, y: y, channel: 1))
                        + Int(a.channel(x: x, y: y, channel: 2)) < 300 { inkCount += 1 }
                    for channel in 0..<3 {
                        if a.channel(x: x, y: y, channel: channel) != b.channel(x: x, y: y, channel: channel) {
                            changedCenter += 1
                        }
                    }
                }
            }
            XCTAssertGreaterThan(inkCount, 20, "The 24pt seal must have a real full-ink glyph")
            XCTAssertEqual(changedCenter, 0, "The identifying glyph must not wobble or disappear")
            attach(resting, name: "boss-seal-24pt-\(boss.rawValue)")
        }
        XCTAssertEqual(images.count, BossModifier.allCases.count)
    }

    func testCompactBossHeaderPreservesTheActualRuleMeaning() {
        XCTAssertEqual(BossBoardDesign(boss: .censor).headerRule(censored: .seven), "Digit 7 scores 0")
        XCTAssertEqual(BossBoardDesign(boss: .tikTak).headerRule(censored: nil), "4-minute limit")
        XCTAssertEqual(BossBoardDesign(boss: .handyDandy).headerRule(censored: nil),
                       "Up to 2 Hand cards barred each turn")
        for boss in BossModifier.allCases {
            XCTAssertFalse(BossBoardDesign(boss: boss).headerRule(censored: nil).isEmpty)
        }
    }

    func testBossMotionClockResumesWithoutChargingTimeUnderSettingsOrInBackground() {
        var clock = BossMotionClock()
        clock.setRunning(true, at: 100)
        XCTAssertEqual(clock.phase(at: 101.5, duration: 6), 0.25, accuracy: 0.0001)
        clock.setRunning(false, at: 101.5)
        XCTAssertEqual(clock.phase(at: 900, duration: 6), 0.25, accuracy: 0.0001)
        clock.setRunning(true, at: 900)
        XCTAssertEqual(clock.phase(at: 900, duration: 6), 0.25, accuracy: 0.0001)
        XCTAssertEqual(clock.phase(at: 901.5, duration: 6), 0.5, accuracy: 0.0001)
        // Repeated lifecycle notifications cannot restart or double-charge it.
        clock.setRunning(true, at: 902)
        XCTAssertEqual(clock.elapsed(at: 903), 4.5, accuracy: 0.0001)
        clock.setRunning(false, at: 903)
        clock.setRunning(false, at: 904)
        XCTAssertEqual(clock.elapsed(at: 905), 4.5, accuracy: 0.0001)
    }

    func testBossMotionStartsStillAndIgnoresInvalidClockSamples() {
        var clock = BossMotionClock()
        XCTAssertEqual(clock.phase(at: 500, duration: 6), 0)
        clock.setRunning(false, at: 500)
        XCTAssertEqual(clock.phase(at: 9_000, duration: 6), 0,
                       "Reduce Motion or disabled background motion starts with a static treatment")
        clock.setRunning(true, at: .infinity)
        XCTAssertNil(clock.startedAt)
        clock.setRunning(true, at: 10)
        XCTAssertEqual(clock.elapsed(at: 9), 0)
        XCTAssertEqual(clock.phase(at: 12, duration: 0), 0)
        clock.setRunning(false, at: 12)
        XCTAssertEqual(clock.elapsed(at: .nan), 2)
    }

    func testAllBossPresentationAtlasAtRestAndQuarterCycle() throws {
        let fixtures = try BossModifier.allCases.map { boss in
            BossAtlasFixture(boss: boss, puzzle: try XCTUnwrap(makeGame(boss: boss).puzzle))
        }
        for phase in [0.0, 0.25] {
            let renderer = ImageRenderer(content:
                BossPresentationAtlas(fixtures: fixtures, phase: phase)
                    .environment(\.colorScheme, .light)
                    .environment(\.cosmeticTheme, .standard)
                    .background(Paper.page)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            attach(image, name: "boss-presentation-atlas-phase-\(phase)")
        }
        // Real gameplay header, not a substitute title in the atlas. Font and
        // rule survive at the narrowest supported page text width.
        for boss in BossModifier.allCases {
            let renderer = ImageRenderer(content:
                BossStamp(boss: boss, censored: boss == .censor ? .seven : nil)
                    .frame(width: 280)
                    .padding(8)
                    .background(Paper.page)
            )
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
            let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").lowercased().filter(\.isLetter)
            let name = boss.name.lowercased().filter(\.isLetter)
            XCTAssertTrue(recognized.contains(name), "Boss name is not readable: \(boss.name). OCR: \(recognized)")
        }
    }

    func testDisablingBackgroundMotionKeepsBossInkAtItsRestingPose() throws {
        let suite = "boss-motion-disabled-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: AppPreferences.Key.ambientMotion)
        for boss in BossModifier.allCases {
            let renderer = ImageRenderer(content:
                BossPerimeterVignette(boss: boss)
                    .frame(width: 180, height: 180)
                    .environment(\.scenePhase, .active)
                    .defaultAppStorage(defaults)
                    .background(Paper.page)
            )
            renderer.scale = 2
            XCTAssertEqual(try XCTUnwrap(renderer.uiImage?.pngData()),
                           try renderPerimeter(boss: boss, phase: 0).pngData(),
                           "The background-motion preference must freeze \(boss.name)'s decorative ink")
        }
    }

    func testEveryBossHasItsOwnRuleLinkedInkSignature() {
        let signatures = Set(BossModifier.allCases.map { BossInkSignature(boss: $0) })
        XCTAssertEqual(signatures.count, BossModifier.allCases.count)
        XCTAssertEqual(signatures, Set(BossInkSignature.allCases))
        XCTAssertEqual(BossInkSignature(boss: .deadline), .eightTicks)
        XCTAssertEqual(BossInkSignature(boss: .tikTak), .clock)
        XCTAssertEqual(BossInkSignature(boss: .unluckyLucky), .sleepingBookmark)
        XCTAssertEqual(BossInkSignature(boss: .grayTheGarry), .rowBrackets)
        XCTAssertEqual(BossInkSignature(boss: .garryTheGray), .boxBrackets)
    }

    func testAmbientInkAnimatesOnlyThePerimeterAndNeverThePlayableDigits() throws {
        for boss in BossModifier.allCases {
            let first = try renderPerimeter(boss: boss, phase: 0)
            let second = try renderPerimeter(boss: boss, phase: 0.25)
            XCTAssertNotEqual(first.pngData(), second.pngData(),
                              "\(boss.name) must have its own living ink treatment")
            let a = try pixels(first)
            let b = try pixels(second)
            // All glyph centers, not only the large central rectangle. Even
            // the outside row/column retain a motion-free number/tap region.
            let cell = a.width / 9
            var changedGlyphChannels = 0
            for square in Square.all {
                for dx in (cell / 3)...(cell * 2 / 3) {
                    for dy in (cell / 3)...(cell * 2 / 3) {
                        let x = square.col * cell + dx
                        let y = square.row * cell + dy
                        for channel in 0..<3 {
                            if a.channel(x: x, y: y, channel: channel)
                                != b.channel(x: x, y: y, channel: channel) {
                                changedGlyphChannels += 1
                            }
                        }
                    }
                }
            }
            XCTAssertEqual(changedGlyphChannels, 0,
                           "\(boss.name)'s animation intruded into a number")
        }
    }

    func testRouteArtworkIsSquareAndEachBossRetainsAVisibleSudoku() throws {
        var snapshots = Set<Data>()
        for boss in BossModifier.allCases {
            let renderer = ImageRenderer(content:
                BossRouteArtwork(boss: boss, isActive: false)
                    .frame(width: 180, height: 180)
                    .background(Paper.page)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertEqual(image.size, CGSize(width: 180, height: 180))
            snapshots.insert(try XCTUnwrap(image.pngData()))
            attach(image, name: "square-route-\(boss.rawValue)")
        }
        XCTAssertEqual(snapshots.count, BossModifier.allCases.count)
    }

    func testPausedAndReduceMotionRouteArtworkShareTheSameRestingPose() throws {
        for boss in BossModifier.allCases {
            func render(active: Bool, reduced: Bool, presented: Bool = true) throws -> Data {
                let renderer = ImageRenderer(content:
                    BossRouteArtwork(boss: boss, isActive: active, reduceMotionOverride: reduced)
                        .frame(width: 144, height: 144)
                        .environment(\.scenePhase, .active)
                        .environment(\.bossMotionIsActive, presented)
                )
                return try XCTUnwrap(renderer.uiImage?.pngData())
            }
            let paused = try render(active: false, reduced: false)
            XCTAssertEqual(paused, try render(active: true, reduced: true))
            XCTAssertEqual(paused, try render(active: true, reduced: false, presented: false))
        }
    }

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

    func testHandAndDigitRestrictionsDoNotPaintFalseBlockedSquaresUnderTheGrid() throws {
        for boss in [BossModifier.handyDandy, .censor] {
            let renderer = ImageRenderer(content:
                BossBoardUnderprint(boss: boss, fouled: [], greyed: [])
                    .frame(width: 180, height: 180)
                    .background(Paper.page)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            let bitmap = try pixels(image)
            let paper = (0..<3).map { bitmap.channel(x: 1, y: 1, channel: $0) }
            var markedPixels = 0
            for y in 1..<(bitmap.width - 1) {
                for x in 1..<(bitmap.width - 1) {
                    if (0..<3).contains(where: {
                        abs(Int(bitmap.channel(x: x, y: y, channel: $0)) - Int(paper[$0])) > 2
                    }) { markedPixels += 1 }
                }
            }
            XCTAssertEqual(markedPixels, 0,
                           "\(boss.name) may tint paper, but only real rule state may mark board squares")
            attach(image, name: "no-false-board-restriction-\(boss.rawValue)")
        }
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

    func testGarryGameplayDoesNotDrawDecorativeBracketsAroundUnbarredUnits() throws {
        for boss in [BossModifier.grayTheGarry, .garryTheGray] {
            var puzzle = try XCTUnwrap(makeGame(boss: boss).puzzle)
            // Move the real restriction well below the former decorative
            // middle-row/upper-corner brackets. This is a rendering fixture,
            // not playthrough evidence or a change to live player state.
            puzzle.bossTurn?.greyed = Set(boss == .grayTheGarry ? Geometry.rows[7] : Geometry.boxes[8])
            let renderer = ImageRenderer(content:
                BossBoardOverlay(puzzle: puzzle, phaseOverride: 0.25)
                    .frame(width: 360, height: 360)
                    .background(Color.white)
            )
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage)
            let raster = try pixels(image)
            let scale = CGFloat(raster.width) / 360
            // Inside the left board edge, away from the permanent frame.
            // Neither the true bottom restriction nor its outline is here.
            var falseCuePixels = 0
            for y in Int(36 * scale)..<Int(252 * scale) {
                for x in Int(5 * scale)..<Int(11 * scale) {
                    if (0..<3).contains(where: { raster.channel(x: x, y: y, channel: $0) < 250 }) {
                        falseCuePixels += 1
                    }
                }
            }
            XCTAssertEqual(falseCuePixels, 0, "\(boss.name) must not bracket an unrelated row or box")
            attach(image, name: "garry-only-actual-restriction-\(boss.rawValue)")
        }
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

    func testAllBossNamesAndRulesFitTheExistingTwoLineHeaderHeight() throws {
        let font = UIFont.systemFont(ofSize: 11.5, weight: .semibold)
        for width: CGFloat in [280, 300, 340] {
            let titleWidth = width - 26 - 7
            for boss in BossModifier.allCases {
                let title = NSAttributedString(string: boss.name.uppercased(),
                                               attributes: [.font: font])
                let bounds = title.boundingRect(with: CGSize(width: titleWidth, height: 200),
                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                context: nil)
                XCTAssertLessThanOrEqual(bounds.height, font.lineHeight + 1,
                                         "\(boss.name) clips in a \(width)-point stamp")
                let renderer = ImageRenderer(content:
                    BossStamp(boss: boss, censored: boss == .censor ? .seven : nil)
                        .frame(width: width)
                        .background(Paper.page)
                )
                let image = try XCTUnwrap(renderer.uiImage)
                XCTAssertLessThanOrEqual(image.size.height, font.lineHeight * 2 + 1,
                                         "The seal must not make the Boss header taller or shrink the board")
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
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = boss
        var game = Game(run: run)
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.boss, boss,
                       "The visual fixture must deal the requested Boss from its eligible level pool.")
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

    private func renderPerimeter(boss: BossModifier, phase: Double) throws -> UIImage {
        let renderer = ImageRenderer(content:
            BossPerimeterDrawing(boss: boss, phase: phase)
                .frame(width: 180, height: 180)
                .background(Paper.page)
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

private struct BossAtlasFixture: Identifiable {
    let boss: BossModifier
    let puzzle: PuzzleState
    var id: String { boss.rawValue }
}

/// A design-proof sheet: real BossStamp, real route artwork, and the real
/// BossBoardOverlay on a public-board proof. No hidden solution is rendered.
private struct BossPresentationAtlas: View {
    let fixtures: [BossAtlasFixture]
    let phase: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Boss ink proof · phase \(phase.formatted())")
                .font(Print.heading(24))
                .foregroundStyle(Paper.ink)
            ForEach(Array(stride(from: 0, to: fixtures.count, by: 3)), id: \.self) { start in
                HStack(alignment: .top, spacing: 18) {
                    ForEach(Array(fixtures[start..<min(start + 3, fixtures.count)])) { fixture in
                        VStack(alignment: .leading, spacing: 10) {
                            BossStamp(boss: fixture.boss, censored: fixture.puzzle.censoredDigit)
                                .frame(width: 318, height: 44, alignment: .topLeading)
                            HStack(spacing: 18) {
                                BossRouteArtwork(boss: fixture.boss, phaseOverride: phase)
                                    .frame(width: 150, height: 150)
                                ZStack {
                                    PublicBossProofBoard(board: fixture.puzzle.board)
                                    BossBoardOverlay(puzzle: fixture.puzzle, phaseOverride: phase)
                                }
                                .frame(width: 150, height: 150)
                            }
                            Text("Route / in-play overlay")
                                .font(Print.caption(11))
                                .foregroundStyle(Paper.inkSoft)
                        }
                        .padding(10)
                        .background(Paper.pageWarm)
                    }
                }
            }
        }
        .padding(18)
    }
}

private struct PublicBossProofBoard: View {
    let board: Board

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 9
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Paper.page))
            for square in Square.all {
                if board.isGiven[square.index] {
                    context.fill(Path(CGRect(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell,
                                             width: cell, height: cell)), with: .color(Paper.cellGiven))
                }
                if let digit = board[square] {
                    context.draw(Text(String(digit.rawValue)).font(Print.numeral(cell * 0.62, weight: .medium))
                        .foregroundStyle(Paper.ink),
                                 at: CGPoint(x: (CGFloat(square.col) + 0.5) * cell,
                                             y: (CGFloat(square.row) + 0.5) * cell))
                }
            }
            for index in 0...9 {
                var rule = Path()
                rule.move(to: CGPoint(x: CGFloat(index) * cell, y: 0))
                rule.addLine(to: CGPoint(x: CGFloat(index) * cell, y: size.height))
                rule.move(to: CGPoint(x: 0, y: CGFloat(index) * cell))
                rule.addLine(to: CGPoint(x: size.width, y: CGFloat(index) * cell))
                context.stroke(rule, with: .color(Paper.ink.opacity(index.isMultiple(of: 3) ? 0.85 : 0.32)),
                               lineWidth: index.isMultiple(of: 3) ? 1.3 : 0.5)
            }
        }
    }
}
