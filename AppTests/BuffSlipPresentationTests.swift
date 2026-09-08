import XCTest
import SwiftUI
import UIKit
import Vision
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BuffSlipPresentationTests: XCTestCase {
    func testPaperSlipLongContentUsesAWorkingScrollContainer() async throws {
        let content = VStack(alignment: .leading, spacing: 14) {
            ForEach(1...24, id: \.self) { index in
                Text("Long paragraph \(index): this deliberately verbose copy verifies that a paper slip can scroll without losing its final decision.")
                    .font(Print.body(15))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Final paragraph remains reachable.")
                .font(Print.body(15))
                .fixedSize(horizontal: false, vertical: true)
        }
        let host = UIHostingController(rootView: PaperSlip(title: "Long article", subtitle: nil,
                                                            maximumHeight: 420, onClose: {}) {
            content
        }.environment(\.dynamicTypeSize, .accessibility5))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        let laidOut = expectation(description: "Paper slip laid out")
        DispatchQueue.main.async {
            window.layoutIfNeeded()
            host.view.layoutIfNeeded()
            DispatchQueue.main.async { laidOut.fulfill() }
        }
        await fulfillment(of: [laidOut], timeout: 2)

        func firstScrollView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            return view.subviews.lazy.compactMap { firstScrollView(in: $0) }.first
        }
        let scroll = try XCTUnwrap(firstScrollView(in: host.view))
        XCTAssertTrue(scroll.isScrollEnabled)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        let maximumOffset = max(0, scroll.contentSize.height - scroll.bounds.height)
        scroll.setContentOffset(CGPoint(x: 0, y: maximumOffset), animated: false)
        window.layoutIfNeeded()
        XCTAssertGreaterThan(scroll.contentOffset.y, 0)
        let image = UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let printed = try text(in: image)
        XCTAssertTrue(printed.contains("finalparagraphremainsreachable"))
        XCTAssertTrue(printed.contains("close"))
        let attachment = XCTAttachment(image: image)
        attachment.name = "paper-slip-long-content-scrolled"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSharedSlipsFitShortContentAndKeepLongArticleCloseVisible() throws {
        for count in [1, 30] {
            let image = try render(PaperSlip(title: "Field notes", subtitle: nil, onClose: {}) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<count, id: \.self) { _ in
                        Text("A useful note about this Book.")
                            .font(Print.body(15))
                            .foregroundStyle(Paper.ink)
                    }
                }
            })
            let copy = try text(in: image)
            XCTAssertTrue(copy.contains("fieldnotes"))
            XCTAssertTrue(copy.contains("close"), "Closing remains outside the scrolling article")
            let height = try paperBounds(in: image).height / image.scale
            XCTAssertGreaterThan(height, 100)
            XCTAssertLessThanOrEqual(height, count == 1 ? 250 : 622)
            let attachment = XCTAttachment(image: image)
            attachment.name = "shared-slip-\(count)-paragraphs"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testEveryBuffHasItsOwnIllustrationAndVisibleDecisions() throws {
        for definition in Buffs.all {
            try autoreleasepool {
                XCTAssertNotEqual(ItemIcon.symbol(for: definition.id), "circle", definition.id)
                let model = try buffModel(definition.id)
                let image = try render(BuffSlip(model: model, index: 0, onDone: {}))
                let copy = try text(in: image)
                XCTAssertTrue(copy.contains("use"), definition.id)
                XCTAssertTrue(copy.contains("keepit"), definition.id)
                let height = try paperBounds(in: image).height / image.scale
                XCTAssertLessThanOrEqual(height, 622, definition.id)
                let attachment = XCTAttachment(image: image)
                attachment.name = "illustrated-\(definition.id)"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testShortBuffDecisionDoesNotExpandIntoAnEmptyPage() throws {
        let model = try buffModel(Buffs.freshInk)
        let image = try render(BuffSlip(model: model, index: 0, onDone: {}))
        let printed = try text(in: image)
        XCTAssertTrue(printed.contains("freshink"))
        XCTAssertTrue(printed.contains("use"))
        XCTAssertTrue(printed.contains("keepit"))
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let rows = request.results ?? []
        let use = try XCTUnwrap(rows.first { $0.topCandidates(1).first?.string.uppercased() == "USE" })
        let keep = try XCTUnwrap(rows.first { $0.topCandidates(1).first?.string.uppercased() == "KEEP IT" })
        let gap = (use.boundingBox.minY - keep.boundingBox.maxY) * image.size.height
        XCTAssertGreaterThan(gap, 0, "The two decisions must not overlap")
        XCTAssertLessThan(gap, 80, "A short Buff must not leave hundreds of blank points between its actions")
        let paperBounds = try paperBounds(in: image)
        XCTAssertLessThan(paperBounds.height / image.scale, 400,
                          "A short Buff's paper must wrap its content instead of filling the page")
        let attachment = XCTAttachment(image: image)
        attachment.name = "compact-fresh-ink-decision"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNinePaperCraneChoicesWrapAndKeepBothActionsVisible() throws {
        let model = try buffModel(Buffs.paperCrane, hand: Digit.allCases)
        let image = try render(BuffSlip(model: model, index: 0, onDone: {}))
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        try VNImageRequestHandler(cgImage: XCTUnwrap(image.cgImage)).perform([request])
        let anchor = (request.results ?? []).first { observation in
            let candidate = observation.topCandidates(1).first?.string ?? ""
            return candidate.lowercased().filter { $0.isLetter } == "chooseanumber"
        }
        let anchorBottom = (1 - (try XCTUnwrap(anchor)).boundingBox.minY) * image.size.height
        let cardWidth = min(image.size.width - 44, 480)
        let contentWidth = cardWidth - 36
        let contentLeft = (image.size.width - cardWidth) / 2 + 18
        let cellWidth = (contentWidth - 4 * 7) / 5
        let cellHeight: CGFloat = 46
        let rowGap: CGFloat = 7
        for digit in 1...9 {
            let index = digit - 1
            let row = index / 5
            let column = index % 5
            let cell = CGRect(x: contentLeft + CGFloat(column) * (cellWidth + 7) - 3,
                              y: anchorBottom + 7 + CGFloat(row) * (cellHeight + rowGap) - 3,
                              width: cellWidth + 6,
                              height: cellHeight + 6)
            XCTAssertGreaterThan(try printedInkCount(in: image, topRect: cell.insetBy(dx: 8, dy: 8)), 30,
                                 "Choice \(digit) must have visible numeral ink in its own cell")
        }
        XCTAssertGreaterThanOrEqual(cellWidth, 44,
                                    "Nine numbers must retain the minimum touch-target width")
        let printed = try text(in: image)
        XCTAssertTrue(printed.contains("use"))
        XCTAssertTrue(printed.contains("keepit"))
        let attachment = XCTAttachment(image: image)
        attachment.name = "paper-crane-nine-choices"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func buffModel(_ id: String, hand: [Digit]? = nil) throws -> GameModel {
        var game = Game(seed: "buff-decision-layout")
        try game.startPuzzle()
        var run = game.run
        run.buffs = [OwnedBuff(defID: id, pricePaid: 0)]
        if let hand {
            run.puzzle?.hand = hand
            run.puzzle?.handSize = hand.count
        }
        return GameModel(frozen: Game(run: run), page: .puzzle)
    }

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

    func testMarkerPlacementSlipShowsItsCompleteGridAndFooterOnPhoneAndIPad() async throws {
        var game = Game(seed: "marker-placement-layout")
        try game.startPuzzle()
        var run = game.run
        run.markers = [OwnedMarker(
            defID: "mk_copper",
            boughtAtLevel: run.level,
            pricePaid: 0,
            squares: [Square(80)]
        )]
        let model = GameModel(frozen: Game(run: run), page: .shop)

        let sizes: [(String, CGSize)] = [
            ("marker-placement-phone", CGSize(width: 375, height: 667)),
            ("marker-placement-ipad", CGSize(width: 834, height: 1210))
        ]
        for (name, size) in sizes {
            let slip = MarkerPlacementSlip(model: model, markerIndex: 0, onPlaced: {})
            let image = try await renderMarker(slip, size: size, attachmentName: name)
            let printed = try text(in: image)
            XCTAssertTrue(
                hasVisibleCopperCell(in: image),
                "\(name) should visibly render the occupied bottom-right Copper cell"
            )
            XCTAssertTrue(
                printed.contains("markedsquaresareworthmoreonharderpuzzles"),
                "\(name) should show the complete Marker footer"
            )
            XCTAssertTrue(
                printed.contains("moreofyourmarkscomeintoplay"),
                "\(name) should show the end of the Marker footer"
            )
        }
    }

    private func renderMarker(
        _ slip: MarkerPlacementSlip,
        size: CGSize,
        attachmentName: String
    ) async throws -> UIImage {
        let content = slip
            .frame(width: size.width, height: size.height)
            .environment(\.cosmeticTheme, .standard)
            .environment(\.colorScheme, .light)
            .environment(\.locale, Locale(identifier: "en_US"))
        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.rootViewController = host
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        let settled = expectation(description: "Hosted Marker placement slip completed layout")
        DispatchQueue.main.async {
            window.layoutIfNeeded()
            host.view.layoutIfNeeded()
            DispatchQueue.main.async {
                window.layoutIfNeeded()
                host.view.layoutIfNeeded()
                settled.fulfill()
            }
        }
        await fulfillment(of: [settled], timeout: 3)
        let image = UIGraphicsImageRenderer(size: size).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func hasVisibleCopperCell(in image: UIImage) -> Bool {
        guard let cgImage = image.cgImage else { return false }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { storage in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        // The ninth cell is in the lower-right part of the centered grid. Its
        // semi-opaque copper fill remains distinctly redder than the warm page.
        let xStart = Int(Double(width) * 0.62)
        let yStart = Int(Double(height) * 0.34)
        var copperPixels = 0
        for y in yStart..<height {
            for x in xStart..<width {
                let offset = (y * width + x) * 4
                let red = Int(pixels[offset])
                let green = Int(pixels[offset + 1])
                let blue = Int(pixels[offset + 2])
                if red >= green + 18, green >= blue + 12, red >= 120 {
                    copperPixels += 1
                }
            }
        }
        return copperPixels >= 20
    }

    private func render<Content: View>(_ slip: Content) throws -> UIImage {
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

    private func printedInkCount(in image: UIImage, topRect: CGRect) throws -> Int {
        let bounds = CGRect(origin: .zero, size: image.size)
        let cropRect = topRect.intersection(bounds)
        guard !cropRect.isEmpty else { return 0 }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let cropped = UIGraphicsImageRenderer(size: cropRect.size, format: format).image { _ in
            image.draw(in: CGRect(x: -cropRect.minX, y: -cropRect.minY,
                                  width: image.size.width, height: image.size.height))
        }

        // Isolated numeral OCR confuses 5/S and 3/8. Count actual dark label
        // pixels inside each outlined cell instead: this also fails when the
        // old single row makes the expected second-row choices disappear.
        let cgImage = try XCTUnwrap(cropped.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { storage in
            guard let context = CGContext(data: storage.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return stride(from: 0, to: pixels.count, by: 4).filter {
            pixels[$0] < 100 && pixels[$0 + 1] < 100 && pixels[$0 + 2] < 100 && pixels[$0 + 3] > 200
        }.count
    }

    private func paperBounds(in image: UIImage) throws -> CGRect {
        guard let cgImage = image.cgImage else { return .zero }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        pixels.withUnsafeMutableBytes { storage in
            guard let context = CGContext(
                data: storage.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        func isPaper(_ offset: Int) -> Bool {
            let red = Int(pixels[offset])
            let green = Int(pixels[offset + 1])
            let blue = Int(pixels[offset + 2])
            let brightest = max(red, max(green, blue))
            let darkest = min(red, min(green, blue))
            return red >= 120 && green >= 120 && blue >= 100 && brightest - darkest < 90
        }

        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width {
                if isPaper((y * width + x) * 4) {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        guard maxX >= minX, maxY >= minY else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
