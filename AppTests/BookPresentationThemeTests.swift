import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BookPresentationThemeTests: XCTestCase {
    func testEveryBookUsesItsOwnCatalogColorAndMarginalMotif() {
        let themes = Book.allCases.map { BookPresentationTheme(book: $0) }
        XCTAssertEqual(themes.count, 12)
        XCTAssertEqual(Set(themes.map(\.motif.rawValue)).count, 12)
        for theme in themes {
            XCTAssertEqual(theme.accent, BookEdition.edition(for: theme.book).accent)
            XCTAssertEqual(theme.motif, BookAmbientMotif.forBook(theme.book))
            XCTAssertEqual(theme, BookPresentationTheme(book: theme.book),
                           "A redraw cannot choose a random Book color or motif")
        }
        // Selecting another Book never mutates the first edition's theme.
        XCTAssertEqual(BookPresentationTheme.first, BookPresentationTheme(book: .probably))
    }

    func testEveryPrimaryButtonMeetsNormalTextContrastWithoutLosingBookColor() {
        var renderedColors = Set<Data>()
        for book in Book.allCases {
            let theme = BookPresentationTheme(book: book)
            XCTAssertGreaterThanOrEqual(
                BookPresentationTheme.contrast(theme.buttonFill, theme.buttonForeground), 4.5,
                "\(book.rawValue)'s cream label must remain readable")
            XCTAssertEqual(theme.buttonForeground, Paper.page)
            if let image = ImageRenderer(content: theme.buttonFill.frame(width: 8, height: 8)).uiImage,
               let data = image.pngData() {
                renderedColors.insert(data)
            }
        }
        XCTAssertEqual(renderedColors.count, 12,
                       "Contrast handling must not make every Book's controls the same sage")
    }

    func testEveryBookMeetsSmallLabelContrastOnTheActualWarmQuietSurface() {
        for book in Book.allCases {
            let theme = BookPresentationTheme(book: book)
            XCTAssertGreaterThanOrEqual(
                BookPresentationTheme.contrast(theme.buttonFill, Paper.pageWarm), 4.5,
                "\(book.rawValue) must be checked against the darker quiet-button stock, not only the page")
            for paperID in ["pp_newsprint", "pp_night_sky"] {
                let paper = CosmeticCatalog.paper(paperID)
                XCTAssertGreaterThanOrEqual(
                    BookPresentationTheme.contrast(theme.quietInk(onDarkPaper: paper.isDark), paper.warm), 4.5,
                    "\(book.rawValue)'s small quiet label must stay readable on \(paperID)")
            }
        }
    }

    func testRenderedSmallSubtitlesKeepFullContrastAcrossAllBooksAndLightAndDarkPaper() throws {
        for book in Book.allCases {
            let bookTheme = BookPresentationTheme(book: book)
            for paperID in ["pp_newsprint", "pp_night_sky"] {
                var cosmetic = CosmeticTheme.standard
                cosmetic.paper = CosmeticCatalog.paper(paperID)
                for primary in [false, true] {
                    let expectedInk = primary ? bookTheme.buttonForeground
                        : bookTheme.quietInk(onDarkPaper: cosmetic.paper.isDark)
                    let context = "\(book.rawValue), \(paperID), \(primary ? "primary" : "quiet")"
                    // An empty title prevents its larger opaque glyphs from
                    // accidentally satisfying the subtitle's contrast check.
                    // The real production view still controls font and alpha.
                    let paperButton = PaperButton(title: "", subtitle: "MMMM MMMM MMMM",
                                                  kind: primary ? .primary : .quiet, action: {})
                    try assertRenderedSubtitle(
                        paperButton, bookTheme: bookTheme, cosmetic: cosmetic,
                        expectedInk: expectedInk,
                        expectedFill: primary ? bookTheme.buttonFill
                            : cosmetic.paper.warm.mixed(with: cosmetic.paper.page, by: 0.1),
                        context: "PaperButton: \(context)")

                    let puzzleButton = PuzzleActionButton(title: "", subtitle: "MMMM MMMM MMMM",
                                                          kind: primary ? .primary : .quiet, action: {})
                    try assertRenderedSubtitle(
                        puzzleButton, bookTheme: bookTheme, cosmetic: cosmetic,
                        expectedInk: expectedInk,
                        expectedFill: primary ? bookTheme.buttonFill : cosmetic.paper.warm,
                        context: "PuzzleActionButton: \(context)")
                }
            }
        }
    }

    func testCachedPaletteLookupsPreserveAllAuthoredColorsAcrossBookChanges() {
        let originals = Book.allCases.map { BookPresentationTheme(book: $0) }
        for _ in 0..<20 {
            for original in originals.reversed() {
                let cached = BookPresentationTheme(book: original.book)
                XCTAssertEqual(cached, original)
                XCTAssertEqual(cached.quietInk(onDarkPaper: true),
                               original.accent.mixed(with: Paper.page, by: 0.48))
                XCTAssertEqual(cached.quietInk(onDarkPaper: false), original.buttonFill)
            }
        }
    }

    func testAmbientMotionRequiresAllFourSafetyGates() {
        for active in [false, true] {
            for sceneActive in [false, true] {
                for reduced in [false, true] {
                    for lowPower in [false, true] {
                        XCTAssertEqual(
                            BookAmbientMotionPolicy.shouldAnimate(isActive: active,
                                                                  sceneIsActive: sceneActive,
                                                                  reduceMotion: reduced,
                                                                  lowPower: lowPower),
                            active && sceneActive && !reduced && !lowPower)
                    }
                }
            }
        }
    }

    func testAllBooksHaveDifferentArtworkAndChangeOnlyInTheMargins() throws {
        var stills = Set<Data>()
        for book in Book.allCases {
            let first = try render(book: book, time: 0)
            let later = try render(book: book, time: 12)
            stills.insert(try XCTUnwrap(first.pngData()))
            XCTAssertNotEqual(first.pngData(), later.pngData(),
                              "\(book.rawValue) needs its own living marginalia")
            try assertClearCenter(first)
            try assertClearCenter(later)
        }
        XCTAssertEqual(stills.count, 12)
    }

    func testMotionFrameIsDeterministicAndMarginBudgetDoesNotGrowOnIPad() throws {
        XCTAssertEqual(try render(book: .genuinely, time: 8).pngData(),
                       try render(book: .genuinely, time: 8).pngData())
        XCTAssertEqual(BookAmbientArtwork.marginWidth(for: CGSize(width: 320, height: 640)), 17.6,
                       accuracy: 0.001)
        XCTAssertEqual(BookAmbientArtwork.marginWidth(for: CGSize(width: 1024, height: 1366)), 18)
    }

    func testPageMarginaliaLeavesTheEntireReadingColumnClearWithoutDisappearing() throws {
        for width: CGFloat in [327, 759] {
            for book in Book.allCases {
                for time: TimeInterval in [0, 12] {
                    // Match the actual ownership: GameView installs a background
                    // on the content; PageSurface then adds the physical margins.
                    let view = Color.clear.frame(width: width, height: 640)
                        .background {
                            BookAmbientArtwork(theme: BookPresentationTheme(book: book), time: time)
                                .modifier(BookPageMarginPlacement())
                        }
                        .padding(Volume.pageContentInsets)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    let image = try XCTUnwrap(renderer.uiImage)
                    let cg = try XCTUnwrap(image.cgImage)
                    var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
                    try pixels.withUnsafeMutableBytes { storage in
                        let context = try XCTUnwrap(CGContext(
                            data: storage.baseAddress, width: cg.width, height: cg.height,
                            bitsPerComponent: 8, bytesPerRow: cg.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                        context.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
                    }
                    let left = Int(Volume.pageContentInsets.leading)
                    let right = left + Int(width)
                    var intrusions = 0, marginInk = 0
                    for y in 0..<cg.height {
                        for x in 0..<cg.width where pixels[(y * cg.width + x) * 4 + 3] > 0 {
                            if (left..<right).contains(x) { intrusions += 1 }
                            else { marginInk += 1 }
                        }
                    }
                    XCTAssertEqual(intrusions, 0,
                                   "\(book.rawValue), width \(width), time \(time): ink overlaps offer text/icons")
                    XCTAssertGreaterThan(marginInk, 0,
                                         "Move the decoration to the paper margin; do not remove it")
                    if intrusions > 0 {
                        let attachment = XCTAttachment(image: image)
                        attachment.name = "marginalia-reading-column-\(book.rawValue)-\(Int(width))-\(Int(time))"
                        attachment.lifetime = .keepAlways
                        add(attachment)
                        return
                    }
                }
            }
        }
    }

    private func render(book: Book, time: TimeInterval) throws -> UIImage {
        let renderer = ImageRenderer(content: BookAmbientArtwork(theme: BookPresentationTheme(book: book),
                                                                 time: time)
            .frame(width: 320, height: 640))
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage)
    }

    private func assertRenderedSubtitle<Content: View>(
        _ content: Content, bookTheme: BookPresentationTheme, cosmetic: CosmeticTheme,
        expectedInk: Color, expectedFill: Color, context: String,
        file: StaticString = #filePath, line: UInt = #line
    ) throws {
        let renderer = ImageRenderer(content: content
            .frame(width: 320, height: 52)
            .background(cosmetic.paper.page)
            .environment(\.bookPresentation, bookTheme)
            .environment(\.cosmeticTheme, cosmetic)
            .environment(\.colorScheme, .light))
        // Device-scale text provides many solid glyph-core pixels. Thin
        // antialiased edges are deliberately not treated as the text color.
        renderer.scale = 3
        let image = try XCTUnwrap(renderer.uiImage, file: file, line: line)
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB), file: file, line: line)
            let bitmap = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                                space: colorSpace,
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                                      file: file, line: line)
            bitmap.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        func pixel(_ x: Int, _ y: Int) -> [Double] {
            let offset = (y * width + x) * 4
            return (0..<3).map { Double(bytes[offset + $0]) / 255 }
        }
        func components(_ color: Color) -> [Double] {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return [Double(r), Double(g), Double(b)]
        }
        func luminance(_ rgb: [Double]) -> Double {
            zip(rgb, [0.2126, 0.7152, 0.0722]).reduce(0) { sum, pair in
                let component = pair.0
                let linear = component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
                return sum + linear * pair.1
            }
        }

        // The left interior contains only the actual button surface: no
        // rounded border, shadow or centered subtitle is included.
        let background = pixel(48, height / 2)
        let fill = components(expectedFill), ink = components(expectedInk)
        for channel in 0..<3 {
            XCTAssertEqual(background[channel], fill[channel], accuracy: 2.0 / 255,
                           "\(context): unexpected rendered button paper", file: file, line: line)
        }
        let backgroundLight = luminance(background)
        var opaqueCoreCount = 0
        var coreContrasts: [Double] = []
        for y in 24..<(height - 24) {
            for x in 120..<(width - 120) {
                let rgb = pixel(x, y)
                guard (0..<3).allSatisfy({ abs(rgb[$0] - ink[$0]) <= 2.0 / 255 }) else { continue }
                opaqueCoreCount += 1
                let glyphLight = luminance(rgb)
                coreContrasts.append((max(backgroundLight, glyphLight) + 0.05)
                                     / (min(backgroundLight, glyphLight) + 0.05))
            }
        }
        XCTAssertGreaterThanOrEqual(opaqueCoreCount, 24,
                                   "\(context): subtitle opacity washed out the solid glyph cores",
                                   file: file, line: line)
        // Exact source palettes above must meet 4.5. Here allow only the small
        // error introduced by 8-bit sRGB quantization and near-solid edge pixels.
        XCTAssertGreaterThanOrEqual(coreContrasts.max() ?? 0, 4.465,
                                   "\(context): actual small glyphs lost their 4.5:1 contrast",
                                   file: file, line: line)
        if opaqueCoreCount < 24 || (coreContrasts.max() ?? 0) < 4.465 {
            let attachment = XCTAttachment(image: image)
            attachment.name = "button-subtitle-contrast-\(context)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func assertClearCenter(_ image: UIImage,
                                   file: StaticString = #filePath, line: UInt = #line) throws {
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: width, height: height,
                                                 bitsPerComponent: 8, bytesPerRow: width * 4,
                                                 space: CGColorSpaceCreateDeviceRGB(),
                                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                                       file: file, line: line)
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        for row in 0..<height {
            for column in 19..<(width - 19) {
                if bytes[(row * width + column) * 4 + 3] != 0 {
                    XCTFail("Decorative ink overlaps readable content at \(column),\(row)",
                            file: file, line: line)
                    return
                }
            }
        }
        XCTAssertTrue(stride(from: 3, to: bytes.count, by: 4).contains { bytes[$0] > 0 },
                      "The margin artwork must not be entirely invisible", file: file, line: line)
    }
}
