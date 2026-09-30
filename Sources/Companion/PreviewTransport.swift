#if DEBUG
import Foundation
import OpenClawChatUI
import OpenClawProtocol

/// Explicit UI inspection fixture. Never used by normal launches or Release builds.
struct PreviewTransport: OpenClawChatTransport {
    struct Unavailable: LocalizedError { var errorDescription: String? { "미리보기에서는 메시지를 보낼 수 없어요." } }
    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        if ProcessInfo.processInfo.arguments.contains("--ui-artifact-preview") {
            // Synthetic metadata only. No real file, URL request or completed delivery.
            let artifactJSON = #"{"sessionKey":"preview","sessionId":"preview","thinkingLevel":"off","messages":[{"role":"assistant","content":[{"type":"text","text":"파일 표시 확인용 예시예요. 실제 생성된 파일은 아니에요."},{"type":"attachment","attachment":{"kind":"document","label":"검증용 메모.pdf","mimeType":"application/pdf","sizeBytes":1200,"artifactId":"artifact_managed_media_11111111-1111-4111-8111-111111111111"}}]}]}"#
            return try JSONDecoder().decode(OpenClawChatHistoryPayload.self, from: Data(artifactJSON.utf8))
        }
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

/// Render-only synthetic boundary for production activity state transitions.
/// It never contacts a server, and ConnectionStore.canSend remains false.
actor ActivityPreviewTransport: OpenClawChatTransport {
    static let sessionKey = "agent:main:activity-preview"
    private static let runID = "fixture-run-current"
    private let stream: AsyncStream<OpenClawChatTransportEvent>
    private let continuation: AsyncStream<OpenClawChatTransportEvent>.Continuation
    private var stopped = false

    init() {
        let pair = AsyncStream<OpenClawChatTransportEvent>.makeStream()
        stream = pair.stream
        continuation = pair.continuation
    }

    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        let baseline = try await PreviewTransport().requestHistory(sessionKey: sessionKey)
        return OpenClawChatHistoryPayload(sessionKey: Self.sessionKey, sessionId: "fixture-session",
            messages: baseline.messages, thinkingLevel: "off",
            sessionInfo: .init(hasActiveRun: !stopped, activeRunIds: stopped ? [] : [Self.runID],
                               key: Self.sessionKey, agentId: "main"),
            inFlightRun: stopped ? nil : .init(runId: Self.runID, text: "일정 정리 예시를 살펴보고 있어요."))
    }
    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        throw PreviewTransport.Unavailable()
    }
    func listSessions(limit: Int?, search: String?, archived: Bool) async throws -> OpenClawChatSessionsListResponse {
        try await PreviewTransport().listSessions(limit: limit, search: search, archived: archived)
    }
    func requestHealth(timeoutMs: Int) async throws -> Bool { true }
    func listModels(agentID: String?) async throws -> [OpenClawChatModelChoice] { [] }
    nonisolated func events() -> AsyncStream<OpenClawChatTransportEvent> { stream }
    func setActiveSessionKey(_ sessionKey: String) async throws {}
    func gatewayAdvertisesMethod(_ method: String) async -> Bool? {
        ["progressCard.get", "question.list"].contains(method)
    }
    func fetchProgressCard(sessionKey: String, agentID: String?) async throws -> ProgressCard? {
        ProgressCard(sessionkey: Self.sessionKey, revision: 1, updatedat: 1,
            steps: [.init(step: "오늘의 일정 확인", status: .completed),
                    .init(step: "해야 할 일 정리", status: .inProgress),
                    .init(step: "검토할 목록 준비", status: .pending)])
    }
    func acquireRunControlRouteLease() async -> OpenClawChatRunControlRouteLease? {
        .init(requestStop: { [weak self] session, _, run in
            guard let self, session == Self.sessionKey, run == Self.runID else {
                throw OpenClawChatRunControlError.notDispatched
            }
            return try await self.stopFixture()
        }, observe: { [weak self] run in
            guard let self, run == Self.runID else { return .unavailable }
            return await self.stopped ? .stopped : .active
        })
    }
    private func stopFixture() async throws -> OpenClawChatAbortReceipt {
        if ProcessInfo.processInfo.arguments.contains("--ui-stop-failed") {
            throw OpenClawChatRunControlError.notDispatched
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-stop-confirmed") {
            stopped = true
            let data = Data(#"{"sessionKey":"agent:main:activity-preview","runId":"fixture-run-current","state":"aborted"}"#.utf8)
            continuation.yield(.chat(try JSONDecoder().decode(OpenClawChatEventPayload.self, from: data)))
        }
        return .requested
    }
    func listQuestions() async throws -> [QuestionRecord] {
        guard ProcessInfo.processInfo.arguments.contains("--ui-questions") else { return [] }
        return [QuestionRecord(id: "fixture-question", questions: [Question(questionid: "priority", header: "우선순위",
            question: "어떤 일부터 정리할까요?", options: [.init(label: "꼭 해야 할 일"), .init(label: "시간이 남으면 할 일")],
            multiselect: false, isother: true)], agentid: "main", sessionkey: Self.sessionKey, runid: Self.runID,
            createdatms: Int(Date().timeIntervalSince1970 * 1000),
            expiresatms: Int(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000), status: .pending)]
    }
}
#endif
