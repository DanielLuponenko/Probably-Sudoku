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

    func testRouteAndHeaderInkAnimationKeepsItsIllustratedDigitCentersStill() throws {
        for boss in BossModifier.allCases {
            let first = try renderPerimeter(boss: boss, phase: 0)
            let second = try renderPerimeter(boss: boss, phase: 0.25)
            XCTAssertNotEqual(first.pngData(), second.pngData(),
                              "\(boss.name) must have its own living ink treatment")
            let a = try pixels(first)
            let b = try pixels(second)
            // This decorative renderer is retained for route/header artwork,
            // not mounted on the playable board. Its illustrated digits stay still.
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

    func testEveryBossRendersAndPassiveBossesLeaveThePlayableBoardUndecorated() async throws {
        var symbols = Set<String>()
        for boss in BossModifier.allCases {
            let design = BossBoardDesign(boss: boss)
            XCTAssertNotNil(UIImage(systemName: design.symbol), "Missing Boss header symbol: \(boss.name)")
            symbols.insert(design.symbol)
            let game = try makeGame(boss: boss)
            let before = try game.encoded()
            let image = try await render(game)
            XCTAssertEqual(image.size, CGSize(width: 360, height: 360))
            if boss != .fog && !boss.foulsSquaresEachTurn && !boss.greysARowEachTurn && !boss.greysABoxEachTurn {
                var clearRun = game.run
                clearRun.puzzle?.boss = nil
                let clear = try await render(Game(run: clearRun))
                XCTAssertEqual(image.pngData(), clear.pngData(),
                               "\(boss.name) must not add lines, stamps, fog bands or perimeter doodles inside the board")
            }
            XCTAssertEqual(try game.encoded(), before)
            attach(image, name: "clean-boss-board-\(boss.rawValue)")
        }
        // Boss identity remains in its existing header, not across the cells.
        XCTAssertEqual(symbols.count, BossModifier.allCases.count)
    }

    func testFogHidesMarkerDecorationsWithoutRevealingTheirLocations() async throws {
        let original = try makeGame(boss: .fog)
        let blanks = try XCTUnwrap(original.puzzle?.board.blanks)
        let first = try XCTUnwrap(blanks.first)
        let last = try XCTUnwrap(blanks.last)
        XCTAssertNotEqual(first, last)
        let withoutMarkers = try await render(original)

        for square in [first, last] {
            var run = original.run
            run.markers = [OwnedMarker(defID: "mk_copper", boughtAtLevel: 1,
                                       pricePaid: 0, squares: [square])]
            let game = Game(run: run)
            let model = GameModel(frozen: game, page: .puzzle)
            XCTAssertTrue(model.markersAreHidden)
            XCTAssertTrue(model.visibleMarkers.isEmpty)
            let markedImage = try await render(game)
            XCTAssertEqual(markedImage.pngData(), withoutMarkers.pngData(),
                           "Fog must not disclose hidden Marker positions")
        }
        attach(withoutMarkers, name: "fog-marker-locations-remain-hidden")
    }

    func testFogConcealmentDoesNotWashOutBoardPaperOrDigits() async throws {
        let fog = try makeGame(boss: .fog)
        var clearRun = fog.run
        clearRun.puzzle?.boss = nil
        let clearImage = try await render(Game(run: clearRun))
        let fogImage = try await render(fog)
        XCTAssertNotEqual(fogImage.pngData(), clearImage.pngData(),
                          "Fog is now visible above the paper and below the readable digits")
        let clear = try pixels(clearImage)
        let mist = try pixels(fogImage)
        var crispInk = 0
        for y in 12..<(clear.width - 12) {
            for x in 12..<(clear.width - 12) {
                // Erode the dark glyph mask by one pixel: antialiased edges
                // legitimately blend with their changed paper background.
                let isOpaqueInk = (-1...1).allSatisfy { dy in
                    (-1...1).allSatisfy { dx in
                        clear.channel(x: x + dx, y: y + dy, channel: 3) == 255
                            && (0..<3).allSatisfy { clear.channel(x: x + dx, y: y + dy, channel: $0) < 40 }
                    }
                }
                if isOpaqueInk {
                    crispInk += 1
                    for channel in 0..<3 {
                        XCTAssertEqual(clear.channel(x: x, y: y, channel: channel),
                                       mist.channel(x: x, y: y, channel: channel),
                                       "Mist must remain below opaque numeral ink")
                    }
                }
            }
        }
        XCTAssertGreaterThan(crispInk, 100, "The exact opaque-ink comparison must sample numeral pixels")
        attach(fogImage, name: "fog-mist-below-crisp-digits")
    }

    func testReduceMotionKeepsEveryBossOverlayTreatmentVisible() throws {
        for boss in BossModifier.allCases {
            let puzzle = try XCTUnwrap(makeGame(boss: boss).puzzle)
            XCTAssertEqual(try renderOverlay(puzzle, reduceMotion: false).pngData(),
                           try renderOverlay(puzzle, reduceMotion: true).pngData(),
                           "Reduce Motion removes movement, not \(boss.name)'s rule cues")
        }
    }

    func testPassiveBossOverlayIsEmptyAtEveryMotionAndClockPhase() throws {
        let passive = BossModifier.allCases.filter {
            !$0.foulsSquaresEachTurn && !$0.greysARowEachTurn && !$0.greysABoxEachTurn
        }
        let emptyRenderer = ImageRenderer(content: Color.white.frame(width: 180, height: 180))
        emptyRenderer.scale = 2
        let empty = try XCTUnwrap(emptyRenderer.uiImage?.pngData())
        for boss in passive {
            let puzzle = try XCTUnwrap(makeGame(boss: boss).puzzle)
            for phase in [0.0, 0.25, 0.75] {
                let renderer = ImageRenderer(content:
                    BossBoardOverlay(puzzle: puzzle, secondsLeft: phase == 0 ? 180 : 1,
                                     phaseOverride: phase)
                        .frame(width: 180, height: 180)
                        .background(Color.white)
                )
                renderer.scale = 2
                XCTAssertEqual(try XCTUnwrap(renderer.uiImage?.pngData()), empty,
                               "\(boss.name) must not paint decorative board ink at phase \(phase)")
            }
        }
    }

    func testReadOnlyBoardSnapshotsKeepPassiveBossesUndecorated() throws {
        for boss in BossModifier.allCases where !boss.foulsSquaresEachTurn
            && !boss.greysARowEachTurn && !boss.greysABoxEachTurn {
            let game = try makeGame(boss: boss)
            let puzzle = try XCTUnwrap(game.puzzle)
            var clear = puzzle
            clear.boss = nil
            func snapshot(_ state: PuzzleState) throws -> Data {
                let renderer = ImageRenderer(content:
                    GameplayBoardSnapshot(board: state.board, puzzle: state)
                        .frame(width: 320, height: 320)
                        .environment(\.cosmeticTheme, .standard)
                        .environment(\.colorScheme, .light)
                )
                renderer.scale = 2
                return try XCTUnwrap(renderer.uiImage?.pngData())
            }
            XCTAssertEqual(try snapshot(puzzle), try snapshot(clear),
                           "Retained Results/briefing boards must not restore \(boss.name)'s removed doodles")
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

    func testRepeatedGarryRestrictionStillIdentifiesANewLandingEachTurn() throws {
        var puzzle = try XCTUnwrap(makeGame(boss: .grayTheGarry).puzzle)
        func landing(_ puzzle: PuzzleState) -> BossBrickLandingEvent {
            let feedback = BossBoardFeedback(puzzle: puzzle)
            return BossBrickLandingEvent(boss: feedback.boss, turn: feedback.turnNumber, squares: feedback.greyed)
        }
        let first = landing(puzzle)
        puzzle.turnNumber += 1
        let next = landing(puzzle)
        XCTAssertEqual(first.squares, next.squares)
        XCTAssertNotEqual(first, next, "An unchanged row still needs a new drop on the next turn.")
        XCTAssertEqual(next, landing(puzzle), "An unrelated view refresh must not replay the drop.")
    }

    func testBrickLifecycleHandlesReducedAndHiddenTurnsWithoutReplayingThem() {
        let squares = Set([Square(0), Square(1)])
        let first = BossBrickLandingEvent(boss: .grayTheGarry, turn: 1, squares: squares)
        let second = BossBrickLandingEvent(boss: .grayTheGarry, turn: 2, squares: squares)
        var lifecycle = BossBrickLandingLifecycle()
        XCTAssertFalse(lifecycle.prepare(first, canAnimate: false))
        XCTAssertTrue(lifecycle.isSettled)
        XCTAssertFalse(lifecycle.prepare(first, canAnimate: true), "Turning Reduce Motion off must not replay")
        XCTAssertTrue(lifecycle.prepare(second, canAnimate: true), "The same row on a new turn still lands")
        XCTAssertTrue(lifecycle.isPending)
        XCTAssertTrue(lifecycle.start(second))
        XCTAssertFalse(lifecycle.prepare(second, canAnimate: true), "View redraw does not restart")
        XCTAssertFalse(lifecycle.prepare(second, canAnimate: false))
        XCTAssertTrue(lifecycle.isSettled)
        XCTAssertFalse(lifecycle.prepare(second, canAnimate: true), "Resuming or closing an overlay does not replay")
    }

    func testBrickLifecycleCancelsPendingLandingWhenCoveredAndRejectsStaleStart() {
        let first = BossBrickLandingEvent(boss: .grayTheGarry, turn: 1, squares: [Square(0)])
        let changed = BossBrickLandingEvent(boss: .garryTheGray, turn: 1, squares: [Square(0)])
        var lifecycle = BossBrickLandingLifecycle()
        XCTAssertTrue(lifecycle.prepare(first, canAnimate: true))
        XCTAssertFalse(lifecycle.prepare(first, canAnimate: false))
        XCTAssertFalse(lifecycle.start(first), "A delayed start cannot revive a covered landing")
        XCTAssertTrue(lifecycle.prepare(changed, canAnimate: true))
        XCTAssertFalse(lifecycle.start(first), "A stale task cannot start another boss's landing")
        XCTAssertTrue(lifecycle.start(changed))
    }

    func testFirstBrickEntranceWaitsForPageCurlThenStartsExactlyOnce() {
        let event = BossBrickLandingEvent(boss: .garryTheGray, turn: 1, squares: [Square(40)])
        var lifecycle = BossBrickLandingLifecycle()
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: false, deferUntilVisible: true))
        XCTAssertTrue(lifecycle.isPending, "A newly mounted destination has not been seen yet")
        XCTAssertFalse(lifecycle.isSettled)
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: false, deferUntilVisible: true))
        XCTAssertTrue(lifecycle.prepare(event, canAnimate: true), "Reveal must trigger the missed first landing")
        XCTAssertTrue(lifecycle.start(event))
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: true))
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: false, deferUntilVisible: true))
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: true), "An outgoing page must not replay")
    }

    func testDeferredBrickEntranceIsCancelledByBackgroundOrReducedMotion() {
        let event = BossBrickLandingEvent(boss: .grayTheGarry, turn: 1, squares: [Square(9)])
        var lifecycle = BossBrickLandingLifecycle()
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: false, deferUntilVisible: true))
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: false))
        XCTAssertFalse(lifecycle.start(event))
        XCTAssertTrue(lifecycle.isSettled)
        XCTAssertFalse(lifecycle.prepare(event, canAnimate: true))
    }

    func testBrickImpactsAreSeparatedAndLastDustFullyClears() {
        for count in 1...9 {
            let finish = BossBrickSequence.duration(count: count)
            for rank in 0..<count {
                let impact = Double(rank) * BossBrickSequence.interval + BossBrickMotion.impactTime + 0.00000001
                let current = BossBrickMotion(elapsed: BossBrickSequence.localElapsed(impact, rank: rank))
                XCTAssertEqual(current.height, 0, accuracy: 0.000001)
                XCTAssertGreaterThan(current.dust, 0.99)
                if rank + 1 < count {
                    let next = BossBrickMotion(elapsed: BossBrickSequence.localElapsed(impact, rank: rank + 1))
                    XCTAssertGreaterThan(next.height, 0.5, "The next brick must still be visibly airborne")
                    XCTAssertEqual(next.dust, 0)
                }
                let settled = BossBrickMotion(elapsed: BossBrickSequence.localElapsed(finish, rank: rank))
                XCTAssertEqual(settled.height, 0)
                XCTAssertEqual(settled.dust, 0, accuracy: 0.000001)
            }
            XCTAssertLessThan(finish, 2.5, "Even a complete empty row must settle promptly")
        }
    }

    func testGarryBrickFeedbackContainsOnlyEligibleBlankCellsAndLeavesAnExit() throws {
        for boss in [BossModifier.grayTheGarry, .garryTheGray] {
            let puzzle = try XCTUnwrap(makeGame(boss: boss).puzzle)
            let restricted = BossBoardFeedback(puzzle: puzzle).greyed
            XCTAssertFalse(restricted.isEmpty)
            XCTAssertTrue(restricted.isSubset(of: Set(puzzle.board.blanks)))
            XCTAssertFalse(Set(puzzle.board.blanks).subtracting(restricted).isEmpty)
            XCTAssertTrue(restricted.allSatisfy { puzzle.board[$0] == nil })
        }
    }

    func testBrickHasDistinctAirborneImpactAndSettledFrames() throws {
        XCTAssertNotNil(UIImage(named: "BossBrick"), "The physical brick asset must be bundled.")
        var frames = Set<Data>()
        for (name, elapsed) in [("airborne", 0.18), ("impact", 0.40), ("rebound", 0.47),
                                ("dust-spread", 0.60), ("settled", 2.0)] {
            let renderer = ImageRenderer(content:
                BossBrickDrawing(size: 72, motion: BossBrickMotion(elapsed: elapsed))
                    .padding(.top, 180)
                    .padding(40)
                    .background(Paper.page)
            )
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            frames.insert(try XCTUnwrap(image.pngData()))
            attach(image, name: "physical-brick-\(name)")
        }
        XCTAssertEqual(frames.count, 5, "A landing must visibly fall, impact, rebound, shed dust and settle.")
        XCTAssertGreaterThan(BossBrickMotion(elapsed: 0.18).height, 1, "The fall must be visible at phone size.")
        XCTAssertEqual(BossBrickMotion(elapsed: 2).height, 0)
        XCTAssertEqual(BossBrickMotion(elapsed: 2).dust, 0)
    }

    func testFallingBrickLayerCannotEscapeTheBoardIntoTheHUD() throws {
        for boss in [BossModifier.grayTheGarry, .garryTheGray] {
            let game = try makeGame(boss: boss)
            let before = try game.encoded()
            for elapsed in [0.18, 0.40, 0.70, 2.0] {
                let renderer = ImageRenderer(content:
                    BossBrickLandingOverlay(feedback: BossBoardFeedback(puzzle: game.puzzle),
                                            reduceMotion: false, elapsedOverride: elapsed)
                        .frame(width: 270, height: 270)
                        .padding(30)
                        .background(Color.white)
                )
                renderer.scale = 1
                let raster = try pixels(XCTUnwrap(renderer.uiImage))
                let background = (0..<3).map { raster.channel(x: 0, y: 0, channel: $0) }
                var escaped = 0
                for y in 0..<330 {
                    for x in 0..<330 where !(30..<300).contains(x) || !(30..<300).contains(y) {
                        if (0..<3).contains(where: { raster.channel(x: x, y: y, channel: $0) != background[$0] }) {
                            escaped += 1
                        }
                    }
                }
                XCTAssertEqual(escaped, 0, "\(boss.name) at \(elapsed)s escaped the board")
            }
            XCTAssertEqual(try game.encoded(), before)
        }
    }

    func testBrickFallsStraightAndSettlesInsideItsSquareAtPhoneAndTabletSizes() throws {
        let phases = [0.0, 0.035, 0.14, 0.28, 0.39, 0.40, 0.47, 0.54, 0.70, 0.86, 2.0]
        for size: CGFloat in [28, 40, 64] {
            for scale: CGFloat in [2, 3] {
                for elapsed in phases {
                    // A full empty cell surrounds the brick on every side. This
                    // permits the intentional vertical airborne corridor, but
                    // rejects lateral drift and any spill after contact.
                    let renderer = ImageRenderer(content:
                        BossBrickDrawing(size: size, motion: BossBrickMotion(elapsed: elapsed))
                            .padding(size)
                            .background(Color.white)
                    )
                    renderer.scale = scale
                    let image = try XCTUnwrap(renderer.uiImage)
                    let raster = try pixels(image)
                    let cell = Int(size * scale)
                    XCTAssertEqual(raster.width, cell * 3)
                    XCTAssertEqual(image.cgImage?.height, cell * 3)
                    let background = (0..<3).map { raster.channel(x: 0, y: 0, channel: $0) }
                    var changedOutside = 0
                    var changedOutsideCorridor = 0
                    var paintedInside = 0
                    for y in 0..<(cell * 3) {
                        for x in 0..<(cell * 3) {
                            let changed = (0..<3).contains {
                                raster.channel(x: x, y: y, channel: $0) != background[$0]
                            }
                            guard changed else { continue }
                            if !(cell..<(cell * 2)).contains(x) || y >= cell * 2 {
                                changedOutsideCorridor += 1
                            }
                            if (cell..<(cell * 2)).contains(x) && (cell..<(cell * 2)).contains(y) {
                                paintedInside += 1
                            } else {
                                changedOutside += 1
                            }
                        }
                    }
                    let sample = "\(size)pt at \(scale)×, \(elapsed)s"
                    XCTAssertEqual(changedOutsideCorridor, 0, "Airborne bricks cannot drift into another column: \(sample)")
                    if elapsed >= BossBrickMotion.impactTime {
                        XCTAssertEqual(changedOutside, 0,
                                       "After contact, clay, rebound, shadow and dust stay in the blocked square: \(sample)")
                        XCTAssertGreaterThan(paintedInside, cell * cell / 5,
                                             "Containment must retain a visible brick: \(sample)")
                    }
                    if changedOutsideCorridor != 0 || (elapsed >= BossBrickMotion.impactTime && changedOutside != 0) {
                        attach(image, name: "brick-cell-spill-\(size)-\(scale)-\(elapsed)")
                    }
                }
            }
        }
    }

    func testGarryBrickBlocksItsBlankAndLeavesAdjacentBlankSelectable() throws {
        for boss in [BossModifier.grayTheGarry, .garryTheGray] {
            let game = try makeGame(boss: boss)
            let puzzle = try XCTUnwrap(game.puzzle)
            let blocked = try XCTUnwrap(puzzle.bossTurn?.greyed)
            let pair = try XCTUnwrap(blocked.sorted { $0.index < $1.index }.compactMap { square in
                puzzle.board.blanks.first { neighbor in
                    !blocked.contains(neighbor)
                        && abs(neighbor.row - square.row) + abs(neighbor.col - square.col) == 1
                }.map { (square, $0) }
            }.first, "The \(boss.name) fixture needs a blocked blank beside an available blank")
            let model = GameModel(frozen: game, page: .puzzle)
            let before = try model.game.encoded()
            XCTAssertTrue(puzzle.board.isBlank(pair.0))
            XCTAssertTrue(model.isBarred(pair.0))
            XCTAssertFalse(model.isBarred(pair.1))

            model.tapSquare(pair.0)
            XCTAssertNil(model.selectedSquare, "The brick-covered blank must reject selection")

            model.tapSquare(pair.1)
            XCTAssertEqual(model.selectedSquare, pair.1,
                           "The adjacent blank must remain selectable for \(boss.name)")
            XCTAssertEqual(try model.game.encoded(), before,
                           "Inspecting either square must not change puzzle or saved-run state")
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

    private func render(_ game: Game) async throws -> UIImage {
        try await BossHostedGridCapture.image(game)
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

@MainActor
enum BossHostedGridCapture {
    static func image(_ game: Game, phase: Double? = nil) async throws -> UIImage {
        let puzzle = try XCTUnwrap(game.puzzle)
        let model = GameModel(frozen: game, page: .puzzle)
        let size = CGSize(width: 360, height: 360)
        // Cells host a UIKit touch recognizer. ImageRenderer substitutes its
        // unsupported-view glyph, so it cannot prove numeral legibility.
        let root = GridView(model: model, board: puzzle.board, fogPhaseOverride: phase)
            .frame(width: size.width, height: size.height)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.gameReduceMotion, true)
        let host = UIHostingController(rootView: root)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.backgroundColor = .white
        window.rootViewController = host
        defer { window.isHidden = true; window.rootViewController = nil; oldKey?.makeKey() }
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}
