import SwiftUI
import ProbablySudokuEngine

/// Uses the supplied catalogue art. Tiles retain their authored paper; inventory
/// glyphs contain only the centered symbol, so card stock is drawn just once.
struct ItemArtwork: View {
    enum Style { case tile, glyph }
    let id: String
    var size: CGFloat = 24
    var style: Style = .tile

    var body: some View {
        Group {
            if let image = CatalogueArtwork.image(id: id, glyphOnly: style == .glyph) {
                Image(uiImage: image)
                    .renderingMode(style == .glyph && CatalogueDetails.item(id)?.category == "Buff" ? .template : .original)
                    .resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: ItemIcon.symbol(for: id))
                    .resizable().scaledToFit().padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

@MainActor
enum CatalogueArtwork {
    private static var cache: [String: UIImage] = [:]

    static func image(id: String, glyphOnly: Bool = false) -> UIImage? {
        let key = id + (glyphOnly ? ".glyph" : ".tile")
        if let cached = cache[key] { return cached }
        guard let entry = CatalogueDetails.item(id), let number = Int(entry.code.dropFirst()) else { return nil }
        let asset = "Catalogue-" + entry.sheet.replacingOccurrences(of: ".png", with: "")
        guard let source = UIImage(named: asset)?.cgImage else { return nil }
        let isolatesSymbol = glyphOnly && ["Bookmark", "Buff"].contains(entry.category)
        // Do not first apply the former symmetric glyph inset: it cropped
        // genuine strokes (the Sunday sun, Overflow arrow and wide Buffs).
        let rect = crop(category: entry.category, number: number,
                        glyphOnly: glyphOnly && !isolatesSymbol)
        // Sheets are authored at 1122 × 1402. Scale their crop if an asset
        // compiler changes its backing pixel dimensions.
        let scaled = CGRect(x: rect.minX * CGFloat(source.width) / 1122,
                            y: rect.minY * CGFloat(source.height) / 1402,
                            width: rect.width * CGFloat(source.width) / 1122,
                            height: rect.height * CGFloat(source.height) / 1402).integral
        guard let cropped = source.cropping(to: scaled) else { return nil }
        let image: UIImage
        if isolatesSymbol {
            guard let glyph = centeredGlyph(from: cropped, category: entry.category, authoredSize: rect.size) else { return nil }
            image = glyph
        } else {
            image = UIImage(cgImage: cropped, scale: 2, orientation: .up)
        }
        cache[key] = image
        return image
    }

    /// Isolate ink inside the supplied card, preserving colored Bookmark
    /// details. Buff ink is used as a template so it also reads on paper slips.
    /// Only this small decoded result is cached; no per-frame pixel work runs.
    private static func centeredGlyph(from source: CGImage, category: String, authoredSize: CGSize) -> UIImage? {
        let width = source.width, height = source.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: bitmapInfo) else { return false }
            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        let isBuff = category == "Buff"
        let scaleX = CGFloat(width) / authoredSize.width
        let scaleY = CGFloat(height) / authoredSize.height
        let left = Int((isBuff ? 5 : 7) * scaleX)
        let right = width - left
        let top = Int((isBuff ? 25 : 7) * scaleY)
        let bottom = height - Int((isBuff ? 8 : 17) * scaleY)
        var foreground = [Bool](repeating: false, count: width * height)
        for y in top..<bottom {
            for x in left..<right {
                let p = (y * width + x) * 4
                let r = Double(pixels[p]), g = Double(pixels[p + 1]), b = Double(pixels[p + 2])
                let light = 0.2126 * r + 0.7152 * g + 0.0722 * b
                if isBuff {
                    foreground[y * width + x] = min(r, g, b) > 165
                } else {
                    // Separate neutral/sage ink and genuine gold/red accents
                    // from the similarly colored but pale paper/notch edges.
                    foreground[y * width + x] = (light < 145 && r - b < 45)
                        || (r - b > 0.55 * r && r - g > 15 && b < 145)
                }
            }
        }
        // Tiny detached paper flecks must not move the symbol's center.
        // Significant components define an envelope; tiny original details
        // inside that envelope are retained rather than erased.
        var envelope = CGRect.null
        var visited = [Bool](repeating: false, count: foreground.count)
        let minimumComponent = max(3, Int(12 * scaleX * scaleY))
        for y in top..<bottom {
            for x in left..<right {
                let seed = y * width + x
                guard foreground[seed], !visited[seed] else { continue }
                var component = [seed], cursor = 0
                var bounds = CGRect(x: x, y: y, width: 1, height: 1)
                visited[seed] = true
                while cursor < component.count {
                    let index = component[cursor], cx = index % width, cy = index / width
                    cursor += 1
                    bounds = bounds.union(CGRect(x: cx, y: cy, width: 1, height: 1))
                    for (dx, dy) in [(0, -1), (0, 1), (-1, 0), (1, 0)] {
                        let nx = cx + dx, ny = cy + dy
                        guard nx >= left, nx < right, ny >= top, ny < bottom else { continue }
                        let next = ny * width + nx
                        if foreground[next], !visited[next] {
                            visited[next] = true
                            component.append(next)
                        }
                    }
                }
                if component.count >= minimumComponent { envelope = envelope.union(bounds) }
            }
        }
        guard !envelope.isNull else { return nil }
        var alpha = [UInt8](repeating: 0, count: width * height)
        let fringe = envelope.insetBy(dx: -2 * scaleX, dy: -2 * scaleY)
        for y in top..<bottom {
            for x in left..<right where fringe.contains(CGPoint(x: x, y: y)) {
                let index = y * width + x, p = index * 4
                if foreground[index], envelope.contains(CGPoint(x: x, y: y)) {
                    alpha[index] = 255
                } else {
                    // Keep the source antialias fringe only next to real ink.
                    let nearInk = (-1...1).contains { dy in
                        (-1...1).contains { dx in
                            let nx = x + dx, ny = y + dy
                            return nx >= left && nx < right && ny >= top && ny < bottom
                                && envelope.contains(CGPoint(x: nx, y: ny)) && foreground[ny * width + nx]
                        }
                    }
                    if nearInk {
                        let light = 0.2126 * Double(pixels[p]) + 0.7152 * Double(pixels[p + 1]) + 0.0722 * Double(pixels[p + 2])
                        let coverage = isBuff ? (light - 105) / 105 : (235 - light) / 90
                        alpha[index] = UInt8(max(0, min(255, coverage * 255)))
                    }
                }
            }
        }
        var minX = width, minY = height, maxX = -1, maxY = -1
        for index in alpha.indices {
            let a = Int(alpha[index]), p = index * 4
            for channel in 0..<3 { pixels[p + channel] = UInt8(Int(pixels[p + channel]) * a / 255) }
            pixels[p + 3] = alpha[index]
            if a > 0 {
                minX = min(minX, index % width); maxX = max(maxX, index % width)
                minY = min(minY, index / width); maxY = max(maxY, index / width)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let provider = CGDataProvider(data: Data(pixels) as CFData),
              let isolated = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let symbol = isolated.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) else { return nil }
        let canvas: CGFloat = 128, inset: CGFloat = 8
        let factor = (canvas - 2 * inset) / CGFloat(max(symbol.width, symbol.height))
        let size = CGSize(width: CGFloat(symbol.width) * factor, height: CGFloat(symbol.height) * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: canvas, height: canvas), format: format).image { _ in
            UIImage(cgImage: symbol).draw(in: CGRect(x: (canvas - size.width) / 2,
                y: (canvas - size.height) / 2, width: size.width, height: size.height))
        }
    }

    static func crop(category: String, number: Int, glyphOnly: Bool) -> CGRect {
        let count = category == "Buff" ? 20 : 25
        let index = (number - 1) % count
        let col = index % 5, row = index / 5
        switch category {
        case "Buff":
            let x: [CGFloat] = number <= 20 ? [47, 267, 484, 701, 920] : [55, 270, 484, 697, 912]
            let y: [CGFloat] = number <= 20 ? [119, 410, 704, 999] : [128, 436, 745, 1053]
            let rect = CGRect(x: x[col], y: y[row], width: 157, height: 160)
            return glyphOnly ? rect.insetBy(dx: 16, dy: 25) : rect
        case "Marker":
            let x: [CGFloat] = number <= 25 ? [64, 277, 490, 702, 915] : [61, 277, 491, 705, 920]
            let y: [CGFloat] = number <= 25 ? [89, 330, 577, 826, 1076] : [89, 334, 582, 846, 1098]
            let rect = CGRect(x: x[col], y: y[row], width: 144, height: 138)
            return glyphOnly ? CGRect(x: rect.minX + 20, y: rect.minY + 20, width: 60, height: 65) : rect
        default:
            let x: [CGFloat] = number <= 25 ? [56, 274, 492, 708, 924] : [66, 281, 495, 706, 920]
            let y: [CGFloat] = number <= 25 ? [78, 334, 591, 854, 1114] : [85, 331, 589, 846, 1109]
            let rect = CGRect(x: x[col], y: y[row], width: number <= 25 ? 143 : 137, height: number > 25 && row == 0 ? 141 : 146)
            return glyphOnly ? rect.insetBy(dx: 13, dy: 19) : rect
        }
    }
}
