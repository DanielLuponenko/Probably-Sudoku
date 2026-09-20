import Foundation
import XCTest
@testable import ProbablySudokuEngine

/// Independent acceptance probes. Fixtures keep a finite multiset and real
/// action paths; balance rows are solution-assisted mechanical probes only.
final class BossRosterRedesignReviewTests: XCTestCase {
    private let regular: Set<BossModifier> = [.fog, .mirror, .erratum, .accountant,
        .tikTak, .garryTheGray, .bookends, .rebinder, .chainStitcher, .returnSlip,
        .dryPress, .backPage, .royaltyContract, .rivalColumn, .publicist, .collateral]
    private let finals: Set<BossModifier> = [.heavyLifter, .unluckyLucky, .bindery,
        .reviewBoard, .splitEdition, .lastEdition]

    private func data<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    private func fixture(_ boss: BossModifier, hand: [Digit] = [.one, .one, .two, .three],
                         blanks: [Square] = Square.all, target: Int = 100_000) -> RunState {
        let solution = (0..<81).map { Digit(rawValue: (($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9) + 1)! }
        let blankSet = Set(blanks)
        let board = Board(GeneratedPuzzle(solution: solution, isGiven: Square.all.map { !blankSet.contains($0) }))
        var pool = Pool(blanksOf: board)
        for digit in hand { XCTAssertTrue(pool.take(digit)) }
        var run = RunState(seed: "independent-boss-roster-review", book: .probably)
        run.level = boss.isFinalBoss ? 9 : 3; run.slot = .boss; run.pendingBoss = nil
        var puzzle = PuzzleState(level: run.level, slot: .boss, difficulty: .boss,
            board: board, pool: pool, hand: hand, handSize: hand.count, turnNumber: 1,
            turnsMax: boss == .lastEdition ? 1 : 10, tossedThisPuzzle: 0,
            tossAllowance: 4, score: 0, target: target, cluesRemaining: 2,
            boss: boss, censoredDigit: nil, blockedDigit: nil, bossTurn: nil,
            phase: .playing, keepFillingCoins: 0)
        puzzle.ensureHandIdentities(seed: run.seed)
        BossRuntime.puzzleStarted(run: run, puzzle: &puzzle)
        puzzle.startBossTurn(&run)
        run.puzzle = puzzle
        return run
    }

    private func conservation(_ run: RunState, file: StaticString = #filePath, line: UInt = #line) {
        guard let p = run.puzzle else { return XCTFail("Missing puzzle", file: file, line: line) }
        let reserve = p.bossState.encounter.pledgedCard.map { [$0.digit] } ?? []
        XCTAssertNil(Conservation.check(board: p.board, pool: p.pool,
            hand: p.hand + p.markerState.reservedForkCards + reserve), file: file, line: line)
        XCTAssertEqual(p.hand.count, p.handCardIDs.count, file: file, line: line)
        XCTAssertEqual(Set(p.handCardIDs).count, p.hand.count, file: file, line: line)
        if let card = p.bossState.encounter.pledgedCard {
            XCTAssertFalse(p.handCardIDs.contains(card.id), file: file, line: line)
        }
    }

    func testExactlyTwentyTwoNewEncountersAndUniqueBookAnnouncements() throws {
        XCTAssertEqual(Set(BossModifier.regularBosses), regular)
        XCTAssertEqual(Set(BossModifier.finalBosses), finals)
        XCTAssertEqual(regular.union(finals).count, 22)
        for seed in 0..<12 {
            var run = RunState(seed: "roster-unique-\(seed)")
            XCTAssertEqual(run.bossRosterVersion, 2)
            var seen: [BossModifier] = []
            repeat {
                guard run.slot == .easy else { continue }
                let announced = try XCTUnwrap(run.pendingBoss)
                XCTAssertTrue((run.level == 9 ? finals : regular).contains(announced))
                XCTAssertFalse(seen.contains(announced), "Chapter \(run.level) repeats \(announced)")
                seen.append(announced)
                let streams = run.streams
                let restored = try JSONDecoder().decode(RunState.self, from: data(run))
                XCTAssertEqual(restored.pendingBoss, announced)
                XCTAssertEqual(try data(restored.streams), try data(streams))
                XCTAssertEqual(restored.bossEncounterHistory, run.bossEncounterHistory)
            } while run.advance()
            XCTAssertEqual(seen.count, 9)
        }
    }

    func testEveryHistoricalActiveBossRetainsItsIdentityAndStateWhenNewFieldsAreAbsent() throws {
        let old = BossModifier.allCases.filter { ![.collateral, .splitEdition, .lastEdition].contains($0) }
        XCTAssertEqual(old.count, 39)
        for boss in old {
            let run = fixture(boss)
            var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data(run)) as? [String: Any])
            json.removeValue(forKey: "bossRosterVersion"); json.removeValue(forKey: "bossEncounterHistory")
            var puzzleJSON = try XCTUnwrap(json["puzzle"] as? [String: Any])
            var bossJSON = try XCTUnwrap(puzzleJSON["bossState"] as? [String: Any])
            bossJSON.removeValue(forKey: "encounter")
            puzzleJSON["bossState"] = bossJSON; json["puzzle"] = puzzleJSON
            let legacy = try JSONSerialization.data(withJSONObject: json, options: .sortedKeys)
            let restored = try JSONDecoder().decode(RunState.self, from: legacy)
            XCTAssertEqual(restored.bossRosterVersion, 1)
            XCTAssertEqual(restored.puzzle?.boss, boss)
            var beforePuzzle = run.puzzle!, afterPuzzle = restored.puzzle!
            XCTAssertEqual(afterPuzzle.bossTurn?.fouled, beforePuzzle.bossTurn?.fouled)
            XCTAssertEqual(afterPuzzle.bossTurn?.greyed, beforePuzzle.bossTurn?.greyed)
            XCTAssertEqual(afterPuzzle.bossTurn?.blockedDigits, beforePuzzle.bossTurn?.blockedDigits)
            XCTAssertEqual(afterPuzzle.bossTurn?.blockedHandIndices, beforePuzzle.bossTurn?.blockedHandIndices)
            XCTAssertEqual(afterPuzzle.bossTurn?.disabledBookmark, beforePuzzle.bossTurn?.disabledBookmark)
            // The original legacy BossTurn container encodes Sets/dictionary
            // keys in arbitrary order; compare those values semantically.
            beforePuzzle.bossTurn = nil; afterPuzzle.bossTurn = nil
            XCTAssertEqual(try data(afterPuzzle), try data(beforePuzzle), boss.rawValue)
            XCTAssertEqual(try data(restored.streams), try data(run.streams), boss.rawValue)
            let again = try JSONDecoder().decode(RunState.self, from: data(restored))
            var once = restored, twice = again
            once.puzzle?.bossTurn = nil; twice.puzzle?.bossTurn = nil
            XCTAssertEqual(try data(twice), try data(once))
        }
    }

    func testPledgeReservesOnlyOneDuplicateCopyAndReturnsItOnceAfterSaveAndBank() throws {
        var run = fixture(.collateral)
        let first = try XCTUnwrap(run.puzzle?.handCards.first)
        let otherCopy = run.puzzle!.handCards[1]
        XCTAssertEqual(first.digit, otherCopy.digit)
        XCTAssertTrue(Actions.pledgeBossCard(&run, cardID: first.id))
        XCTAssertEqual(run.puzzle?.bossState.encounter.pledgedCard, first)
        XCTAssertTrue(run.puzzle!.handCardIDs.contains(otherCopy.id))
        conservation(run)
        let pledged = try data(run)
        XCTAssertFalse(Actions.pledgeBossCard(&run, cardID: otherCopy.id))
        XCTAssertFalse(Actions.pledgeBossCard(&run, cardID: UUID()))
        XCTAssertEqual(try data(run), pledged)
        run = try JSONDecoder().decode(RunState.self, from: pledged)
        _ = try Actions.place(&run, handIndex: run.puzzle!.handCardIDs.firstIndex(of: otherCopy.id)!, square: Square(0))
        XCTAssertNil(run.puzzle!.handCardIDs.firstIndex(of: otherCopy.id))
        _ = try Actions.endTurn(&run)
        XCTAssertNil(run.puzzle?.bossState.encounter.pledgedCard)
        XCTAssertEqual(run.puzzle!.handCardIDs.filter { $0 == first.id }.count, 1)
        conservation(run)
    }

    func testPledgePreviewIsPureAndItsMultRunsBeforeBookmarkOperators() throws {
        var run = fixture(.collateral)
        run.bookmarks = [Bookmarks.opEd, Bookmarks.theSundaySupplement].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: Catalog.item($0)!.listedPrice)
        }
        let card = run.puzzle!.handCards[0]
        XCTAssertTrue(Actions.pledgeBossCard(&run, cardID: card.id))
        _ = try Actions.place(&run, handIndex: run.puzzle!.hand.firstIndex(of: .one)!, square: Square(0))
        let before = try data(run)
        let ledger = run.puzzle!.pendingScoringLedger
        XCTAssertEqual(ledger.multiplier, 12, "(1 + pledge2 + OpEd1) × Sunday3")
        XCTAssertEqual(ledger.total, 120)
        for _ in 0..<10 { XCTAssertEqual(run.puzzle!.pendingScoringLedger, ledger) }
        XCTAssertEqual(try data(run), before)
        let bank = try Actions.endTurn(&run)
        XCTAssertEqual(bank.pointsGained, ledger.total)
        conservation(run)
    }

    func testRedrawCannotLoseOrDuplicateThePledgedToken() throws {
        var game = Game(run: fixture(.collateral))
        let pledged = game.puzzle!.handCards[0]
        XCTAssertTrue(Actions.pledgeBossCard(&game.run, cardID: pledged.id))
        let buff = OwnedBuff(defID: Buffs.redraw, pricePaid: 3)
        game.run.buffs = [buff]
        _ = try game.beginBuff(id: buff.id)
        XCTAssertEqual(game.puzzle?.bossState.encounter.pledgedCard, pledged)
        XCTAssertLessThanOrEqual(game.puzzle!.hand.count + 1, game.puzzle!.handSize)
        conservation(game.run)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle!.handCardIDs.filter { $0 == pledged.id }.count, 1)
        conservation(game.run)
    }

    func testAcceptedActionLocksBossChoicesButInvalidActionDoesNot() throws {
        for boss in [BossModifier.collateral, .splitEdition] {
            var run = fixture(boss)
            let before = try data(run)
            XCTAssertThrowsError(try Actions.place(&run, handIndex: -1, square: Square(0)))
            XCTAssertEqual(try data(run), before)
            if boss == .splitEdition {
                XCTAssertFalse(Actions.chooseBossEdition(&run, edition: -1))
                XCTAssertFalse(Actions.chooseBossEdition(&run, edition: 2))
                XCTAssertEqual(try data(run), before)
                XCTAssertTrue(Actions.chooseBossEdition(&run, edition: 1))
            }
            _ = try Actions.toss(&run, handIndex: 0)
            let locked = try data(run)
            if boss == .collateral {
                XCTAssertFalse(Actions.pledgeBossCard(&run, cardID: run.puzzle!.handCardIDs[0]))
            } else {
                XCTAssertFalse(Actions.chooseBossEdition(&run, edition: 0))
            }
            XCTAssertEqual(try data(run), locked)
            conservation(run)
        }
    }

    func testSplitRoutesDirectAwardsAndOrdinaryBanksToTheChosenEdition() throws {
        var run = fixture(.splitEdition, target: 101)
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.morningEdition, boughtAtLevel: 1, pricePaid: 4)]
        XCTAssertEqual(run.puzzle?.bossState.encounter.editionTargets.reduce(0, +), 101)
        _ = try Actions.place(&run, handIndex: 0, square: Square(0))
        let first = try Actions.endTurn(&run)
        XCTAssertEqual(first.pointsGained, 110)
        XCTAssertEqual(run.puzzle?.bossState.encounter.editionScores, [110, 0])
        XCTAssertFalse(BossEncounterRules.targetSatisfied(puzzle: run.puzzle!))
        XCTAssertEqual(run.puzzle?.phase, .playing, "One overfunded edition is not victory")
        XCTAssertTrue(Actions.chooseBossEdition(&run, edition: 1))
        _ = try Actions.place(&run, handIndex: run.puzzle!.hand.firstIndex(of: .two)!, square: Square(1))
        _ = try Actions.endTurn(&run)
        XCTAssertEqual(run.puzzle?.bossState.encounter.editionScores, [110, 120])
        XCTAssertTrue(BossEncounterRules.targetSatisfied(puzzle: run.puzzle!))
        XCTAssertEqual(run.puzzle?.phase, .won)
        conservation(run)
    }

    func testFullClearCannotBypassAnUnfundedEdition() throws {
        var run = fixture(.splitEdition, hand: [.one], blanks: [Square(0)], target: 2)
        _ = try Actions.place(&run, handIndex: 0, square: Square(0))
        XCTAssertTrue(run.puzzle!.board.isFull)
        XCTAssertGreaterThan(run.puzzle!.score, run.puzzle!.target)
        XCTAssertEqual(run.puzzle!.bossState.encounter.editionScores[1], 0)
        XCTAssertEqual(run.puzzle?.phase, .failed)
        XCTAssertFalse(Actions.canClaimRewardedRescue(run))
        conservation(run)
    }

    func testLastEditionCannotAddBanksThroughOvertimeRescueOrKeepFilling() throws {
        var game = Game(run: fixture(.lastEdition))
        let overtime = OwnedBuff(defID: Buffs.overtime, pricePaid: 7)
        game.run.buffs = [overtime]
        XCTAssertFalse(BuffRuntime.canUse(buffID: overtime.id, run: game.run))
        let before = try data(game.run)
        XCTAssertThrowsError(try game.beginBuff(id: overtime.id))
        XCTAssertEqual(try data(game.run), before)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.bossState.encounter.banksUsed, 1)
        XCTAssertEqual(game.puzzle?.phase, .failed)
        XCTAssertFalse(Actions.canClaimRewardedRescue(game.run))
        XCTAssertFalse(Actions.claimRewardedRescue(&game.run))
        XCTAssertThrowsError(try game.keepFilling())
        XCTAssertThrowsError(try game.endTurn())
        XCTAssertEqual(game.puzzle?.bossState.encounter.banksUsed, 1)
        conservation(game.run)
    }

    func testLastEditionAutomaticEmptyHandBankCanWinButNeverResume() throws {
        var game = Game(run: fixture(.lastEdition, hand: [.one], target: 10))
        let placement = try game.place(handIndex: 0, at: Square(0))
        XCTAssertEqual(placement.automaticTurn?.pointsGained, 10)
        XCTAssertEqual(game.puzzle?.bossState.encounter.banksUsed, 1)
        XCTAssertEqual(game.puzzle?.phase, .won)
        XCTAssertThrowsError(try game.keepFilling())
        let resumed = try Game(decoding: game.encoded())
        XCTAssertEqual(resumed.puzzle?.phase, .won)
        XCTAssertEqual(resumed.puzzle?.bossState.encounter.banksUsed, 1)
        conservation(resumed.run)
    }

    private struct ProbeBuild {
        let name: String
        let bookmarks: [String]
        let priorSyndicationWins: Int
        let numberIndexMult: Int
        let withMarkersAndBuffs: Bool
    }
    private struct ProbeRow: Codable {
        let boss: String
        let seed: String
        let build: String
        let listedLoadoutCost: Int
        let priorSyndicationWins: Int
        let numberIndexMult: Int
        let openingHand: Int
        let target: Int
        let score: Int
        let phase: String
        let banks: Int
        let placements: Int
        let blanksRemaining: Int
        let editionScores: [Int]
        let editionTargets: [Int]
    }

    func testSixFinalBossesWithFiniteWeakDevelopedAndStrongLoadouts() throws {
        let builds = [
            ProbeBuild(name: "Three-slot basic", bookmarks: [Bookmarks.localGossip, Bookmarks.opEd,
                Bookmarks.theSundaySupplement], priorSyndicationWins: 0, numberIndexMult: 0, withMarkersAndBuffs: false),
            ProbeBuild(name: "Five-slot developed", bookmarks: [Bookmarks.frontPageSplash, Bookmarks.rollingPresses,
                Bookmarks.syndication, Bookmarks.localGossip, Bookmarks.theSundaySupplement],
                priorSyndicationWins: 12, numberIndexMult: 0, withMarkersAndBuffs: true),
            ProbeBuild(name: "Five-slot clear engine", bookmarks: [Bookmarks.frontPageSplash, Bookmarks.rollingPresses,
                Bookmarks.syndication, Bookmarks.extraExtra, Bookmarks.theSundaySupplement],
                priorSyndicationWins: 18, numberIndexMult: 0, withMarkersAndBuffs: true),
            ProbeBuild(name: "Five-slot number collection", bookmarks: [Bookmarks.frontPageSplash, Bookmarks.numberIndex,
                Bookmarks.theSundaySupplement, Bookmarks.theSundaySupplement, Bookmarks.rollingPresses],
                priorSyndicationWins: 0, numberIndexMult: 10, withMarkersAndBuffs: true)
        ]
        var rows: [ProbeRow] = []
        for boss in finals.sorted(by: { $0.rawValue < $1.rawValue }) {
            for seedIndex in 0..<3 {
                for build in builds {
                    let seed = "finite-final-roster-\(seedIndex)"
                    var game = Game(seed: seed, book: .probably)
                    game.run.level = 9; game.run.slot = .boss; game.run.pendingBoss = boss
                    game.run.bookmarks = build.bookmarks.enumerated().map { index, definition in
                        OwnedBookmark(defID: definition, boughtAtLevel: 3,
                            pricePaid: Catalog.item(definition)!.listedPrice,
                            id: SkipOffer.stableIdentity(seed: seed, domain: "review.bookmark.\(index)"))
                    }
                    if build.priorSyndicationWins > 0 {
                        game.run.runItemState[Bookmarks.syndication] = Double(build.priorSyndicationWins)
                    }
                    if let index = game.run.bookmarks.first(where: { $0.defID == Bookmarks.numberIndex }) {
                        game.run.bookmarkState.copies[index.id] = .init()
                        game.run.bookmarkState.copies[index.id]?.numberIndexMult = build.numberIndexMult
                    }
                    try game.startPuzzle()
                    XCTAssertEqual(game.puzzle?.boss, boss)
                    let openingHand = game.puzzle!.hand.count
                    XCTAssertEqual(openingHand, boss == .lastEdition ? 11 : 7)
                    let markerIDs = [Markers.crimson, Markers.golden]
                    let buffIDs = [Buffs.freshInk, Buffs.luckyDip]
                    if build.withMarkersAndBuffs {
                        let publicBlanks = Array(game.puzzle!.board.blanks.prefix(6))
                        game.run.markers = markerIDs.enumerated().map { index, definition in
                            OwnedMarker(defID: definition, boughtAtLevel: 3,
                                pricePaid: Catalog.item(definition)!.listedPrice,
                                squares: Array(publicBlanks[(index * 3)..<(index * 3 + 3)]))
                        }
                        MarkerRuntime.synchronizeOwnership(run: &game.run)
                        game.run.buffs = buffIDs.enumerated().map { index, definition in
                            OwnedBuff(defID: definition, pricePaid: Catalog.item(definition)!.listedPrice,
                                id: SkipOffer.stableIdentity(seed: seed, domain: "review.buff.\(index)"))
                        }
                        for source in game.run.buffs {
                            XCTAssertTrue(BuffRuntime.canUse(buffID: source.id, run: game.run))
                            _ = try game.beginBuff(id: source.id)
                        }
                    }
                    var placements = 0
                    var bankTurns = Set<Int>()
                    for actionIndex in 0..<200 {
                        guard let p = game.puzzle, p.phase == .playing else { break }
                        if BossEncounterRules.canChooseEdition(run: game.run) {
                            let targets = BossEncounterRules.editionTargets(puzzle: p)
                            let remaining = (0..<2).map { max(0, targets[$0] - p.bossState.encounter.editionScores[$0]) }
                            _ = game.chooseBossEdition(remaining[0] >= remaining[1] ? 0 : 1)
                        }
                        let current = game.puzzle!
                        let edition = current.bossState.encounter.selectedEdition
                        let targetForEdition = BossEncounterRules.editionTargets(puzzle: current)[edition]
                        if boss == .splitEdition, current.pendingScore > 0,
                           current.bossState.encounter.editionScores[edition] + current.pendingScore >= targetForEdition,
                           current.bossState.encounter.editionScores[1 - edition] < BossEncounterRules.editionTargets(puzzle: current)[1 - edition] {
                            _ = try game.endTurn()
                        } else {
                            var choices: [(Int, Square, Int)] = []
                            for handIndex in current.hand.indices where !current.isBlocked(handIndex: handIndex) {
                                for square in current.board.blanks where !current.isBarred(square)
                                    && current.board.correctDigit(at: square) == current.hand[handIndex] {
                                    let nearestClear = [ProbablySudokuEngine.Unit.row, .col, .box].map { unit in
                                        Geometry.cells(of: unit, through: square).filter { current.board.isBlank($0) }.count
                                    }.min() ?? 9
                                    choices.append((handIndex, square, nearestClear))
                                }
                            }
                            let next = choices.sorted {
                                if $0.2 != $1.2 { return $0.2 < $1.2 }
                                if $0.1.index != $1.1.index { return $0.1.index < $1.1.index }
                                return $0.0 < $1.0
                            }.first
                            if let next {
                                XCTAssertTrue(try game.place(handIndex: next.0, at: next.1).correct)
                                placements += 1
                            } else { _ = try game.endTurn() }
                        }
                        conservation(game.run)
                        if let receipt = game.puzzle?.lastScoringLedger { bankTurns.insert(receipt.turnNumber) }
                        if actionIndex.isMultiple(of: 7) {
                            game = try Game(decoding: game.encoded())
                            conservation(game.run)
                        }
                    }
                    let end = try XCTUnwrap(game.puzzle)
                    XCTAssertNotEqual(end.phase, .playing, "Finite action budget must reach a result")
                    XCTAssertLessThanOrEqual(placements, 52)
                    XCTAssertLessThanOrEqual(bankTurns.count, end.turnsMax)
                    if end.phase == .won { XCTAssertTrue(BossEncounterRules.targetSatisfied(puzzle: end)) }
                    if boss == .lastEdition { XCTAssertEqual(bankTurns.count, 1) }
                    let itemCost = build.bookmarks.reduce(0) { $0 + Catalog.item($1)!.listedPrice }
                        + (build.withMarkersAndBuffs ? (markerIDs + buffIDs).reduce(0) { $0 + Catalog.item($1)!.listedPrice } : 0)
                    let row = ProbeRow(boss: boss.rawValue, seed: seed, build: build.name,
                        listedLoadoutCost: itemCost, priorSyndicationWins: build.priorSyndicationWins,
                        numberIndexMult: build.numberIndexMult,
                        openingHand: openingHand, target: end.target, score: end.score,
                        phase: end.phase.rawValue, banks: bankTurns.count, placements: placements,
                        blanksRemaining: end.board.blanks.count,
                        editionScores: end.bossState.encounter.editionScores,
                        editionTargets: end.bossState.encounter.editionTargets)
                    rows.append(row)
                    print("BOSS_ROSTER_FINAL_PROBE \(String(decoding: try data(row), as: UTF8.self))")
                }
            }
        }
        XCTAssertEqual(rows.count, 72)
        if let path = ProcessInfo.processInfo.environment["BOSS_ROSTER_FINAL_REPORT"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rows).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
