import SwiftUI

/// Original, replaceable Companion artwork driven by the existing MIT animator.
/// No Muse, OpenAI, or Grok character paths or image assets are used.
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
        #else
        self.paused = paused
        #endif
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion || paused || scenePhase != .active)) { context in
            let pose = reduceMotion ? OpenClawMascotPose.staticPose(for: mood)
                : animator.pose(at: context.date.timeIntervalSinceReferenceDate)
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height)
                ZStack {
                    RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                        .fill(Color(white: 0.17))
                        .frame(width: size * 0.76, height: size * 0.72)
                    HStack(spacing: size * 0.12) {
                        eye(openness: pose.leftEyeOpenness, size: size)
                        eye(openness: pose.rightEyeOpenness, size: size)
                    }
                    .offset(x: pose.gaze.width * size * 0.025, y: -size * 0.025 + pose.gaze.height * size * 0.025)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .scaleEffect(x: 1, y: 1 + (pose.bodyStretch - 1) * 0.25, anchor: .bottom)
                .rotationEffect(.degrees(pose.bodyTilt * 0.25))
                .offset(y: pose.floatOffset * size / 400)
            }
        }
        .onAppear { animator.setMood(mood, at: Date().timeIntervalSinceReferenceDate) }
        .onChange(of: mood) { _, value in animator.setMood(value, at: Date().timeIntervalSinceReferenceDate) }
        .accessibilityHidden(true)
    }

    private func eye(openness: CGFloat, size: CGFloat) -> some View {
        Capsule().fill(Color(white: 0.97))
            .frame(width: size * 0.058, height: max(size * 0.014, size * 0.105 * openness))
            .frame(height: size * 0.105)
    }
}
