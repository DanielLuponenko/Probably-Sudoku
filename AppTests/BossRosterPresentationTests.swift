import XCTest
import SwiftUI
import UIKit
import Vision
@testable import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BossRosterPresentationTests: XCTestCase {
    func testPledgeUsesSelectedIdentityAndRejectsDelayedPreviousTurnChoice() throws {
        let model = try model(.collateral)
        let initial = try XCTUnwrap(model.puzzle)
        let card = try XCTUnwrap(initial.handCards.first)
        let context = try XCTUnwrap(model.bossChoiceContext)
        model.tapHand(0)
        model.pledgeBossCard(card.id, context: context)
        XCTAssertEqual(model.puzzle?.bossState.encounter.pledgedCard?.id, card.id)
        XCTAssertFalse(model.handCards.contains { $0.id == card.id })
        XCTAssertNil(model.selectedHandIndex)
        let pledged = try model.game.encoded()
        model.pledgeBossCard(card.id, context: context)
        XCTAssertEqual(try model.game.encoded(), pledged)
        let restored = try Game(decoding: pledged)
        XCTAssertEqual(restored.puzzle?.bossState.encounter.pledgedCard?.id, card.id)
        model.endTurn()
        XCTAssertEqual(model.handCards.filter { $0.id == card.id }.count, 1)
        XCTAssertNil(model.puzzle?.bossState.encounter.pledgedCard)
        let nextTurn = try model.game.encoded()
        model.pledgeBossCard(card.id, context: context)
        XCTAssertEqual(try model.game.encoded(), nextTurn, "A delayed old button cannot pledge a new turn")
    }

    func testEditionSelectionPreservesHandSelectionAndLocksAfterAcceptedFill() throws {
        let model = try model(.splitEdition)
        let context = try XCTUnwrap(model.bossChoiceContext)
        model.tapHand(0)
        model.chooseBossEdition(1, context: context)
        XCTAssertEqual(model.puzzle?.bossState.encounter.selectedEdition, 1)
        XCTAssertEqual(model.selectedHandIndex, 0)
        let chosen = try model.game.encoded()
        let restored = try Game(decoding: chosen)
        XCTAssertEqual(restored.puzzle?.bossState.encounter.selectedEdition, 1)
        try playOne(model)
        let committed = try model.game.encoded()
        model.chooseBossEdition(0, context: context)
        XCTAssertEqual(try model.game.encoded(), committed)
        model.endTurn()
        XCTAssertEqual(model.puzzle?.bossState.encounter.editionScores[0], 0)
        XCTAssertGreaterThan(model.puzzle?.bossState.encounter.editionScores[1] ?? 0, 0)
        let afterBank = try model.game.encoded()
        model.chooseBossEdition(0, context: context)
        XCTAssertEqual(try model.game.encoded(), afterBank)
    }

    func testActiveRosterRendersAtNormalAndCompactSizesWithoutMutatingGame() async throws {
        for boss in BossModifier.activeBosses {
            let model = try model(boss)
            for size in [CGSize(width: 375, height: 667), CGSize(width: 402, height: 874)] {
                try await capture(model, boss: boss, stage: "ready", size: size)
            }
        }
    }

    func testNewBossControlsRenderCommittedAndAccessibilityStates() async throws {
        for boss in [BossModifier.collateral, .splitEdition, .lastEdition] {
            let model = try model(boss)
            if boss == .collateral {
                let card = try XCTUnwrap(model.handCards.first)
                model.tapHand(0)
                try await capture(model, boss: boss, stage: "selected", size: CGSize(width: 375, height: 667))
                model.pledgeBossCard(card.id, context: try XCTUnwrap(model.bossChoiceContext))
            } else if boss == .splitEdition {
                model.chooseBossEdition(1, context: try XCTUnwrap(model.bossChoiceContext))
                try playOne(model)
            } else {
                try playOne(model)
            }
            try await capture(model, boss: boss, stage: "committed", size: CGSize(width: 402, height: 874))
            try await capture(model, boss: boss, stage: "large-text", size: CGSize(width: 375, height: 667), largeText: true)
        }
    }

    func testAccessibleBossChoicesKeepReadableTypeAndReachableActionsOnSmallPhones() async throws {
        for boss in [BossModifier.collateral, .splitEdition] {
            for size in [CGSize(width: 320, height: 568), CGSize(width: 375, height: 667)] {
                let model = try model(boss)
                for committed in [false, true] {
                    if committed, boss == .collateral {
                        let card = try XCTUnwrap(model.handCards.first)
                        model.tapHand(0)
                        model.pledgeBossCard(card.id, context: try XCTUnwrap(model.bossChoiceContext))
                    } else if committed {
                        model.chooseBossEdition(1, context: try XCTUnwrap(model.bossChoiceContext))
                        try playOne(model)
                    }
                    let image = try await capture(model, boss: boss,
                        stage: committed ? "AX5-choice-committed" : "AX5-choice-ready",
                        size: size, textSize: .accessibility5)
                    let request = VNRecognizeTextRequest()
                    request.recognitionLevel = .accurate
                    try VNImageRequestHandler(cgImage: try XCTUnwrap(image.cgImage)).perform([request])
                    let rows = request.results ?? []
                    let printed = rows.compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: " ").lowercased()
                    XCTAssertTrue(printed.contains("end turn"), printed)
                    XCTAssertTrue(printed.contains("toss"), printed)
                    let phrase = boss == .splitEdition ? "256,000" : committed ? "returns at bank" : "mult"
                    let row = try XCTUnwrap(rows.first {
                        $0.topCandidates(1).first?.string.lowercased().contains(phrase) == true
                    }, "Missing readable choice copy: \(printed)")
                    XCTAssertGreaterThanOrEqual(row.boundingBox.height * image.size.height, 12,
                        "Essential boss choice copy must not regress to 9–12pt type at AX5")
                    let endTurn = try XCTUnwrap(rows.first {
                        $0.topCandidates(1).first?.string.lowercased().contains("end turn") == true
                    })
                    XCTAssertLessThan((1 - endTurn.boundingBox.minY) * image.size.height, size.height)
                }
            }
        }
    }

    func testCompletedEditionStaysVisibleAfterChoosingTheOtherStack() async throws {
        let model = try model(.splitEdition)
        let target = try XCTUnwrap(model.puzzle).bossState.encounter.editionTargets[0]
        model.qaAward(points: target)
        model.chooseBossEdition(1, context: try XCTUnwrap(model.bossChoiceContext))
        XCTAssertEqual(model.puzzle?.bossState.encounter.selectedEdition, 1)
        XCTAssertEqual(model.puzzle?.bossState.encounter.editionScores, [target, 0])
        try await capture(model, boss: .splitEdition, stage: "one-edition-complete", size: CGSize(width: 375, height: 667))
    }

    func testPrintedLastEditionKeepsTheCommittedReceiptVisible() async throws {
        let model = try model(.lastEdition)
        try playOne(model)
        model.endTurn()
        XCTAssertEqual(model.puzzle?.bossState.encounter.banksUsed, 1)
        XCTAssertGreaterThan(model.puzzle?.lastScoringLedger?.total ?? 0, 0)
        model.finishScorePresentation()
        try await capture(model, boss: .lastEdition, stage: "printed", size: CGSize(width: 402, height: 874))
    }

    private func model(_ boss: BossModifier) throws -> GameModel {
        var run = RunState(seed: "boss-roster-presentation-\(boss.rawValue)")
        run.level = BossModifier.finalBosses.contains(boss) ? 9 : 1
        run.slot = .boss
        run.pendingBoss = boss
        run.bookmarks = [Bookmarks.localGossip, Bookmarks.opEd, Bookmarks.theSundaySupplement].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 0)
        }
        run.markers = [OwnedMarker(defID: Markers.golden, boughtAtLevel: 1,
                                  pricePaid: 0, squares: [Square(0), Square(40)])]
        run.buffs = [OwnedBuff(defID: Buffs.freshInk, pricePaid: 0)]
        var game = Game(run: run)
        try game.startPuzzle()
        return GameModel(resuming: game, savesProgress: false)
    }

    private func playOne(_ model: GameModel) throws {
        let p = try XCTUnwrap(model.puzzle)
        for index in p.hand.indices where !model.isBlocked(handIndex: index) {
            if let square = p.board.blanks.first(where: {
                !model.isBarred($0) && p.board.correctDigit(at: $0) == p.hand[index]
            }) {
                model.place(handIndex: index, at: square)
                XCTAssertFalse(try XCTUnwrap(model.puzzle).board.isBlank(square))
                model.finishScorePresentation()
                return
            }
        }
        XCTFail("Fixture requires one held correct placement")
    }

    @discardableResult
    private func capture(_ model: GameModel, boss: BossModifier, stage: String,
                         size: CGSize, largeText: Bool = false,
                         textSize: DynamicTypeSize? = nil) async throws -> UIImage {
        let saved = try model.game.encoded()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldWindow = scene.windows.first { $0.isKeyWindow }
        let flipper = PageFlipper()
        let surface = RunPageSurface(model: model, flipper: flipper,
            controls: [StripControl(systemImage: "questionmark", label: "Help", action: {}),
                       StripControl(systemImage: "gearshape", label: "Settings", action: {})],
            safeAreaInsets: EdgeInsets(top: size.height > 700 ? 62 : 20, leading: 0,
                                      bottom: size.height > 700 ? 34 : 0, trailing: 0),
            onTapBuff: { _ in }) {
                PuzzlePageView(model: model, puzzle: model.puzzle!, isClockRunning: false)
            }
            .environment(\.gameReduceMotion, true)
            .environment(flipper)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
            .environment(\.levelPalette, .forDisplay(slot: .boss))
            .environment(\.scenePhase, .inactive)
            .environment(\.bossMotionIsActive, false)
            .environment(\.dynamicTypeSize, textSize ?? (largeText ? .accessibility3 : .large))
            .frame(width: size.width, height: size.height)
        let host = UIHostingController(rootView: surface)
        host.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil; oldWindow?.makeKey(); flipper.cancel() }
        try await Task.sleep(for: .milliseconds(180))
        window.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat(); format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "roster-\(boss.rawValue)-\(stage)-\(Int(size.width))x\(Int(size.height))"
        attachment.lifetime = .keepAlways; add(attachment)
        XCTAssertEqual(try model.game.encoded(), saved, "Rendering a boss choice cannot commit it")
        return image
    }
}
