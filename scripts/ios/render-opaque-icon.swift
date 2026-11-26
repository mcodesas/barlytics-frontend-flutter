import AppKit
import CoreGraphics
import Foundation
import ImageIO

// Render the official transparent B on BarLytics navy, then encode to JPEG.
// The caller converts JPEG to PNG using sips so the App Store icon is RGB with no alpha.
let argv = CommandLine.arguments
guard argv.count == 3,
      let source = NSImage(contentsOfFile: argv[1]) else {
    fputs("Usage: swift render-opaque-icon.swift official-logo.png output.jpg\n", stderr)
    exit(2)
}
let side = 1024
let space = CGColorSpaceCreateDeviceRGB()
guard let bitmap = CGContext(
    data: nil, width: side, height: side,
    bitsPerComponent: 8, bytesPerRow: side * 4,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fputs("Cannot initialize CoreGraphics RGBA context\n", stderr)
    exit(1)
}
bitmap.setFillColor(red: 6.0/255.0, green: 23.0/255.0, blue: 35.0/255.0, alpha: 1.0)
bitmap.fill(CGRect(x: 0, y: 0, width: side, height: side))
let context = NSGraphicsContext(cgContext: bitmap, flipped: false)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
// Keep the original artwork and outer canvas; reduce the symbol by 20%.
let logoSide = CGFloat(side) * 0.8
let inset = (CGFloat(side) - logoSide) / 2.0
let bounds = NSRect(x: inset, y: inset, width: logoSide, height: logoSide)
source.draw(in: bounds, from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver, fraction: 1)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let image = bitmap.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        URL(fileURLWithPath: argv[2]) as CFURL,
        "public.jpeg" as CFString, 1, nil
      ) else {
    fputs("Cannot initialize JPEG output\n", stderr)
    exit(1)
}
CGImageDestinationAddImage(destination, image,
    [kCGImageDestinationLossyCompressionQuality: 1.0] as CFDictionary)
guard CGImageDestinationFinalize(destination) else {
    fputs("Cannot render opaque JPEG output\n", stderr)
    exit(1)
}
print("Rendered opaque BarLytics icon with official logo")
