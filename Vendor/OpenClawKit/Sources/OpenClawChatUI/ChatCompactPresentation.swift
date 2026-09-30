import SwiftUI

private struct CompactConversationKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Opt-in mobile presentation: a single-row composer and message actions on
    /// long press. The underlying editor, send/cancel controls and menus are reused.
    public var openClawCompactConversation: Bool {
        get { self[CompactConversationKey.self] }
        set { self[CompactConversationKey.self] = newValue }
    }
}

/// Reuses the existing model/effort controls outside the conversation composer.
@MainActor
public struct OpenClawChatSessionSettings: View {
    private let viewModel: OpenClawChatViewModel
    private let isEnabled: Bool

    public init(viewModel: OpenClawChatViewModel, isEnabled: Bool) {
        self.viewModel = viewModel
        self.isEnabled = isEnabled
    }

    private var controls: OpenClawChatComposer {
        OpenClawChatComposer(viewModel: viewModel, style: .standard,
            showsSessionSwitcher: false, userAccent: nil, composerChrome: .clean,
            isComposerEnabled: isEnabled, isAttachmentInputEnabled: false,
            messagePlaceholder: nil, talkControl: nil, dictationControl: nil, voiceNoteControl: nil)
    }

    public var body: some View {
        Group {
            if viewModel.composerModelMutationAvailable {
                LabeledContent("모델") { controls.modelPicker.accessibilityLabel("모델") }
            } else {
                LabeledContent("모델", value: viewModel.modelSelectionID == OpenClawChatViewModel.defaultModelSelectionID
                    ? "서버 기본값" : viewModel.canonicalModelSelectionID)
            }
            if viewModel.showsThinkingPicker, viewModel.composerEffortMutationAvailable {
                controls.thinkingPicker
            }
            if viewModel.sessionBranches.count > 1 { controls.branchMenu }
            ChatModelSignInSettings(viewModel: viewModel, isEnabled: isEnabled)
            if let message = viewModel.modelCatalogMessage {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .disabled(!isEnabled || viewModel.isUpdatingSessionSettings)
        .task(id: viewModel.composerCapabilityOwnerID) {
            if isEnabled { await viewModel.loadComposerCapabilities() }
        }
    }
}
