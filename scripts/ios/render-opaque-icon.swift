import AppKit
import Foundation

// Apple App Store icons must be opaque. Keep the official gradient B and
// composite transparent parts over the BarLytics dark navy background.
let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("Usage: swift render-opaque-icon.swift source.png output.png\n", stderr)
    exit(2)
}
guard let source = NSImage(contentsOfFile: arguments[1]) else {
    fputs("Cannot load the official BarLytics PNG\n", stderr)
    exit(1)
}
let side = 1024
guard let output = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: side,
    pixelsHigh: side,
    bitsPerSample: 8,
    samplesPerPixel: 3,
    hasAlpha: false,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: output) else {
    fputs("Cannot create opaque RGB bitmap\n", stderr)
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor(calibratedRed: 6.0/255.0, green: 23.0/255.0, blue: 35.0/255.0, alpha: 1).setFill()
let bounds = NSRect(x: 0, y: 0, width: side, height: side)
bounds.fill()
source.draw(in: bounds, from: NSRect(origin: .zero, size: source.size),
            operation: .sourceOver, fraction: 1)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let png = output.representation(using: .png, properties: [:]) else {
    fputs("Cannot encode generated icon\n", stderr)
    exit(1)
}
do {
    try png.write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
} catch {
    fputs("Cannot save generated icon\n", stderr)
    exit(1)
}
