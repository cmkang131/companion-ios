import Foundation

public enum OpenClawChatStopState: Equatable, Sendable {
    case idle, requesting, requested, stopped, ended, failed, unconfirmed
}

/// Describes only the selected conversation, never all work on the gateway.
public struct OpenClawChatRunActivity: Equatable, Sendable {
    public let hasActiveRun: Bool
    public let knownRunCount: Int
    /// Runs eligible for a new explicit request; excludes accepted Stop requests.
    public let stoppableRunCount: Int
    public let requestedRunCount: Int
    public let stopState: OpenClawChatStopState
    public let canStop: Bool
    public let canRefresh: Bool
    public let isRefreshing: Bool
}

public enum OpenClawChatAbortReceipt: Equatable, Sendable {
    /// The server accepted the exact request; execution may still be ending.
    case requested
    case unconfirmed
}

public enum OpenClawChatStopObservation: Equatable, Sendable {
    case stopped, ended, active, unavailable
}

public enum OpenClawChatRunControlError: Error, Sendable {
    case notDispatched
}

/// A platform adapter binds both mutation and observation to one physical route.
public struct OpenClawChatRunControlRouteLease: Sendable {
    public let requestStop: @Sendable (_ sessionKey: String, _ agentID: String?, _ runID: String) async throws
        -> OpenClawChatAbortReceipt
    public let observe: @Sendable (_ runID: String) async -> OpenClawChatStopObservation

    public init(
        requestStop: @escaping @Sendable (String, String?, String) async throws -> OpenClawChatAbortReceipt,
        observe: @escaping @Sendable (String) async -> OpenClawChatStopObservation)
    {
        self.requestStop = requestStop
        self.observe = observe
    }
}

extension OpenClawChatGatewayPayloadCodec {
    public static func decodeAbortReceipt(_ data: Data, runID: String) throws -> OpenClawChatAbortReceipt {
        struct Payload: Decodable {
            let ok: Bool?
            let aborted: Bool?
            let runIds: [String]?
        }
        // Pinned gateway ebe57ef, server-methods/chat-abort-handler.ts. Even
        // aborted:true describes cancellation acceptance, not terminal output.
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.ok == true && payload.aborted == true && payload.runIds?.contains(runID) == true
            ? .requested : .unconfirmed
    }

    public static func decodeStopObservation(_ data: Data) throws -> OpenClawChatStopObservation {
        struct Payload: Decodable {
            let status: String?
            let aborted: Bool?
            let stopReason: String?
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        // The shared codec decides whether the wait response is terminal. Do
        // not reinterpret queue timeouts or absence from history as completion.
        switch try decodeAgentWaitObservation(data) {
        case .checkAgain: return .active
        case .unavailable: return .unavailable
        case .terminal:
            let status = payload.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let reason = payload.stopReason?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return payload.aborted == true || status == "aborted" || reason == "aborted" ? .stopped : .ended
        }
    }
}
