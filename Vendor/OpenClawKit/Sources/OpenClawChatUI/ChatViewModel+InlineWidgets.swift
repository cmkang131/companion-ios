import Foundation

enum ChatInlineWidgetAvailability: Hashable, Sendable {
    case unsupported
    case waitingForConnection
    case ready

    init(supportsLoading: Bool, isConnected: Bool) {
        if !supportsLoading {
            self = .unsupported
        } else {
            self = isConnected ? .ready : .waitingForConnection
        }
    }

    var statusMessage: String? {
        switch self {
        case .unsupported:
            String(localized: "이 연결에서는 미리보기를 열 수 없어요.")
        case .waitingForConnection:
            String(localized: "서버 연결 후 미리보기를 불러올 수 있어요.")
        case .ready:
            nil
        }
    }

    @MainActor
    func resolve(
        path: String,
        replacing failedResource: OpenClawChatWidgetResource?,
        using resolver: @MainActor @Sendable (
            String,
            OpenClawChatWidgetResource?) async -> OpenClawChatWidgetResource?) async -> OpenClawChatWidgetResource?
    {
        guard self == .ready else { return nil }
        return await resolver(path, failedResource)
    }
}

extension OpenClawChatViewModel {
    var inlineWidgetAvailability: ChatInlineWidgetAvailability {
        ChatInlineWidgetAvailability(
            supportsLoading: self.transport.supportsInlineWidgetLoading,
            isConnected: self.healthOK)
    }
}
