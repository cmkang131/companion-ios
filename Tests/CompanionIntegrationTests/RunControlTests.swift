import Foundation
import Testing
import OpenClawKit
@testable import OpenClawChatUI
@testable import Companion

@MainActor
struct RunControlTests {
    private static let sessionA = "agent:main:task-a"
    private static let sessionB = "agent:main:task-b"

    @Test func acceptedRequestNeedsExactTerminalAndPreservesComposer() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let attachment = OpenClawPendingAttachment(url: nil, data: Data([1, 3, 5]),
            fileName: "next.txt", mimeType: "text/plain", preview: nil)
        let reply = OpenClawChatReplyTarget(messageID: UUID(), text: "next reply", senderLabel: "Fixture")
        model.input = "next unsent draft"
        model.attachments = [attachment]
        model.replyTarget = reply
        #expect(model.companionRunActivity.canStop)
        let request = try #require(model.requestStopCurrentRuns())
        #expect(model.requestStopCurrentRuns() == nil)
        #expect(model.abort() == nil)
        await transport.waitForStopCount(1)
        #expect(model.companionRunActivity.stopState == .requesting)
        await transport.finishStop(0, result: .success(.requested))
        await request.value
        #expect(model.companionRunActivity.stopState == .requested)
        #expect(model.pendingRunCount == 1)
        #expect(!model.companionRunActivity.canStop)
        terminal("foreign-run", session: Self.sessionA, model: model)
        terminal("run-a", session: Self.sessionB, model: model)
        #expect(model.companionRunActivity.stopState == .requested)
        // Upstream legacy cleanup may use a singleton fallback. The new Stop
        // result must still require the explicit session and run correlation.
        terminal(nil, session: Self.sessionA, model: model)
        #expect(model.companionRunActivity.stopState == .requested)
        terminal("run-a", session: nil, model: model)
        #expect(model.companionRunActivity.stopState == .requested)
        terminal("run-a", session: Self.sessionA, model: model)
        #expect(model.companionRunActivity.stopState == .stopped)
        #expect(model.companionRunCompletionRevision == 0)
        #expect(model.input == "next unsent draft")
        #expect(model.attachments.first?.id == attachment.id)
        #expect(model.attachments.first?.data == Data([1, 3, 5]))
        #expect(model.replyTarget == reply)
        #expect(await transport.stopCount == 1)
        model.detachTransport()
    }

    @Test(arguments: [false, true])
    func failedOrUnconfirmedStopRetriesOnlyByExplicitRequest(knownFailure: Bool) async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        model.input = "preserved"
        model.errorText = "existing composer note"
        let request = try #require(model.abort())
        await transport.waitForStopCount(1)
        await transport.finishStop(0, result: knownFailure
            ? .failure(OpenClawChatRunControlError.notDispatched) : .success(.unconfirmed))
        await request.value
        #expect(model.companionRunActivity.stopState == (knownFailure ? .failed : .unconfirmed))
        #expect(model.companionRunActivity.canStop)
        #expect(model.errorText == "existing composer note")
        #expect(model.input == "preserved")
        #expect(model.pendingRunCount == 1)
        #expect(await transport.stopCount == 1)
        let retry = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(2)
        await transport.finishStop(1, result: .success(.requested))
        await retry.value
        #expect(model.companionRunActivity.stopState == .requested)
        model.detachTransport()
    }

    @Test func immediateNavigationCannotRetargetReservedStop() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let request = try #require(model.requestStopCurrentRuns())
        model.switchSession(to: Self.sessionB)
        announceRun("run-b", model: model)
        model.input = "B draft"
        await request.value
        #expect(await transport.stopCount == 0)
        #expect(model.companionRunActivity.stopState == .idle)
        #expect(!model.isAborting)
        #expect(model.input == "B draft")
        model.detachTransport()
    }

    @Test func oldStopCompletionCannotSettleAnotherConversationRequest() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let oldRequest = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        model.switchSession(to: Self.sessionB)
        announceRun("run-b", model: model)
        let nextRequest = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(2)
        await transport.finishStop(0, result: .success(.requested))
        await oldRequest.value
        #expect(model.isAborting)
        #expect(model.companionRunActivity.stopState == .requesting)
        await transport.finishStop(1, result: .success(.requested))
        await nextRequest.value
        terminal("run-a", session: Self.sessionA, model: model)
        #expect(model.companionRunActivity.stopState == .requested)
        terminal("run-b", session: Self.sessionB, state: "final", model: model)
        #expect(model.companionRunActivity.stopState == .ended)
        #expect(model.companionRunCompletionRevision == 0)
        let calls = await transport.calls
        #expect(calls.map(\.session) == [Self.sessionA, Self.sessionB])
        #expect(calls.map(\.runID) == ["run-a", "run-b"])
        model.detachTransport()
    }

    @Test(arguments: [false, true])
    func detachedOrReplacedRouteCannotAcceptLateStopReceipt(detach: Bool) async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let request = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        if detach { model.detachTransport() }
        else { model.handleTransportEvent(.routeChanged) }
        await transport.finishStop(0, result: .success(.requested))
        await request.value
        #expect(model.companionRunActivity.stopState == (detach ? .idle : .unconfirmed))
        #expect(!model.isAborting)
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    @Test func allCapturedRunsRequireTheirOwnTerminalEvidence() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        model.handleTransportEvent(.sessionMessage(OpenClawSessionMessageEventPayload(
            sessionKey: Self.sessionA, message: nil, messageId: nil, messageSeq: nil,
            hasActiveRun: true, activeRunIds: ["run-a", "run-b"])))
        #expect(model.companionRunActivity.knownRunCount == 2)
        let request = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        terminal("run-a", session: Self.sessionA, model: model)
        await transport.finishStop(0, result: .success(.requested))
        await transport.waitForStopCount(2)
        await transport.finishStop(1, result: .success(.requested))
        await request.value
        #expect(model.companionRunActivity.requestedRunCount == 2)
        #expect(model.companionRunActivity.stopState == .requested)
        terminal("run-b", session: Self.sessionA, model: model)
        #expect(model.companionRunActivity.stopState == .stopped)
        #expect(await transport.calls.map(\.runID) == ["run-a", "run-b"])
        model.detachTransport()
    }

    @Test func localSendWithoutAcknowledgementAndUnknownRunCannotBeStopped() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.updateActiveSessionRunWithoutChatSnapshot(true)
        #expect(model.companionRunActivity.hasActiveRun)
        #expect(model.companionRunActivity.knownRunCount == 0)
        #expect(!model.companionRunActivity.canStop)
        model.updateActiveSessionRunWithoutChatSnapshot(false)
        model.input = "new message"
        let send = try #require(model.send())
        await transport.waitForSend()
        #expect(model.companionRunActivity.hasActiveRun)
        #expect(model.companionRunActivity.knownRunCount == 0)
        #expect(model.requestStopCurrentRuns() == nil)
        try await transport.acknowledgeSend()
        await send.value
        #expect(model.companionRunActivity.knownRunCount == 1)
        #expect(model.companionRunActivity.canStop)
        model.detachTransport()
    }

    @Test func refreshNeedsTypedTerminalAndNeverResendsStop() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let request = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        await transport.finishStop(0, result: .success(.requested))
        await request.value
        await transport.setObservation(.active)
        let firstRefresh = try #require(model.refreshCurrentRunActivity())
        #expect(model.refreshCurrentRunActivity() == nil)
        await firstRefresh.value
        #expect(model.companionRunActivity.stopState == .requested)
        await transport.setObservation(.stopped)
        await model.refreshCurrentRunActivity()?.value
        #expect(model.companionRunActivity.stopState == .stopped)
        #expect(!model.companionRunActivity.hasActiveRun)
        #expect(!model.companionRunActivity.canStop)
        #expect(await transport.stopCount == 1)
        #expect(!model.companionRunActivity.isRefreshing)
        model.detachTransport()
    }

    @Test func confirmedOldStopDoesNotHideAnotherAdvertisedRun() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let first = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        await transport.finishStop(0, result: .success(.requested))
        await first.value
        await transport.setObservation(.stopped)
        await model.refreshCurrentRunActivity()?.value
        #expect(!model.companionRunActivity.hasActiveRun)
        // The upstream pending set remains its own concern. The typed Stop
        // projection excludes only the exactly confirmed run from new requests.
        model.handleTransportEvent(.sessionMessage(OpenClawSessionMessageEventPayload(
            sessionKey: Self.sessionA, message: nil, messageId: nil, messageSeq: nil,
            hasActiveRun: true, activeRunIds: ["run-b"])))
        #expect(model.companionRunActivity.hasActiveRun)
        #expect(model.companionRunActivity.knownRunCount == 1)
        #expect(model.companionRunActivity.stopState == .idle)
        let second = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(2)
        await transport.finishStop(1, result: .success(.requested))
        await second.value
        #expect(await transport.calls.map(\.runID) == ["run-a", "run-b"])
        model.detachTransport()
    }

    @Test func staleOrForeignAgentLifecycleCannotConfirmStop() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        #expect(model.applyLiveRunUsage(runID: "run-a", sequence: 12, outputTokens: 1))
        let request = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        await transport.finishStop(0, result: .success(.requested))
        await request.value
        func event(sequence: Int, session: String) throws -> OpenClawChatTransportEvent {
            .agent(try JSONDecoder().decode(OpenClawAgentEventPayload.self,
                from: JSONSerialization.data(withJSONObject: [
                    "runId": "run-a", "seq": sequence, "stream": "lifecycle",
                    "data": ["phase": "aborted", "sessionKey": session]
                ])))
        }
        model.handleTransportEvent(try event(sequence: 11, session: Self.sessionA))
        #expect(model.companionRunActivity.stopState == .requested)
        model.handleTransportEvent(try event(sequence: 13, session: Self.sessionB))
        #expect(model.companionRunActivity.stopState == .requested)
        model.handleTransportEvent(try event(sequence: 14, session: Self.sessionA))
        #expect(model.companionRunActivity.stopState == .stopped)
        model.detachTransport()
    }

    @Test func cancelledTaskBeforeDispatchDoesNotAbort() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let request = try #require(model.requestStopCurrentRuns())
        request.cancel()
        await request.value
        #expect(await transport.stopCount == 0)
        #expect(model.companionRunActivity.stopState == .failed)
        #expect(!model.isAborting)
        model.detachTransport()
    }

    @Test func cancelledPendingTaskCannotPublishLateAcceptedReceipt() async throws {
        let transport = RunControlTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        announceRun("run-a", model: model)
        let request = try #require(model.requestStopCurrentRuns())
        await transport.waitForStopCount(1)
        request.cancel()
        await transport.finishStop(0, result: .success(.requested))
        await request.value
        #expect(model.companionRunActivity.stopState == .unconfirmed)
        #expect(model.pendingRunCount == 1)
        model.handleTransportEvent(.health(ok: false))
        #expect(!model.companionRunActivity.canStop)
        #expect(model.requestStopCurrentRuns() == nil)
        #expect(await transport.stopCount == 1)
        model.detachTransport()
    }

    @Test(arguments: [
        #"{"ok":true,"aborted":true,"runIds":["run-a"]}"#,
        #"{"ok":true,"aborted":false,"runIds":[]}"#,
        #"{"ok":true,"aborted":true,"runIds":["foreign"]}"#,
        #"{"ok":true}"#
    ])
    func abortReceiptRequiresExactAcceptedRun(payload: String) throws {
        let result = try OpenClawChatGatewayPayloadCodec.decodeAbortReceipt(Data(payload.utf8), runID: "run-a")
        #expect(result == (payload.contains(#"["run-a"]"#) ? .requested : .unconfirmed))
    }

    @Test func waitCodecDistinguishesAbortFromOtherTerminalAndQueueTimeout() throws {
        #expect(try OpenClawChatGatewayPayloadCodec.decodeStopObservation(
            Data(#"{"status":"aborted"}"#.utf8)) == .stopped)
        #expect(try OpenClawChatGatewayPayloadCodec.decodeStopObservation(
            Data(#"{"status":"error","error":"Run aborted"}"#.utf8)) == .ended)
        #expect(try OpenClawChatGatewayPayloadCodec.decodeStopObservation(
            Data(#"{"status":"ok"}"#.utf8)) == .ended)
        #expect(try OpenClawChatGatewayPayloadCodec.decodeStopObservation(
            Data(#"{"status":"timeout","timeoutPhase":"queue"}"#.utf8)) == .active)
    }

    @Test func adapterLeaseRejectsRouteBeforeDispatchAndKeepsExactTarget() async throws {
        let gateway = RunControlGatewayFixture()
        let lease = routeLease(gateway)
        await gateway.setCurrent(false)
        do {
            _ = try await lease.requestStop(Self.sessionA, "main", "run-a")
            Issue.record("Retired route accepted a stop")
        } catch is OpenClawChatRunControlError { }
        #expect(await gateway.requests.isEmpty)
        await gateway.setCurrent(true)
        let request = Task { try await lease.requestStop(Self.sessionA, "main", "run-a") }
        await gateway.waitForRequest()
        let outgoing = try #require(await gateway.requests.first)
        #expect(outgoing.method == "chat.abort")
        #expect(outgoing.params["sessionKey"]?.stringValue == Self.sessionA)
        #expect(outgoing.params["runId"]?.stringValue == "run-a")
        #expect(outgoing.params["discardPendingInput"] == nil)
        await gateway.finish(.success(Data(#"{"ok":true,"aborted":true,"runIds":["run-a"]}"#.utf8)))
        #expect(try await request.value == .requested)
    }

    @Test(arguments: [false, true])
    func adapterLeaseRejectsLatePayloadOrErrorAfterRouteReplacement(error: Bool) async throws {
        let gateway = RunControlGatewayFixture()
        let lease = routeLease(gateway)
        let request = Task { try await lease.requestStop(Self.sessionA, "main", "run-a") }
        await gateway.waitForRequest()
        await gateway.setCurrent(false)
        await gateway.finish(error ? .failure(URLError(.timedOut))
            : .success(Data(#"{"ok":true,"aborted":true,"runIds":["run-a"]}"#.utf8)))
        do {
            _ = try await request.value
            Issue.record("Old route result escaped its lease")
        } catch is CancellationError { }
    }

    @Test func adapterLeaseRejectsReceiptAfterTaskCancellation() async throws {
        let gateway = RunControlGatewayFixture()
        let lease = routeLease(gateway)
        let request = Task { try await lease.requestStop(Self.sessionA, "main", "run-a") }
        await gateway.waitForRequest()
        request.cancel()
        await gateway.finish(.success(Data(#"{"ok":true,"aborted":true,"runIds":["run-a"]}"#.utf8)))
        do {
            _ = try await request.value
            Issue.record("Cancelled operation published an accepted receipt")
        } catch is CancellationError { }
    }

    private func announceRun(_ id: String, model: OpenClawChatViewModel) {
        model.applyTransportHealth(true, refreshSessionsOnReconnect: false)
        model.handleTransportEvent(.chat(OpenClawChatEventPayload(runId: id,
            sessionKey: model.sessionKey, state: "delta", message: nil, errorMessage: nil)))
    }

    private func terminal(_ id: String?, session: String?, state: String = "aborted", model: OpenClawChatViewModel) {
        model.handleTransportEvent(.chat(OpenClawChatEventPayload(runId: id,
            sessionKey: session, state: state, message: nil, errorMessage: nil)))
    }

    private func routeLease(_ fixture: RunControlGatewayFixture) -> OpenClawChatRunControlRouteLease {
        IOSGatewayChatTransport.runControlRouteLease(target: { key, agent in
            IOSGatewayChatTransport.sessionTarget(for: key, selectedAgentID: agent)
        }, isCurrent: { await fixture.current }, request: { try await fixture.request($0) })
    }
}

private actor RunControlTestTransport: OpenClawChatTransport {
    struct Call: Sendable { let session: String; let agent: String?; let runID: String }
    private(set) var calls: [Call] = []
    var stopCount: Int { calls.count }
    private var stops: [Int: CheckedContinuation<OpenClawChatAbortReceipt, any Error>] = [:]
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var observation: OpenClawChatStopObservation = .unavailable
    private var sendContinuation: CheckedContinuation<OpenClawChatSendResponse, any Error>?
    private var sendRunID: String?
    private var sendWaiter: CheckedContinuation<Void, Never>?

    func waitForStopCount(_ count: Int) async {
        guard calls.count < count else { return }
        await withCheckedContinuation { waiters[count, default: []].append($0) }
    }

    func finishStop(_ index: Int, result: Result<OpenClawChatAbortReceipt, any Error>) {
        stops.removeValue(forKey: index)?.resume(with: result)
    }

    func setObservation(_ observation: OpenClawChatStopObservation) { self.observation = observation }

    func acquireRunControlRouteLease() async -> OpenClawChatRunControlRouteLease? {
        OpenClawChatRunControlRouteLease(requestStop: { key, agent, runID in
            try await self.requestStop(key, agent: agent, runID: runID)
        }, observe: { _ in await self.observation })
    }

    private func requestStop(_ key: String, agent: String?, runID: String) async throws -> OpenClawChatAbortReceipt {
        let index = calls.count
        calls.append(Call(session: key, agent: agent, runID: runID))
        return try await withCheckedThrowingContinuation { continuation in
            stops[index] = continuation
            for count in Array(waiters.keys) where count <= calls.count {
                for waiter in waiters.removeValue(forKey: count) ?? [] { waiter.resume() }
            }
        }
    }

    func waitForSend() async {
        guard sendRunID == nil else { return }
        await withCheckedContinuation { sendWaiter = $0 }
    }

    func acknowledgeSend() throws {
        let response = try JSONDecoder().decode(OpenClawChatSendResponse.self,
            from: JSONSerialization.data(withJSONObject: ["runId": sendRunID ?? "", "status": "started"]))
        sendContinuation?.resume(returning: response)
        sendContinuation = nil
    }

    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        sendRunID = idempotencyKey
        return try await withCheckedThrowingContinuation { continuation in
            sendContinuation = continuation
            sendWaiter?.resume()
            sendWaiter = nil
        }
    }

    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        OpenClawChatHistoryPayload(sessionKey: sessionKey, sessionId: nil, messages: [], thinkingLevel: nil)
    }
    func listSessions(limit: Int?, search: String?, archived: Bool) async throws -> OpenClawChatSessionsListResponse {
        OpenClawChatSessionsListResponse(ts: nil, path: nil, count: 0, defaults: nil, sessions: [])
    }
    func requestHealth(timeoutMs: Int) async throws -> Bool { true }
    nonisolated func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }
    func setActiveSessionKey(_ sessionKey: String) async throws {}
}

private actor RunControlGatewayFixture {
    private(set) var current = true
    private(set) var requests: [OpenClawChatGatewayRequest] = []
    private var pending: CheckedContinuation<Data, any Error>?
    private var waiter: CheckedContinuation<Void, Never>?
    func setCurrent(_ value: Bool) { current = value }
    func waitForRequest() async {
        guard requests.isEmpty else { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func request(_ request: OpenClawChatGatewayRequest) async throws -> Data {
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
            waiter?.resume()
            waiter = nil
        }
    }
    func finish(_ result: Result<Data, any Error>) {
        pending?.resume(with: result)
        pending = nil
    }
}
