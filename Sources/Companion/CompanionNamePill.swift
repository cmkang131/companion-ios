import SwiftUI

struct CompanionNamePill: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private var usesOpaqueSurface: Bool {
        #if DEBUG
        reduceTransparency || ProcessInfo.processInfo.arguments.contains("--ui-accessibility-static")
        #else
        reduceTransparency
        #endif
    }

    var body: some View {
        Text("dot")
            .font(.title3.weight(.semibold))
            .padding(.horizontal, 24).padding(.vertical, 8)
            .modifier(NamePillSurface(opaque: usesOpaqueSurface))
            .accessibilityHidden(true)
    }
}

private struct NamePillSurface: ViewModifier {
    let opaque: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if opaque {
            content.background(Color(white: 0.94), in: Capsule())
        } else {
            content.glassEffect(.regular, in: .capsule)
        }
    }
}
