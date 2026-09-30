import Foundation
import Testing
@testable import OpenClawChatUI
import OpenClawProtocol
import OpenClawKit
@testable import Companion

@MainActor
struct ConnectionTests {
    private static let sessionA = "agent:main:session-a"
    private static let sessionB = "agent:main:session-b"

    @Test func previewHistoryIsReadableWithoutDispatchCapability() async {
        let store = ConnectionStore(enablesLaunchFixtures: false)
        store.usePreview()
        await store.loadHistory()
        #expect(store.sessions.count == 1)
        #expect(store.sessions.first?.key == "preview")
        #expect(store.isPreview)
        #expect(store.phase == .disconnected)
        #expect(!store.canSend)
        await store.disconnect()
    }

    @Test(arguments: [OpenClawConversationQuestionScope.all, .unscoped], [false, true])
    func previewQuestionCallbacksStayReadOnlyDespiteSyntheticHealth(scope: OpenClawConversationQuestionScope,
                                                                  skip: Bool) async throws {
        let store = ConnectionStore(enablesLaunchFixtures: false)
        store.usePreview()
        defer { store.model?.detachTransport() }
        let model = try #require(store.model)
        // Preview must remain read-only even with activity's synthetic health,
        // or a mistakenly connected phase. This exercises the real store hook.
        model.healthOK = true
        store.phase = .connected
        let card = try self.addQuestion(to: model, sessionKey: nil)
        #expect(!store.canSend && !model.canPerformQuestionActions)
        let callbacks = OpenClawConversationQuestionsView(viewModel: model, scope: scope)
            .cards(for: .unscoped).actions
        if skip { await callbacks.skip(card) } else { await callbacks.submit(card) }
        #expect(card.status() == .pending)
        #expect(card.otherText["answer"] == "retained question draft")
        #expect(card.errorText == nil)
    }

    @Test(arguments: [OpenClawConversationQuestionScope.all, .currentConversation], [false, true])
    func disconnectedStoreFencesBothCallbacksBeforeTransportHealthUpdates(scope: OpenClawConversationQuestionScope,
                                                                       skip: Bool) async throws {
        let harness = ConnectionHarness(sessionCount: 1)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        let model = try #require(store.model)
        model.healthOK = true
        let card = try self.addQuestion(to: model, sessionKey: model.sessionKey)
        let callbacks = OpenClawConversationQuestionsView(viewModel: model, scope: scope)
            .cards(for: .currentConversation).actions
        #expect(model.canPerformQuestionActions)
        await harness.sessions[0].dropConnection()
        #expect(model.healthOK) // Store callback arrives before the health event.
        #expect(!model.canPerformQuestionActions)
        if skip { await callbacks.skip(card) } else { await callbacks.submit(card) }
        #expect(await harness.sessions[0].transport.questionLeaseRequestCount == 0)
        #expect(card.status() == .pending)
        #expect(card.otherText["answer"] == "retained question draft")
        #expect(card.errorText == nil)
        await store.disconnect()
    }

    private func addQuestion(to model: OpenClawChatViewModel, sessionKey: String?) throws -> OpenClawQuestionCardModel {
        model.upsertQuestion(QuestionRecord(id: "store-question", questions: [Question(questionid: "answer",
            header: "Synthetic", question: "Read-only policy", options: [], isother: true)], agentid: "main",
            sessionkey: sessionKey, createdatms: 1, expiresatms: 4_000_000_000_000, status: .pending))
        let card = try #require(model.questionCards.first)
        card.setOtherText(questionID: "answer", value: "retained question draft")
        return card
    }

    @Test(arguments: [
        ("PAIRING_REQUIRED", "승인"),
        ("AUTH_TOKEN_MISMATCH", "토큰"),
        ("PROTOCOL_MISMATCH", "규격")
    ])
    func structuredConnectionErrorsExplainTheRecovery(detail: String, expected: String) {
        let error = GatewayConnectAuthError(message: "test-only", detailCodeRaw: detail,
            canRetryWithDeviceToken: false)
        #expect(ConnectionStore.connectionError(error).contains(expected))
    }

    @Test func invalidEndpointNeverStartsConnection() {
        let store = ConnectionStore()
        store.endpoint = "http://example.com"
        store.token = "test-only-not-a-credential"
        store.connect()
        #expect(store.phase == .disconnected)
        #expect(store.model == nil)
        #expect(store.errorMessage?.contains("HTTPS") == true)
        #expect(!store.canSend)
    }

    @Test func emptyTokenNeverStartsConnection() {
        let store = ConnectionStore()
        store.endpoint = "https://example.com"
        store.token = " "
        store.connect()
        #expect(store.phase == .disconnected)
        #expect(store.errorMessage?.contains("토큰") == true)
    }

    @Test func repeatedDisconnectClearsSensitiveInput() async {
        let store = ConnectionStore()
        store.token = "test-only-not-a-credential"
        await store.disconnect()
        await store.disconnect()
        #expect(store.token.isEmpty)
        #expect(store.model == nil)
        #expect(store.sessions.isEmpty)
        #expect(!store.canSend)
    }

    @Test func disconnectedTransportRefusesDispatch() async throws {
        let transport = IOSGatewayChatTransport(gateway: GatewayNodeSession())
        do {
            _ = try await transport.sendMessage(sessionKey: "agent:main:main", agentID: nil,
                expectedSessionRoutingContract: nil, message: "test", thinking: "off",
                idempotencyKey: "test-only", attachments: [])
            Issue.record("Disconnected transport reported success")
        } catch OpenClawChatTransportSendError.notDispatched { }
    }

    @Test func canonicalSessionCannotBeReroutedBySelectedAgent() {
        let transport = IOSGatewayChatTransport(gateway: GatewayNodeSession(), globalAgentId: "other")
        #expect(transport.sessionTarget(for: "agent:main:main").sessionKey == "agent:main:main")
        #expect(transport.sessionTarget(for: "conversation").sessionKey == "agent:other:conversation")
    }

    @Test func everySessionDraftSurvivesFailedRetryToNormalizedEndpoint() async throws {
        let harness = ConnectionHarness(sessionCount: 3)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        try seedDrafts(store)
        await harness.sessions[0].dropConnection()

        let failedAttempt = try #require(store.connect())
        await harness.sessions[1].started.wait()
        harness.sessions[1].finish(.failure(ConnectionFixtureError.unavailable))
        await failedAttempt.value
        #expect(store.phase == .failed)
        #expect(store.model == nil)

        // HTTPS and WSS normalize to the same gateway identity.
        store.endpoint = " https://first.example "
        try await harness.connect(store, using: 2)
        try expectDrafts(store)
        await store.disconnect()
    }

    @Test func cancelledRetryKeepsEveryDraftAndTokenAndFencesLateSuccess() async throws {
        let harness = ConnectionHarness(sessionCount: 3)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        try seedDrafts(store)
        await harness.sessions[0].dropConnection()
        store.rememberToken = true
        let cancelled = try #require(store.connect())
        await harness.sessions[1].started.wait()
        await store.cancelConnection()
        await store.cancelConnection()
        #expect(store.phase == .disconnected)
        #expect(store.token == ConnectionHarness.fixtureToken)
        #expect(store.model == nil)
        #expect(harness.savedTokens.isEmpty)

        try await harness.connect(store, using: 2)
        let replacement = try #require(store.model)
        try expectDrafts(store)
        // The fake ignores cancellation and reports success after replacement.
        harness.sessions[1].finish(.success(()))
        await cancelled.value
        await harness.sessions[1].replayConnectedCallback()
        await harness.sessions[1].dropConnection()
        #expect(store.model === replacement)
        #expect(store.phase == .connected)
        #expect(harness.savedTokens.count == 1)
        #expect(harness.savedEndpoints.count == 2)
        await store.disconnect()
    }

    @Test func cancellingBeforeAttemptStartsStillPreservesRetryInput() async throws {
        let harness = ConnectionHarness(sessionCount: 2)
        let store = harness.makeStore()
        let cancelled = try #require(store.connect())
        await store.cancelConnection()
        await cancelled.value
        #expect(store.token == ConnectionHarness.fixtureToken)
        #expect(!harness.sessions[0].started.isOpen)
        try await harness.connect(store, using: 1)
        #expect(store.canSend)
        await store.disconnect()
    }

    @Test func anotherEndpointNeverReceivesRetainedDrafts() async throws {
        let harness = ConnectionHarness(sessionCount: 3)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        try seedDrafts(store)
        await harness.sessions[0].dropConnection()
        store.endpoint = "https://second.example"
        try await harness.connect(store, using: 1)
        let other = try #require(store.model)
        #expect(other.input.isEmpty)
        other.switchSession(to: Self.sessionA)
        #expect(other.input.isEmpty)
        other.switchSession(to: Self.sessionB)
        #expect(other.input.isEmpty)

        await harness.sessions[1].dropConnection()
        store.endpoint = "https://first.example"
        try await harness.connect(store, using: 2)
        let returned = try #require(store.model)
        returned.switchSession(to: Self.sessionA)
        #expect(returned.input.isEmpty)
        await store.disconnect()
    }

    @Test func explicitDisconnectErasesAllDraftsAndInputButKeepsSavedToken() async throws {
        let harness = ConnectionHarness(sessionCount: 2)
        let store = harness.makeStore()
        store.rememberToken = true
        try await harness.connect(store, using: 0)
        try seedDrafts(store)
        await store.disconnect()
        #expect(store.token.isEmpty)
        #expect(store.model == nil)
        #expect(harness.deletedEndpoints.isEmpty)
        store.useSavedToken()
        #expect(store.token == ConnectionHarness.fixtureToken)
        try await harness.connect(store, using: 1)
        let model = try #require(store.model)
        model.switchSession(to: Self.sessionA)
        #expect(model.input.isEmpty)
        model.switchSession(to: Self.sessionB)
        #expect(model.input.isEmpty)
        await store.disconnect()
    }

    @Test func emptiedCurrentDraftDoesNotResurrectOlderSavedText() {
        let transport = ControlledHistoryTransport()
        let original = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        original.input = "old text"
        original.switchSession(to: Self.sessionB)
        original.input = "background text"
        original.switchSession(to: Self.sessionA)
        original.input = ""
        let snapshot = original.captureDraftSnapshot()
        original.detachTransport()
        let restored = OpenClawChatViewModel(sessionKey: "ignored", transport: transport, draftSnapshot: snapshot)
        #expect(restored.currentSessionTarget.sessionKey == Self.sessionA)
        #expect(restored.input.isEmpty)
        restored.switchSession(to: Self.sessionB)
        #expect(restored.input == "background text")
        restored.switchSession(to: Self.sessionA)
        #expect(restored.input.isEmpty)
        restored.detachTransport()
    }

    @Test(arguments: [false, true])
    func tokenRevocationWinsOverDelayedSuccessEvenAfterReoptIn(deleteFails: Bool) async throws {
        let harness = ConnectionHarness(sessionCount: 1)
        harness.deleteFails = deleteFails
        let store = harness.makeStore()
        store.rememberToken = true
        let attempt = try #require(store.connect())
        await harness.sessions[0].started.wait()
        store.forgetToken()
        store.rememberToken = true
        harness.sessions[0].finish(.success(()))
        await attempt.value
        #expect(store.canSend)
        #expect(harness.savedTokens.isEmpty)
        #expect(harness.deletedEndpoints == ["wss://first.example"])
        await store.disconnect()
    }

    @Test func retiredPhysicalRouteCannotPublishFallbackModelAfterMainKeyAwait() async throws {
        let harness = ConnectionHarness(sessionCount: 1)
        let session = harness.sessions[0]
        session.holdsMainKey = true
        session.mainKey = nil
        let store = harness.makeStore()
        store.rememberToken = true
        let attempt = try #require(store.connect())
        await session.started.wait()
        session.finish(.success(()))
        await session.mainKeyStarted.wait()
        session.retirePhysicalRoute()
        session.mainKeyRelease.open()
        await attempt.value
        #expect(store.model == nil)
        #expect(!store.canSend)
        #expect(harness.savedTokens.isEmpty)
        #expect(harness.savedEndpoints.isEmpty)
        await store.disconnect()
    }

    @Test func cancelledMainKeyAwaitCannotPublishIntoReplacement() async throws {
        let harness = ConnectionHarness(sessionCount: 2)
        let old = harness.sessions[0]
        old.holdsMainKey = true
        let store = harness.makeStore()
        store.rememberToken = true
        let cancelled = try #require(store.connect())
        await old.started.wait()
        old.finish(.success(()))
        await old.mainKeyStarted.wait()
        await store.cancelConnection()
        store.endpoint = "https://second.example"
        try await harness.connect(store, using: 1)
        let replacement = try #require(store.model)
        old.mainKeyRelease.open()
        await cancelled.value
        #expect(store.model === replacement)
        #expect(store.endpoint == "wss://second.example")
        #expect(harness.savedTokens.count == 1)
        #expect(harness.savedTokens.first?.endpoint == "wss://second.example")
        await store.disconnect()
    }

    @Test(arguments: [false, true])
    func olderHistoryCompletionCannotReplaceLatestSuccess(oldFails: Bool) async throws {
        let harness = ConnectionHarness(sessionCount: 1)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        let history = harness.sessions[0].transport
        let older = Task { await store.loadHistory() }
        await history.waitForRequestCount(1)
        let latest = Task { await store.loadHistory() }
        await history.waitForRequestCount(2)
        await history.resolve(1, with: .success(try historyResult("latest")))
        await latest.value
        #expect(store.sessions.map(\.key) == ["latest"])
        #expect(!store.isLoadingHistory)
        await history.resolve(0, with: oldFails ? .failure(ConnectionFixtureError.unavailable)
            : .success(try historyResult("old")))
        await older.value
        #expect(store.sessions.map(\.key) == ["latest"])
        #expect(store.historyError == nil)
        #expect(!store.isLoadingHistory)
        await store.disconnect()
    }

    @Test func olderHistoryCannotClearLatestSpinnerAndCancellationCannotPublish() async throws {
        let harness = ConnectionHarness(sessionCount: 1)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        let history = harness.sessions[0].transport
        let older = Task { await store.loadHistory() }
        await history.waitForRequestCount(1)
        let latest = Task { await store.loadHistory() }
        await history.waitForRequestCount(2)
        await history.resolve(0, with: .success(try historyResult("old")))
        await older.value
        #expect(store.isLoadingHistory)
        #expect(store.sessions.isEmpty)
        latest.cancel()
        await history.resolve(1, with: .success(try historyResult("cancelled")))
        await latest.value
        #expect(store.sessions.isEmpty)
        #expect(store.historyError == nil)
        #expect(!store.isLoadingHistory)
        await store.disconnect()
    }

    @Test func disconnectInvalidatesHistoryAndBlocksSessionChanges() async throws {
        let harness = ConnectionHarness(sessionCount: 1)
        let store = harness.makeStore()
        try await harness.connect(store, using: 0)
        let model = try #require(store.model)
        let key = model.currentSessionTarget.sessionKey
        let history = harness.sessions[0].transport
        let pending = Task { await store.loadHistory() }
        await history.waitForRequestCount(1)
        await harness.sessions[0].dropConnection()
        #expect(!store.isLoadingHistory)
        await store.loadHistory()
        let count = await history.requestCount
        #expect(count == 1)
        store.openSession(try #require(historyResult("other").sessions.first))
        store.newConversation()
        #expect(model.currentSessionTarget.sessionKey == key)
        await history.resolve(0, with: .failure(ConnectionFixtureError.unavailable))
        await pending.value
        #expect(store.sessions.isEmpty)
        #expect(store.historyError == nil)
        await store.disconnect()
    }

    @Test func credentialActionsValidateEndpointBeforeStorageAccess() {
        let harness = ConnectionHarness(sessionCount: 0)
        let store = harness.makeStore()
        store.endpoint = "http://example.com"
        store.useSavedToken()
        #expect(store.errorMessage?.contains("HTTPS") == true)
        store.forgetToken()
        #expect(store.errorMessage?.contains("HTTPS") == true)
        #expect(harness.loadedEndpoints.isEmpty)
        #expect(harness.deletedEndpoints.isEmpty)
    }

    private func seedDrafts(_ store: ConnectionStore) throws {
        let model = try #require(store.model)
        model.switchSession(to: Self.sessionA)
        model.input = "  Session A\nunsent text  "
        model.switchSession(to: Self.sessionB)
        model.input = "Session B unsent text"
    }

    private func expectDrafts(_ store: ConnectionStore) throws {
        let model = try #require(store.model)
        #expect(model.currentSessionTarget.sessionKey == Self.sessionB)
        #expect(model.input == "Session B unsent text")
        model.switchSession(to: Self.sessionA)
        #expect(model.input == "  Session A\nunsent text  ")
        model.switchSession(to: Self.sessionB)
        #expect(model.input == "Session B unsent text")
    }
}

private enum ConnectionFixtureError: Error { case unavailable }

@MainActor
private final class ConnectionLatch {
    private(set) var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }
}

@MainActor
private final class ControlledConnectionSession {
    let transport = ControlledHistoryTransport()
    let started = ConnectionLatch()
    let mainKeyStarted = ConnectionLatch()
    let mainKeyRelease = ConnectionLatch()
    private let connectionRelease = ConnectionLatch()
    private var result: Result<Void, any Error> = .success(())
    private var onConnected: ConnectionSession.Callback?
    private var onDisconnected: ConnectionSession.Callback?
    private var routeRevision = 0
    private var hasRoute = false
    var holdsMainKey = false
    var mainKey: String? = "agent:main:main"

    var boundary: ConnectionSession {
        ConnectionSession(connect: { _, _, connected, disconnected in
            self.onConnected = connected
            self.onDisconnected = disconnected
            self.started.open()
            // Deliberately ignores cancellation to exercise the store's fencing.
            await self.connectionRelease.wait()
            try self.result.get()
            self.hasRoute = true
            await connected()
        }, disconnect: {
            self.retirePhysicalRoute()
        }, acquireRoute: {
            guard self.hasRoute else { return nil }
            let capturedRevision = self.routeRevision
            return ConnectionRoute(transport: self.transport, mainSessionKey: {
                self.mainKeyStarted.open()
                if self.holdsMainKey { await self.mainKeyRelease.wait() }
                return self.mainKey
            }, isCurrent: { self.hasRoute && self.routeRevision == capturedRevision })
        })
    }

    func finish(_ result: Result<Void, any Error>) {
        self.result = result
        connectionRelease.open()
    }

    func retirePhysicalRoute() {
        routeRevision += 1
        hasRoute = false
    }

    func dropConnection() async {
        retirePhysicalRoute()
        await onDisconnected?()
    }

    func replayConnectedCallback() async { await onConnected?() }
}

@MainActor
private final class ConnectionHarness {
    static let fixtureToken = "test-only-not-a-credential"
    let sessions: [ControlledConnectionSession]
    private var nextSession = 0
    private var storedTokens: [String: String] = [:]
    var savedTokens: [(token: String, endpoint: String)] = []
    var savedEndpoints: [String] = []
    var loadedEndpoints: [String] = []
    var deletedEndpoints: [String] = []
    var deleteFails = false

    init(sessionCount: Int) {
        sessions = (0..<sessionCount).map { _ in ControlledConnectionSession() }
    }

    func makeStore() -> ConnectionStore {
        let dependencies = ConnectionDependencies(makeSession: {
            let session = self.sessions[self.nextSession]
            self.nextSession += 1
            return session.boundary
        }, saveToken: { token, endpoint in
            self.savedTokens.append((token, endpoint))
            self.storedTokens[endpoint] = token
        }, loadToken: { endpoint in
            self.loadedEndpoints.append(endpoint)
            return self.storedTokens[endpoint]
        }, deleteToken: { endpoint in
            self.deletedEndpoints.append(endpoint)
            if self.deleteFails { throw ConnectionFixtureError.unavailable }
            self.storedTokens[endpoint] = nil
        }, saveEndpoint: { self.savedEndpoints.append($0) })
        let store = ConnectionStore(dependencies: dependencies, enablesLaunchFixtures: false)
        store.endpoint = "https://first.example"
        store.token = Self.fixtureToken
        return store
    }

    func connect(_ store: ConnectionStore, using index: Int) async throws {
        let attempt = try #require(store.connect())
        await sessions[index].started.wait()
        sessions[index].finish(.success(()))
        await attempt.value
        #expect(store.canSend)
    }
}

private actor ControlledHistoryTransport: OpenClawChatTransport {
    private(set) var questionLeaseRequestCount = 0
    func acquireQuestionMutationRouteLease() async -> OpenClawChatQuestionMutationRouteLease? {
        questionLeaseRequestCount += 1
        return nil
    }
    private var pending: [Int: CheckedContinuation<OpenClawChatSessionsListResponse, any Error>] = [:]
    private var startWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private(set) var requestCount = 0

    func waitForRequestCount(_ count: Int) async {
        guard requestCount < count else { return }
        await withCheckedContinuation { startWaiters[count, default: []].append($0) }
    }

    func resolve(_ index: Int, with result: Result<OpenClawChatSessionsListResponse, any Error>) {
        pending.removeValue(forKey: index)?.resume(with: result)
    }

    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        throw ConnectionFixtureError.unavailable
    }

    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        throw ConnectionFixtureError.unavailable
    }

    func listSessions(limit: Int?, search: String?, archived: Bool) async throws -> OpenClawChatSessionsListResponse {
        guard limit == 100 else { return try historyResult() }
        let index = requestCount
        requestCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            for count in Array(startWaiters.keys) where count <= requestCount {
                for waiter in startWaiters.removeValue(forKey: count) ?? [] { waiter.resume() }
            }
        }
    }

    func requestHealth(timeoutMs: Int) async throws -> Bool { false }
    nonisolated func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }
    func setActiveSessionKey(_ sessionKey: String) async throws {}
}

private func historyResult(_ keys: String...) throws -> OpenClawChatSessionsListResponse {
    let data = try JSONSerialization.data(withJSONObject: ["sessions": keys.map { ["key": $0] }])
    return try JSONDecoder().decode(OpenClawChatSessionsListResponse.self, from: data)
}
