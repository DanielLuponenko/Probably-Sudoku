import Foundation
import XCTest
@testable import NumberClubEngine

final class GenerateReference: XCTestCase {
    func testGeneratedReferenceMatchesCheckedInDocument() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let output = root.appendingPathComponent("REFERENCE.md")
        let rendered = ReferenceDocument.render()

        if ProcessInfo.processInfo.environment["WRITE_REFERENCE"] == "1" {
            try rendered.write(to: output, atomically: true, encoding: .utf8)
        }

        XCTAssertEqual(try String(contentsOf: output, encoding: .utf8), rendered,
                       "Regenerate with WRITE_REFERENCE=1 swift test --filter GenerateReference")
    }
}
