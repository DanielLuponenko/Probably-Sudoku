import Foundation
import NumberClubEngine

// A soak test, not an AI. The bot cheats — it reads the solution — because the
// point is to exercise every code path in the engine across whole Books and
// prove the conservation rule never breaks, not to play well.

struct Report {
    var puzzlesPlayed = 0
    var puzzlesWon = 0
    var booksCompleted = 0
    var booksFailed = 0
    var lineClears = 0
    var fullClears = 0
    var itemsBought = 0
    var conservationBreaks: [String] = []
    var errors: [String] = []
    var highestLevel = 0
    var itemsSeen = Set<String>()
    var bossesSeen = Set<BossModifier>()
    /// level -> (best score reached, target, attempts, wins)
    var byLevel: [Int: (best: Int, target: Int, attempts: Int, wins: Int)] = [:]

    mutating func record(level: Int, score: Int, target: Int, won: Bool) {
        var entry = byLevel[level] ?? (best: 0, target: target, attempts: 0, wins: 0)
        entry.best = max(entry.best, score)
        entry.target = max(entry.target, target)
        entry.attempts += 1
        if won { entry.wins += 1 }
        byLevel[level] = entry
    }
}

func checkConservation(_ game: Game, _ where_: String, _ report: inout Report) {
    guard let puzzle = game.puzzle else { return }
    if let problem = Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand) {
        report.conservationBreaks.append("\(where_): \(problem)")
    }
}

func playPuzzle(_ game: inout Game, _ report: inout Report, _ rng: inout RandomStream) {
    report.puzzlesPlayed += 1
    if let boss = game.puzzle?.boss { report.bossesSeen.insert(boss) }

    while let puzzle = game.puzzle, puzzle.phase == .playing || puzzle.phase == .keepFilling {
        var placedThisTurn = false

        // Spend a Buff now and then, to exercise them.
        if !game.run.buffs.isEmpty && rng.next() < 0.3 {
            let digit = Digit.all[rng.int(9)]
            _ = try? game.useBuff(at: 0, digit: digit)
            checkConservation(game, "after buff", &report)
        }

        // Place whatever in Hand has a home, preferring marked squares.
        var guard_ = 0
        while let puzzle = game.puzzle, guard_ < 100 {
            guard_ += 1
            guard puzzle.phase == .playing || puzzle.phase == .keepFilling else { break }
            let marked = Set(game.run.markedSquares.keys)
            var choice: (Int, Square)?
            for (index, digit) in puzzle.hand.enumerated() {
                let homes = puzzle.board.blanks.filter { puzzle.board.correctDigit(at: $0) == digit }
                if let onMark = homes.first(where: { marked.contains($0) }) {
                    choice = (index, onMark); break
                }
                if choice == nil, let any = homes.first { choice = (index, any) }
            }
            guard let (index, square) = choice else { break }
            do {
                let outcome = try game.place(handIndex: index, at: square)
                report.lineClears += outcome.lineClears.count
                if outcome.fullClear { report.fullClears += 1 }
                placedThisTurn = true
            } catch {
                report.errors.append("place: \(error)")
                break
            }
            checkConservation(game, "after place", &report)
        }

        // Target met: cash out most of the time, but sometimes push the greed
        // mechanic so Keep Filling gets exercised too.
        if game.puzzle?.phase == .won {
            if rng.next() < 0.3, (game.puzzle?.turnsRemaining ?? 0) > 2 {
                try? game.keepFilling()
                continue
            }
            break
        }

        if !placedThisTurn, let puzzle = game.puzzle, puzzle.tossesRemaining > 0, !puzzle.hand.isEmpty {
            // One at a time now, and the allowance is for the whole Puzzle.
            _ = try? game.toss(handIndex: 0)
            checkConservation(game, "after toss", &report)
        }

        if let puzzle = game.puzzle, puzzle.canUseClue, rng.next() < 0.5,
           let square = puzzle.board.blanks.first {
            _ = try? game.useClue(at: square)
            checkConservation(game, "after clue", &report)
        }

        guard game.puzzle?.phase == .playing || game.puzzle?.phase == .keepFilling else { break }
        do {
            let turn = try game.endTurn()
            checkConservation(game, "after end turn", &report)
            if turn.puzzleFailed { return }
        } catch {
            report.errors.append("endTurn: \(error)")
            return
        }
    }

    if let puzzle = game.puzzle {
        let won = puzzle.phase == .won || puzzle.phase == .keepFilling
        report.record(level: puzzle.level, score: puzzle.score, target: puzzle.target, won: won)
        if won {
            report.puzzlesWon += 1
            _ = try? game.cashOut()
        }
    }
}

func shop(_ game: inout Game, _ report: inout Report, _ rng: inout RandomStream) {
    game.openShop()
    guard let offers = game.shop?.offers else { return }
    for offer in offers { report.itemsSeen.insert(offer.defID) }

    if rng.next() < 0.3, let cost = game.shop?.rerollCost, game.run.coins >= cost {
        try? game.reroll()
    }

    for offer in game.shop?.offers ?? [] where !offer.sold {
        if game.run.coins >= offer.price {
            do { try game.buy(slot: offer.slot); report.itemsBought += 1 }
            catch Shop.ShopError.slotsFull { continue }
            catch { report.errors.append("buy: \(error)") }
        }
    }

    // Claim every Marker square the Levels have earned.
    for (index, marker) in game.run.markers.enumerated() {
        var pending = marker.pendingSquares(atLevel: game.run.level)
        var attempts = 0
        while pending > 0 && attempts < 200 {
            attempts += 1
            let square = Square(rng.int(81))
            if (try? game.claimSquare(markerIndex: index, square: square)) != nil { pending -= 1 }
        }
    }
}

func playBook(seed: String, board: StartingBoard, _ report: inout Report) {
    var game = Game(seed: seed, startingBoard: board)
    var rng = RandomStream(seed: seed, stream: "bot")

    while game.run.outcome == nil {
        do { try game.startPuzzle() }
        catch { report.errors.append("startPuzzle: \(error)"); return }

        report.highestLevel = max(report.highestLevel, game.run.level)
        playPuzzle(&game, &report, &rng)

        if game.run.outcome == .failed { report.booksFailed += 1; return }
        if game.puzzle?.phase == .failed { report.booksFailed += 1; return }

        shop(&game, &report, &rng)
        if !game.advance() { report.booksCompleted += 1; return }
    }
}

// MARK: - Run

let bookCount = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 40 : 40
var report = Report()
let started = DispatchTime.now().uptimeNanoseconds

for i in 0..<bookCount {
    let board = StartingBoard.allCases[i % 3]
    playBook(seed: "soak-\(i)", board: board, &report)
}

let elapsed = Double(DispatchTime.now().uptimeNanoseconds - started) / 1e9

print("""

Books           \(bookCount)  (\(report.booksCompleted) completed, \(report.booksFailed) failed)
Puzzles         \(report.puzzlesPlayed) played, \(report.puzzlesWon) won
Deepest Level   \(report.highestLevel)
Line Clears     \(report.lineClears)   Full Clears \(report.fullClears)
Items bought    \(report.itemsBought)
Catalogue seen  \(report.itemsSeen.count)/\(Catalog.all.count) items, \(report.bossesSeen.count)/9 Boss Modifiers
Elapsed         \(String(format: "%.2f", elapsed))s

Conservation breaks  \(report.conservationBreaks.count)
Errors               \(report.errors.count)
""")

for problem in report.conservationBreaks.prefix(5) { print("  BREAK  \(problem)") }
let grouped = Dictionary(grouping: report.errors, by: { $0 }).mapValues(\.count)
for (message, count) in grouped.sorted(by: { $0.value > $1.value }).prefix(6) {
    print("  ERROR  x\(count)  \(message)")
}

print("\nLevel   attempts   won   best score   target   headroom")
for level in report.byLevel.keys.sorted() {
    let e = report.byLevel[level]!
    let headroom = e.target > 0 ? Double(e.best) / Double(e.target) : 0
    print(String(format: "  %d %10d %5d %12d %8d   %5.2fx",
                 level, e.attempts, e.wins, e.best, e.target, headroom))
}

let unseen = Set(Catalog.all.map(\.id)).subtracting(report.itemsSeen)
if !unseen.isEmpty { print("  never offered: \(unseen.sorted().joined(separator: ", "))") }

exit(report.conservationBreaks.isEmpty && report.errors.isEmpty ? 0 : 1)
