import AppKit

// Original Companion artwork. Rebuild without any external image assets.
let destination = CommandLine.arguments[1]
let side = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(white: 0.98, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: side, height: side)).fill()
NSColor(white: 0.17, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 210, y: 224, width: 604, height: 574), xRadius: 280, yRadius: 280).fill()
NSColor(white: 0.97, alpha: 1).setFill()
for x in [422, 542] {
    NSBezierPath(roundedRect: NSRect(x: x, y: 506, width: 44, height: 80), xRadius: 22, yRadius: 22).fill()
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
