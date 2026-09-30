import SwiftUI

/// Code-drawn artwork based on the user's current blue character reference.
/// The private screenshot is never bundled. Motion reuses the MIT animator.
public struct CompanionCharacterView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animator = OpenClawMascotAnimator()
    private let mood: OpenClawMascotMood
    private let paused: Bool

    public init(mood: OpenClawMascotMood = .attentive, paused: Bool = false) {
        self.mood = mood
        #if DEBUG
        self.paused = paused || ProcessInfo.processInfo.arguments.contains("--ui-testing")
            || ProcessInfo.processInfo.arguments.contains("--ui-accessibility-static")
        #else
        self.paused = paused
        #endif
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || paused || scenePhase != .active)) { context in
            let pose = reduceMotion || paused ? OpenClawMascotPose.staticPose(for: mood)
                : animator.pose(at: context.date.timeIntervalSinceReferenceDate)
            CompanionCharacterArtwork(pose: pose)
        }
        .onAppear { animator.setMood(mood, at: Date().timeIntervalSinceReferenceDate) }
        .onChange(of: mood) { _, value in animator.setMood(value, at: Date().timeIntervalSinceReferenceDate) }
        .accessibilityHidden(true)
    }
}

/// Separate from the timeline so the exact drawing can be rendered for QA.
struct CompanionCharacterArtwork: View {
    let pose: OpenClawMascotPose

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            ZStack {
                CompanionBodyShape()
                    .fill(LinearGradient(colors: [Color(red: 0.36, green: 0.51, blue: 1),
                        Color(red: 0.21, green: 0.40, blue: 0.94)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        CompanionBodyShape().fill(RadialGradient(colors: [.white.opacity(0.34), .clear],
                            center: UnitPoint(x: 0.23, y: 0.20), startRadius: 0, endRadius: size * 0.25))
                    }
                    .overlay {
                        CompanionBodyShape().fill(RadialGradient(colors: [.white.opacity(0.18), .clear],
                            center: UnitPoint(x: 0.73, y: 0.20), startRadius: 0, endRadius: size * 0.23))
                    }
                    .overlay {
                        CompanionBodyShape().fill(RadialGradient(colors: [.white.opacity(0.12), .clear],
                            center: UnitPoint(x: 0.23, y: 0.59), startRadius: 0, endRadius: size * 0.27))
                    }
                    .overlay {
                        CompanionBodyShape().fill(RadialGradient(colors: [Color.blue.opacity(0.12), .clear],
                            center: UnitPoint(x: 0.80, y: 0.76), startRadius: 0, endRadius: size * 0.30))
                    }
                Circle()
                    .fill(RadialGradient(colors: [Color(red: 0.42, green: 0.58, blue: 1),
                        Color(red: 0.28, green: 0.46, blue: 0.98), Color(red: 0.19, green: 0.36, blue: 0.88)],
                        center: UnitPoint(x: 0.30, y: 0.20), startRadius: 0, endRadius: size * 0.135))
                    .frame(width: size * 0.135, height: size * 0.135)
                    .shadow(color: .blue.opacity(0.12), radius: size * 0.012, x: 0, y: size * 0.006)
                    .position(x: size * 0.82, y: size * 0.54)
                HStack(spacing: size * 0.11) {
                    eye(openness: pose.leftEyeOpenness, size: size)
                    eye(openness: pose.rightEyeOpenness, size: size)
                }
                .position(x: size * 0.51 + pose.gaze.width * size * 0.024,
                    y: size * 0.35 + pose.gaze.height * size * 0.025)
            }
            .frame(width: size, height: size)
            .scaleEffect(x: 1, y: 1 + (pose.bodyStretch - 1) * 0.30, anchor: .bottom)
            .rotationEffect(.degrees(pose.bodyTilt * 0.30))
            .offset(y: pose.floatOffset * size / 400)
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func eye(openness: CGFloat, size: CGFloat) -> some View {
        Ellipse().fill(Color(white: 0.12))
            .frame(width: size * 0.088, height: max(size * 0.012, size * 0.139 * openness))
            .frame(height: size * 0.139)
    }
}

private struct CompanionBodyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0.50, y: 0.19))
        p.addCurve(to: CGPoint(x: 0.20, y: 0.09), control1: CGPoint(x: 0.35, y: 0.12), control2: CGPoint(x: 0.32, y: 0.04))
        p.addCurve(to: CGPoint(x: 0.095, y: 0.43), control1: CGPoint(x: 0.055, y: 0.14), control2: CGPoint(x: 0.02, y: 0.32))
        p.addCurve(to: CGPoint(x: 0.14, y: 0.80), control1: CGPoint(x: -0.025, y: 0.57), control2: CGPoint(x: 0.01, y: 0.75))
        p.addCurve(to: CGPoint(x: 0.49, y: 0.78), control1: CGPoint(x: 0.25, y: 0.86), control2: CGPoint(x: 0.38, y: 0.79))
        p.addCurve(to: CGPoint(x: 0.84, y: 0.81), control1: CGPoint(x: 0.62, y: 0.81), control2: CGPoint(x: 0.74, y: 0.85))
        p.addCurve(to: CGPoint(x: 0.90, y: 0.44), control1: CGPoint(x: 0.99, y: 0.75), control2: CGPoint(x: 1.0, y: 0.57))
        p.addCurve(to: CGPoint(x: 0.80, y: 0.10), control1: CGPoint(x: 0.99, y: 0.28), control2: CGPoint(x: 0.90, y: 0.10))
        p.addCurve(to: CGPoint(x: 0.50, y: 0.19), control1: CGPoint(x: 0.69, y: 0.10), control2: CGPoint(x: 0.61, y: 0.14))
        p.closeSubpath()
        return p.applying(CGAffineTransform(scaleX: rect.width, y: rect.height))
            .applying(CGAffineTransform(translationX: rect.minX, y: rect.minY))
    }
}
