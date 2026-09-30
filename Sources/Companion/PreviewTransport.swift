#if DEBUG
import Foundation
import OpenClawChatUI

/// Explicit UI inspection fixture. Never used by normal launches or Release builds.
struct PreviewTransport: OpenClawChatTransport {
    struct Unavailable: LocalizedError { var errorDescription: String? { "미리보기에서는 메시지를 보낼 수 없어요." } }
    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        let json = #"{"sessionKey":"preview","sessionId":"preview","thinkingLevel":"off","messages":[{"role":"user","content":[{"type":"text","text":"오늘은 조금 천천히 시작하고 싶어."}],"timestamp":1790776800000},{"role":"assistant","content":[{"type":"text","text":"좋아요. 지금 가장 마음에 걸리는 일 하나만 꺼내 볼까요?\n\n급하게 정리하지 않아도 괜찮아요."}],"timestamp":1790776801000},{"role":"user","content":[{"type":"text","text":"오후에 할 일을 미리 정리해 둘까?"}],"timestamp":1790776810000},{"role":"assistant","content":[{"type":"text","text":"먼저 꼭 해야 하는 일부터 적어 봐요. 그다음에 하고 싶은 일을 더하면 충분해요."}],"timestamp":1790776811000}]}"#
        return try JSONDecoder().decode(OpenClawChatHistoryPayload.self, from: Data(json.utf8))
    }
    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse { throw Unavailable() }
    func listSessions(limit: Int?, search: String?, archived: Bool) async throws -> OpenClawChatSessionsListResponse {
        let json = #"{"sessions":[{"key":"preview","displayName":"천천히 시작하는 하루","lastMessagePreview":"먼저 꼭 해야 하는 일부터 적어 봐요."}]}"#
        return try JSONDecoder().decode(OpenClawChatSessionsListResponse.self, from: Data(json.utf8))
    }
    func requestHealth(timeoutMs: Int) async throws -> Bool { false }
    func listModels(agentID: String?) async throws -> [OpenClawChatModelChoice] { [] }
    func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }
    func setActiveSessionKey(_ sessionKey: String) async throws {}
}
#endif
