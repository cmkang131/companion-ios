import Foundation

public enum OpenClawChatMediaArtifactAvailability: Equatable, Sendable {
    case unsupported
    case disconnected
    case available

    public init(supportsLoading: Bool, isConnected: Bool) {
        if !supportsLoading {
            self = .unsupported
        } else {
            self = isConnected ? .available : .disconnected
        }
    }

    var unavailableReason: String? {
        switch self {
        case .unsupported:
            String(localized: "이 연결에서는 첨부 파일을 열 수 없어요.")
        case .disconnected:
            String(localized: "연결 후 첨부 파일을 열 수 있어요.")
        case .available:
            nil
        }
    }
}

extension OpenClawChatViewModel {
    public var mediaArtifactAvailability: OpenClawChatMediaArtifactAvailability {
        OpenClawChatMediaArtifactAvailability(
            supportsLoading: self.transport.supportsMediaArtifactLoading,
            isConnected: self.healthOK)
    }
}
