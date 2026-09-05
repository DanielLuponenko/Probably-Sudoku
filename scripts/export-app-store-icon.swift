import Foundation
import ImageIO
import UniformTypeIdentifiers

// Packaging conversion only: preserve every authored RGB sample and encode a
// flat RGB PNG. Apple masks the corners; the original RGBA artwork stays intact.
// Run from the repository root: swift scripts/export-app-store-icon.swift
let sourceURL = URL(fileURLWithPath: "Artwork/app-icon-light.png")
let outputURL = URL(fileURLWithPath: "App/Assets.xcassets/AppIcon.appiconset/icon.png")
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let original = CGImageSourceCreateImageAtIndex(source, 0, nil),
      original.width == 1024, original.height == 1024,
      original.bitsPerComponent == 8, original.bitsPerPixel == 32,
      original.alphaInfo == .last,
      let sourceBytes = original.dataProvider?.data,
      let bytes = CFDataGetBytePtr(sourceBytes),
      let colorSpace = original.colorSpace else {
    fatalError("Expected the approved 1024-square, straight-alpha RGBA icon")
}

var rgb = Data(capacity: original.width * original.height * 3)
for row in 0..<original.height {
    for column in 0..<original.width {
        let offset = row * original.bytesPerRow + column * 4
        rgb.append(bytes.advanced(by: offset), count: 3)
    }
}
guard let provider = CGDataProvider(data: rgb as CFData),
      let opaque = CGImage(width: original.width, height: original.height,
                           bitsPerComponent: 8, bitsPerPixel: 24,
                           bytesPerRow: original.width * 3, space: colorSpace,
                           bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: false,
                           intent: original.renderingIntent),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create the opaque App Store PNG")
}
CGImageDestinationAddImage(destination, opaque, nil)
guard CGImageDestinationFinalize(destination),
      let exportedSource = CGImageSourceCreateWithURL(outputURL as CFURL, nil),
      let exported = CGImageSourceCreateImageAtIndex(exportedSource, 0, nil),
      (exported.alphaInfo == .none || exported.alphaInfo == .noneSkipLast),
      let exportedBytes = exported.dataProvider?.data,
      let result = CFDataGetBytePtr(exportedBytes) else {
    fatalError("App Store PNG export failed verification")
}
for row in 0..<original.height {
    for column in 0..<original.width {
        let before = row * original.bytesPerRow + column * 4
        let after = row * exported.bytesPerRow + column * (exported.bitsPerPixel / 8)
        for component in 0..<3 {
            precondition(bytes[before + component] == result[after + component],
                         "Packaging must not change authored RGB samples")
        }
    }
}
print("Verified: 1024×1024 opaque PNG; all RGB samples unchanged; original artwork retained.")
