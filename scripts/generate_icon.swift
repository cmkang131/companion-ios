import AppKit
import SwiftUI

/// Renders the same code-drawn character as the app. No private reference pixels.
@main struct RenderCharacter {
    @MainActor static func main() throws {
        let destination = CommandLine.arguments[1]
        let content = ZStack {
            Color(white: 0.98)
            CompanionCharacterArtwork(pose: .staticPose(for: .attentive))
                .frame(width: 750, height: 750).offset(y: 45)
        }.frame(width: 1024, height: 1024).environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        guard let image = renderer.cgImage else { fatalError("Character rendering failed") }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("PNG failed") }
        try png.write(to: URL(fileURLWithPath: destination))
    }
}
