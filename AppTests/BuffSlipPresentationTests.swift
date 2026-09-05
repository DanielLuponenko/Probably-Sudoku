import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BuffSlipPresentationTests: XCTestCase {
    func testConsumedBuffKeepsItsPrintedMetadataOnTheOutgoingSlip() throws {
        for hasNextBuff in [false, true] {
            var game = Game(seed: "buff-slip-dismissal")
            try game.startPuzzle()
            var run = game.run
            run.buffs = [OwnedBuff(defID: "bf_insurance", pricePaid: 3)]
            if hasNextBuff { run.buffs.append(OwnedBuff(defID: Buffs.freshInk, pricePaid: 4)) }
            let model = GameModel(frozen: Game(run: run), page: .puzzle)
            // This same value is retained by SwiftUI during its removal
            // transition, while the observed inventory has already changed.
            let slip = BuffSlip(model: model, index: 0, onDone: {})
            let before = try render(slip)
            XCTAssertTrue(try text(in: before).contains("insurance"))

            XCTAssertTrue(model.useBuff(at: 0)) // In-memory frozen game; no save/profile writes.
            XCTAssertEqual(model.run.buffs.count, hasNextBuff ? 1 : 0)
            let outgoing = try render(slip)
            let printed = try text(in: outgoing)
            XCTAssertTrue(printed.contains("insurance"), "The consumed slip must not become a generic Buff")
            XCTAssertTrue(printed.contains("yournextwrongplacementtakesnopenalty"))
            XCTAssertFalse(printed.contains("freshink"), "The next inventory slot must not replace the outgoing slip")
            let attachment = XCTAttachment(image: outgoing)
            attachment.name = "consumed-buff-slip-next-item-\(hasNextBuff)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func render(_ slip: BuffSlip) throws -> UIImage {
        let renderer = ImageRenderer(content: slip
            .frame(width: 375, height: 667)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US")))
        renderer.scale = 2
        return try XCTUnwrap(renderer.uiImage)
    }

    private func text(in image: UIImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            .joined().lowercased().filter { $0.isLetter || $0.isNumber }
    }
}
