import Foundation
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

final class CloudRunTransportTests: XCTestCase {
    func testExistingCloudEnvelopeReturnsOriginalGameJSONNotAnotherBase64Decode() throws {
        var game = Game(seed: "cloud-rescue", book: .smallVictories, obstacle: .shortHanded)
        try game.startPuzzle()
        while game.puzzle?.phase == .playing { _ = try game.endTurn() }
        for earned in [false, true] {
            if earned { XCTAssertTrue(game.claimRewardedRescue()) }
            let original = try game.encoded()
            let restoredBytes = try XCTUnwrap(CloudSync.runData(fromEnvelope: envelope(original)))
            XCTAssertEqual(restoredBytes, original)
            let restored = try XCTUnwrap(RunStore.game(from: restoredBytes))
            XCTAssertEqual(restored.run.book, .smallVictories)
            XCTAssertEqual(restored.run.obstacle, .shortHanded)
            XCTAssertEqual(restored.puzzle?.rewardedRescueUsed, earned)
            XCTAssertEqual(restored.puzzle?.turnsRemaining, earned ? 3 : 0)
        }
    }

    func testUnknownSchemaAndMalformedEnvelopeFailClosedWithoutInventingARun() throws {
        let bytes = try Game(seed: "valid-cloud-payload").encoded()
        XCTAssertNil(CloudSync.runData(fromEnvelope: nil))
        XCTAssertNil(CloudSync.runData(fromEnvelope: Data("broken".utf8)))
        XCTAssertNil(CloudSync.runData(fromEnvelope: try envelope(bytes, schema: 2)))
        XCTAssertNil(RunStore.game(from: CloudSync.runData(
            fromEnvelope: try envelope(Data("not a game".utf8)))))
    }

    private func envelope(_ payload: Data, schema: Int = 1) throws -> Data {
        // This is the existing schema-1 format written by CloudSync: Data
        // becomes a base64 string once in the envelope, not twice.
        try JSONSerialization.data(withJSONObject: [
            "schema": schema, "modifiedAt": 0, "payload": payload.base64EncodedString()
        ])
    }
}
