import Foundation
import Observation
import SwiftUI

/// Shared presentation ownership for composer and session-settings entry points.
@MainActor @Observable
final class ChatModelSignInPresentation {
    enum Action { case open, refresh }
    private struct Request {
        let id = UUID()
        let action: Action
    }

    var context: OpenClawChatModelSignInContext?
    private(set) var couldNotOpen = false
    private var request: Request?
    @ObservationIgnored private var task: Task<Void, Never>?
    var action: Action? { self.request?.action }

    func perform(_ action: Action, viewModel: OpenClawChatViewModel, isEnabled: Bool) {
        guard isEnabled, self.action == nil else { return }
        let owner = OpenClawChatComposerPresentationOwner(viewModel: viewModel)
        let request = Request(action: action)
        self.request = request
        self.couldNotOpen = false
        self.task = Task {
            defer {
                if self.request?.id == request.id {
                    self.request = nil
                    self.task = nil
                }
            }
            guard !Task.isCancelled, self.request?.id == request.id,
                  OpenClawChatComposerPresentationOwner(viewModel: viewModel) == owner
            else { return }
            switch action {
            case .open:
                let context = await viewModel.modelSignInContext()
                guard !Task.isCancelled, self.request?.id == request.id,
                      OpenClawChatComposerPresentationOwner(viewModel: viewModel) == owner
                else { return }
                self.context = context
                self.couldNotOpen = context == nil
            case .refresh:
                await viewModel.refreshModelSignIn()
            }
        }
    }

    func invalidate() {
        self.request = nil
        self.task?.cancel()
        self.task = nil
        self.context = nil
        self.couldNotOpen = false
    }
}

@MainActor
struct ChatModelSignInHost: ViewModifier {
    let presentation: ChatModelSignInPresentation
    let viewModel: OpenClawChatViewModel
    let isEnabled: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { self.presentation.context != nil },
                set: { if !$0 { self.presentation.context = nil } }))
            {
                if let context = self.presentation.context {
                    OpenClawChatModelSignInSheet(context: context) { await self.viewModel.refreshModelSignIn() }
                }
            }
            .onChange(of: OpenClawChatComposerPresentationOwner(viewModel: self.viewModel)) { _, _ in
                self.presentation.invalidate()
            }
            .onChange(of: self.isEnabled) { _, isEnabled in
                if !isEnabled { self.presentation.invalidate() }
            }
            .onDisappear { self.presentation.invalidate() }
    }
}

@MainActor
struct ChatModelSignInSettings: View {
    let viewModel: OpenClawChatViewModel
    let isEnabled: Bool
    @State private var presentation = ChatModelSignInPresentation()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if self.viewModel.composerModelAvailabilityMessage != nil {
                Text("선택한 모델의 인증을 확인해 주세요.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                Button {
                    self.presentation.perform(.open, viewModel: self.viewModel, isEnabled: self.isEnabled)
                } label: {
                    HStack(spacing: 6) {
                        if self.presentation.action == .open { ProgressView().controlSize(.small) }
                        Text("모델 로그인")
                    }
                }
                .accessibilityIdentifier("chat-model-sign-in")
                Spacer()
                Button {
                    self.presentation.perform(.refresh, viewModel: self.viewModel, isEnabled: self.isEnabled)
                } label: {
                    HStack(spacing: 6) {
                        if self.presentation.action == .refresh { ProgressView().controlSize(.small) }
                        Text("새로고침")
                    }
                }
                .accessibilityLabel("모델 인증 상태 새로고침")
                .accessibilityIdentifier("chat-composer-retry-model-sign-in")
            }
            .buttonStyle(.borderless)
            .disabled(!self.isEnabled || self.presentation.action != nil)
            if self.presentation.couldNotOpen {
                Text("모델 로그인을 열 수 없어요. 서버 지원과 연결 상태를 확인해 주세요.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .modifier(ChatModelSignInHost(
            presentation: self.presentation, viewModel: self.viewModel, isEnabled: self.isEnabled))
    }
}
