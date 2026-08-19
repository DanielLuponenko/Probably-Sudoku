import XCTest
@testable import NumberClubEngine

final class PRNGTests: XCTestCase {

    // Locked against values produced by the TypeScript prototype's cyrb128 +
    // mulberry32. If these drift, every published seed changes meaning.
    private let seed = "number-club-test"

    func testCyrb128MatchesReference() {
        let (a, b, c, d) = cyrb128(seed)
        XCTAssertEqual(a, 3361352897)
        XCTAssertEqual(b, 3925422588)
        XCTAssertEqual(c, 2716402931)
        XCTAssertEqual(d, 2152339918)
    }

    func testStreamSeedsMatchReference() {
        XCTAssertEqual(RandomStream(seed: seed, stream: "board").state, 861239761)
        XCTAssertEqual(RandomStream(seed: seed, stream: "pool").state,  4141143920)
        XCTAssertEqual(RandomStream(seed: seed, stream: "shop").state,  3358561365)
        XCTAssertEqual(RandomStream(seed: seed, stream: "boss").state,  673546453)
    }

    func testStreamValuesMatchReference() {
        let expected: [String: [Double]] = [
            "board": [0.40395039343275130, 0.92833412042818964, 0.67895875242538750,
                      0.88665850157849491, 0.85213772207498550],
            "pool":  [0.50729149510152638, 0.75193507340736687, 0.21636118809692562,
                      0.38237156858667731, 0.33373834821395576],
            "shop":  [0.14792711543850601, 0.82543048262596130, 0.56609974824823439,
                      0.25741942366585135, 0.72063527978025377],
            "boss":  [0.12459954852238297, 0.66850947192870080, 0.11597253917716444,
                      0.58947833511047065, 0.28347011236473918],
        ]
        for (name, values) in expected {
            var rng = RandomStream(seed: seed, stream: name)
            for (i, want) in values.enumerated() {
                XCTAssertEqual(rng.next(), want, accuracy: 1e-15, "\(name)[\(i)]")
            }
        }
    }

    func testStreamsAreIndependent() {
        // Drawing numbers must never shift which Boss Modifier appears (§15).
        var streams = SeedStreams(seed: seed)
        let bossBefore = streams.boss
        for _ in 0..<500 { _ = streams.pool.next() }
        XCTAssertEqual(streams.boss.state, bossBefore.state)
    }

    func testStateRestoreReproducesSequence() {
        var rng = RandomStream(seed: seed, stream: "pool")
        for _ in 0..<17 { _ = rng.next() }
        let snapshot = rng.state
        let expected = (0..<10).map { _ in rng.next() }

        var restored = RandomStream(state: snapshot)
        let actual = (0..<10).map { _ in restored.next() }
        XCTAssertEqual(expected, actual)
    }

    func testIntIsInRangeAndUniformEnough() {
        var rng = RandomStream(seed: seed, stream: "shop")
        var buckets = [Int](repeating: 0, count: 9)
        for _ in 0..<90_000 { buckets[rng.int(9)] += 1 }
        XCTAssertEqual(buckets.reduce(0, +), 90_000)
        for b in buckets { XCTAssertTrue((9_000...11_000).contains(b), "bucket skew: \(buckets)") }
    }

    func testShuffleIsAPermutation() {
        var rng = RandomStream(seed: seed, stream: "board")
        let source = Array(0..<81)
        let shuffled = rng.shuffled(source)
        XCTAssertNotEqual(shuffled, source)
        XCTAssertEqual(shuffled.sorted(), source)
    }
}
