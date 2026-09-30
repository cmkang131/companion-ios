#if DEBUG
import SwiftUI
import OpenClawChatUI

/// QA-only environment injection, labelled in captured output. It is not a
/// system accessibility-setting test and is absent from Release builds.
struct CompanionAccessibilityFixture: ViewModifier {
    private let enabled = ProcessInfo.processInfo.arguments.contains("--ui-accessibility-static")
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.environment(\.accessibilityReduceMotion, true)
                .environment(\.accessibilityReduceTransparency, true)
                .safeAreaInset(edge: .bottom) {
                    Text("검증용 · 모션 및 투명도 감소").font(.caption).padding(6).background(.white)
                }
        } else { content }
    }
}

/// Explicit rendering fixture. The labels cannot be mistaken for server work.
struct CompanionMotionGallery: View {
    private let moods: [(String, OpenClawMascotMood)] = [
        ("대기 표현", .attentive), ("응답 작성 표현", .thinking), ("응답 도착 표현", .happy)]
    var body: some View {
        VStack(spacing: 18) {
            Text("모션 미리보기").font(.title2.weight(.semibold))
            Text("서버 미연결 · 아래 상태는 시각 검증용이에요")
                .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            ForEach(moods, id: \.0) { title, mood in
                HStack(spacing: 20) {
                    CompanionCharacterView(mood: mood).frame(width: 112, height: 112)
                    Text(title).font(.body)
                }
            }
            CompanionNamePill()
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(white: 0.985))
    }
}
#endif
