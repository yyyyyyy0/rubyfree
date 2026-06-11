// Generate the rubyfree app icon — a dark rounded square with a gold "る" (the app's ruby
// accent colour). Headless CoreGraphics/CoreText render (no AppKit run loop), so it works
// from `swift Scripts/make-icon.swift`. Writes an .iconset of PNGs; the caller runs
// `iconutil` to produce AppIcon.icns. Reproducible: the committed AppIcon.icns can be
// regenerated from this script at any time.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Iconset members: (filename, pixel size). iconutil requires these exact names.
let members: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let outDir = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "Scripts/AppIcon.iconset")

func renderIcon(px: Int) -> CGImage? {
    let space = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    let size = CGFloat(px)
    ctx.clear(CGRect(x: 0, y: 0, width: size, height: size))

    // Rounded-square plate with a small margin (macOS icons leave ~6% breathing room).
    let margin = size * 0.06
    let plate = CGRect(x: margin, y: margin, width: size - margin * 2, height: size - margin * 2)
    let radius = plate.width * 0.225
    ctx.addPath(CGPath(roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(CGColor(red: 0.10, green: 0.10, blue: 0.11, alpha: 1.0))
    ctx.fillPath()

    // The "る", in the ruby gold, centred on its visual bounds.
    let font = CTFontCreateWithName("HiraginoSans-W6" as CFString, size * 0.62, nil)
    let gold = CGColor(red: 1.0, green: 0.82, blue: 0.30, alpha: 1.0)
    let attributed = NSAttributedString(string: "る", attributes: [
        kCTFontAttributeName as NSAttributedString.Key: font,
        kCTForegroundColorAttributeName as NSAttributedString.Key: gold,
    ])
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(
        x: (size - bounds.width) / 2 - bounds.minX,
        y: (size - bounds.height) / 2 - bounds.minY
    )
    CTLineDraw(line, ctx)

    return ctx.makeImage()
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { return false }
    CGImageDestinationAddImage(dest, image, nil)
    return CGImageDestinationFinalize(dest)
}

try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

for (name, px) in members {
    guard let image = renderIcon(px: px) else {
        FileHandle.standardError.write(Data("failed to render \(name)\n".utf8))
        exit(1)
    }
    let url = outDir.appendingPathComponent(name)
    if !writePNG(image, to: url) {
        FileHandle.standardError.write(Data("failed to write \(name)\n".utf8))
        exit(1)
    }
    print("wrote \(name) (\(px)px)")
}
print("iconset → \(outDir.path)")
