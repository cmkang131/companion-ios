import AppKit

// Assemble real simulator screenshots without cropping or synthesizing UI.
// Usage: swift scripts/render_evidence_sheet.swift <output> <caption> <png> ...
let args = Array(CommandLine.arguments.dropFirst())
precondition(args.count >= 3 && args.count % 2 == 1)
let items = stride(from: 1, to: args.count, by: 2).map { (args[$0], args[$0 + 1]) }
let columns = min(3, items.count)
let rows = (items.count + columns - 1) / columns
let cellWidth = 600, cellHeight = 1380, header = 100
let width = columns * cellWidth, height = rows * cellHeight + header
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
func label(_ value: String, x: Int, top: Int, font: CGFloat) {
    (value as NSString).draw(in: NSRect(x: x, y: height - top - 44, width: width - x - 20, height: 44),
        withAttributes: [.font: NSFont.systemFont(ofSize: font, weight: .medium),
                         .foregroundColor: NSColor.black])
}
let source = ProcessInfo.processInfo.environment["EVIDENCE_SOURCE"] ?? "see manifest"
label("Companion · actual iOS 27 Simulator renders · source \(source)", x: 24, top: 15, font: 28)
label("Disconnected / synthetic fixtures. No live server, account, or device-install evidence.", x: 24, top: 55, font: 20)
for (index, item) in items.enumerated() {
    let col = index % columns, row = index / columns
    let top = header + row * cellHeight
    label(item.0, x: col * cellWidth + 22, top: top, font: 24)
    let image = NSImage(contentsOfFile: item.1)!
    let scale = min(CGFloat(cellWidth - 40) / image.size.width, CGFloat(cellHeight - 85) / image.size.height)
    let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
    image.draw(in: NSRect(x: CGFloat(col * cellWidth) + (CGFloat(cellWidth) - size.width) / 2,
                         y: CGFloat(height - top - 60) - size.height, width: size.width, height: size.height),
               from: .zero, operation: .copy, fraction: 1)
}
NSGraphicsContext.restoreGraphicsState()
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[0]))
print(args[0])
