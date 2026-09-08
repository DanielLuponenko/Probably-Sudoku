import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookLivingSceneTests: XCTestCase {
    func testEveryBookHasAFullWidthCompositionNotAnEnlargedBenefitBadge() throws {
        var silhouettes = Set<Data>()
        for book in Book.allCases {
            let image = try render(BookLivingSceneArtwork(book: book).frame(width: 360, height: 112))
            let bytes = try pixels(image)
            let visible = pixelIndices(bytes).filter { bytes[$0 + 3] > 170 }
            let strongInk = visible.filter { bytes[$0] < 170 && bytes[$0 + 1] < 170 && bytes[$0 + 2] < 170 }
            XCTAssertGreaterThan(visible.count, 1_800, "\(book.rawValue) must contain substantial paper objects")
            XCTAssertGreaterThan(strongInk.count, 360, "\(book.rawValue) must be legible ink, not a faint wash")
            let columns = visible.map { ($0 / 4) % 360 }
            let rows = visible.map { ($0 / 4) / 360 }
            XCTAssertGreaterThan((columns.max() ?? 0) - (columns.min() ?? 0), 190,
                                 "\(book.rawValue) should inhabit the reserved width, not sit as a central icon")
            XCTAssertGreaterThan((rows.max() ?? 0) - (rows.min() ?? 0), 65,
                                 "\(book.rawValue) should use the actual vignette height")
            silhouettes.insert(Data(pixelIndices(bytes).map { bytes[$0 + 3] }))
            attach(image, name: "living-scene-\(book.rawValue)-112-rest")
        }
        XCTAssertEqual(silhouettes.count, 12, "Each Book requires a different composition, not only a hue swap")
    }

    func testEachSceneHasDiscernibleMotionAtActualCompactPhoneSize() throws {
        for book in Book.allCases {
            let first = try render(BookLivingSceneArtwork(book: book, time: 0).frame(width: 328, height: 96))
            let next = try render(BookLivingSceneArtwork(book: book, time: 1.8).frame(width: 328, height: 96))
            let a = try pixels(first), b = try pixels(next)
            let changed = pixelIndices(a).filter { offset in
                (0..<4).contains { abs(Int(a[offset + $0]) - Int(b[offset + $0])) > 20 }
            }.count
            XCTAssertGreaterThan(changed, 160,
                                 "\(book.rawValue)'s action must be noticeable at 96pt, not a two-pixel shimmer")
            attach(first, name: "living-scene-\(book.rawValue)-96-rest")
            attach(next, name: "living-scene-\(book.rawValue)-96-moving")
        }
    }

    func testLivingScenesDoNotLeakIntoNeighboringLabelsAtPhoneAndIPadSizes() throws {
        for (width, height): (CGFloat, CGFloat) in [(240, 88), (328, 96), (360, 112), (700, 120)] {
            for book in Book.allCases {
                let view = VStack(spacing: 0) {
                    Color.clear.frame(height: 10)
                    BookLivingSceneArtwork(book: book, time: 2.6).frame(height: height)
                    Color.clear.frame(height: 10)
                }.frame(width: width)
                let image = try render(view)
                XCTAssertEqual(image.size, CGSize(width: width, height: height + 20))
                let bytes = try pixels(image), w = Int(width), h = Int(height)
                for row in Array(0..<10) + Array((h + 10)..<(h + 20)) {
                    XCTAssertTrue((0..<w).allSatisfy { bytes[(row * w + $0) * 4 + 3] == 0 },
                                  "\(book.rawValue) at \(width)×\(height) spills into adjacent print")
                }
            }
        }
    }

    func testLivingArtworkFreezesExactlyAndResumesWithoutFastForward() throws {
        var clock = BossMotionClock()
        clock.setRunning(true, at: 40)
        clock.setRunning(false, at: 41.8)
        let pausedTime = clock.elapsed(at: 900)
        clock.setRunning(true, at: 900)
        let resumedTime = clock.elapsed(at: 900)
        XCTAssertEqual(pausedTime, resumedTime)
        for book in Book.allCases {
            let paused = try render(BookLivingSceneArtwork(book: book, time: pausedTime).frame(width: 360, height: 112))
            let resumed = try render(BookLivingSceneArtwork(book: book, time: resumedTime).frame(width: 360, height: 112))
            XCTAssertEqual(paused.pngData(), resumed.pngData(), "\(book.rawValue) jumped after a covered/inactive pause")
        }
    }

    func testNonFiniteRenderTimeReturnsTheSameSafeRestFrame() throws {
        for book in Book.allCases {
            let rest = try render(BookLivingSceneArtwork(book: book, time: 0).frame(width: 328, height: 96))
            let invalid = try render(BookLivingSceneArtwork(book: book, time: .nan).frame(width: 328, height: 96))
            XCTAssertEqual(rest.pngData(), invalid.pngData())
        }
    }

    func testContactSheetShowsAllTwelveAuthoredWorldsAtRealSize() throws {
        let sheet = VStack(spacing: 12) {
            ForEach(Book.allCases, id: \.self) { book in
                HStack(spacing: 16) {
                    BookLivingSceneArtwork(book: book, time: 0).frame(width: 360, height: 112)
                    BookLivingSceneArtwork(book: book, time: 1.8).frame(width: 360, height: 112)
                }
            }
        }
        .padding(12)
        .background(Paper.page)
        attach(try render(sheet), name: "all-twelve-living-scenes-rest-and-action-actual-size")
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func pixelIndices(_ bytes: [UInt8]) -> StrideTo<Int> {
        stride(from: 0, to: bytes.count, by: 4)
    }

    private func render<Content: View>(_ content: Content) throws -> UIImage {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func pixels(_ image: UIImage) throws -> [UInt8] {
        let cgImage = try XCTUnwrap(image.cgImage)
        let width = cgImage.width, height = cgImage.height
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }
}
