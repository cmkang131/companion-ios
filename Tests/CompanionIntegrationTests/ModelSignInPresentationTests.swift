import Foundation
import Testing
@testable import OpenClawChatUI

/// Exercises the production presentation and view-model methods against a held
/// transport boundary. No login sheet, account request, or server is opened.
@MainActor
struct ModelSignInPresentationTests {
    @Test func invalidatedOpenCannotReplaceOrClearANewerRequest() async throws {
        let fixture = try SignInFixture()
        defer { fixture.cleanup() }
        let presentation = fixture.presentation
        presentation.perform(.open, viewModel: fixture.model, isEnabled: true)
        try await waitUntil { fixture.gate.contextRequestCount == 1 }

        presentation.invalidate()
        #expect(presentation.context == nil)
        #expect(presentation.action == nil)
        presentation.perform(.open, viewModel: fixture.model, isEnabled: true)
        try await waitUntil { fixture.gate.contextRequestCount == 2 }

        // Cancellation alone does not stop a boundary that has already replied.
        // Hold the newer request until the old cancelled response has returned.
        fixture.gate.finishContext(0, agentID: "retired-agent")
        try await waitUntil { fixture.gate.returnedContextRequests.contains(0) }
        #expect(fixture.gate.cancelledContextRequests.contains(0))
        #expect(presentation.action == .open)
        #expect(presentation.context == nil)
        fixture.gate.finishContext(1, agentID: "current-agent")
        try await waitUntil { presentation.action == nil }
        #expect(presentation.context?.agentID == "current-agent")
        #expect(!presentation.couldNotOpen)

        presentation.invalidate()
        #expect(presentation.context == nil)
    }

    @Test func sessionChangeDiscardsDelayedContextWithoutUnsupportedNotice() async throws {
        let fixture = try SignInFixture()
        defer { fixture.cleanup() }
        fixture.presentation.perform(.open, viewModel: fixture.model, isEnabled: true)
        try await waitUntil { fixture.gate.contextRequestCount == 1 }

        fixture.model.switchSession(to: "agent:main:sign-in-b")
        #expect(fixture.model.sessionKey == "agent:main:sign-in-b")
        fixture.gate.finishContext(0, agentID: "retired-session")
        try await waitUntil { fixture.presentation.action == nil }

        #expect(fixture.presentation.context == nil)
        #expect(!fixture.presentation.couldNotOpen)
    }

    @Test func refreshIsSingleFlightAndCanRunAgainAfterCompletion() async throws {
        let fixture = try SignInFixture()
        defer { fixture.cleanup() }
        fixture.model.modelCatalogMessage = "Awaiting synthetic catalog"
        fixture.presentation.perform(.refresh, viewModel: fixture.model, isEnabled: true)
        fixture.presentation.perform(.refresh, viewModel: fixture.model, isEnabled: true)
        fixture.presentation.perform(.open, viewModel: fixture.model, isEnabled: true)
        try await waitUntil { fixture.gate.catalogRequestCount == 1 }
        #expect(fixture.presentation.action == .refresh)
        #expect(fixture.gate.contextRequestCount == 0)

        fixture.gate.finishCatalog(0)
        try await waitUntil { fixture.presentation.action == nil }
        #expect(fixture.gate.catalogRequestCount == 1)
        #expect(fixture.model.modelCatalogMessage == nil)

        fixture.presentation.perform(.refresh, viewModel: fixture.model, isEnabled: true)
        try await waitUntil { fixture.gate.catalogRequestCount == 2 }
        fixture.gate.finishCatalog(1)
        try await waitUntil { fixture.presentation.action == nil }
        #expect(fixture.gate.contextRequestCount == 0)
        #expect(!fixture.presentation.couldNotOpen)
    }

    @Test func disabledOpenDoesNotRequestAndUnsupportedOpenExplainsFailure() async throws {
        let fixture = try SignInFixture()
        defer { fixture.cleanup() }
        fixture.presentation.perform(.open, viewModel: fixture.model, isEnabled: false)
        #expect(fixture.presentation.action == nil)
        #expect(fixture.gate.contextRequestCount == 0)

        fixture.presentation.perform(.open, viewModel: fixture.model, isEnabled: true)
        try await waitUntil { fixture.gate.contextRequestCount == 1 }
        fixture.gate.finishContext(0, agentID: nil)
        try await waitUntil { fixture.presentation.action == nil }
        #expect(fixture.presentation.context == nil)
        #expect(fixture.presentation.couldNotOpen)
        #expect(fixture.model.errorText?.isEmpty == false)

        fixture.presentation.invalidate()
        #expect(!fixture.presentation.couldNotOpen)
    }

    @Test(arguments: [false, true])
    func cancelledContextCannotChangeNewerErrorOrDraft(returnsContext: Bool) async throws {
        let fixture = try SignInFixture()
        defer { fixture.cleanup() }
        // The presentation regression above verifies invalidate cancels this
        // task. Await the model call directly here to assert after it finishes.
        let request = Task { await fixture.model.modelSignInContext() }
        defer { request.cancel() }
        try await waitUntil { fixture.gate.contextRequestCount == 1 }
        request.cancel()
        fixture.model.errorText = "Newer chat error"
        fixture.model.input = "Draft typed after closing model settings"
        fixture.gate.finishContext(0, agentID: returnsContext ? "retired-agent" : nil)

        let context = await request.value
        #expect(context == nil)
        #expect(fixture.gate.cancelledContextRequests.contains(0))
        #expect(fixture.model.errorText == "Newer chat error")
        #expect(fixture.model.input == "Draft typed after closing model settings")
    }

    @Test(arguments: [false, true])
    func detachedOwnerCannotPublishContextForTheSameSessionKey(returnsContext: Bool) async throws {
        let retired = try SignInFixture()
        let replacement = try SignInFixture()
        defer { retired.cleanup(); replacement.cleanup() }
        let request = Task { await retired.model.modelSignInContext() }
        defer { request.cancel() }
        try await waitUntil { retired.gate.contextRequestCount == 1 }
        retired.model.detachTransport()
        retired.model.errorText = "Retired owner error"
        retired.model.input = "Retired owner draft"
        replacement.model.errorText = "Replacement owner error"
        replacement.model.input = "Replacement owner draft"
        #expect(retired.model.sessionKey == replacement.model.sessionKey)
        retired.gate.finishContext(0, agentID: returnsContext ? "retired-agent" : nil)

        let context = await request.value
        #expect(context == nil)
        #expect(retired.model.errorText == "Retired owner error")
        #expect(retired.model.input == "Retired owner draft")
        #expect(replacement.model.errorText == "Replacement owner error")
        #expect(replacement.model.input == "Replacement owner draft")
        #expect(replacement.gate.contextRequestCount == 0)
    }

    @Test(arguments: [false, true])
    func cancelledRefreshCannotReplaceNewerCatalogNoticeOrDraft(fails: Bool) async throws {
        let fixture = try SignInFixture()
        defer { fixture.cleanup() }
        let request = Task { await fixture.model.refreshModelSignIn() }
        defer { request.cancel() }
        try await waitUntil { fixture.gate.catalogRequestCount == 1 }
        request.cancel()
        fixture.model.modelCatalogMessage = "Newer catalog notice"
        fixture.model.errorText = "Newer chat error"
        fixture.model.input = "Draft typed after cancelling refresh"
        fixture.gate.finishCatalog(0, fails: fails)
        await request.value

        #expect(fixture.model.modelCatalogMessage == "Newer catalog notice")
        #expect(fixture.model.errorText == "Newer chat error")
        #expect(fixture.model.input == "Draft typed after cancelling refresh")
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            try #require(ContinuousClock.now < deadline, "Timed out waiting for the held test boundary")
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

@MainActor
private final class SignInFixture {
    let gate: SignInBoundary
    let presentation = ChatModelSignInPresentation()
    let model: OpenClawChatViewModel
    private let defaultsName: String
    private let defaults: UserDefaults

    init() throws {
        let gate = SignInBoundary()
        let defaultsName = "ModelSignInPresentationTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        self.gate = gate
        self.defaultsName = defaultsName
        self.defaults = defaults
        self.model = OpenClawChatViewModel(
            sessionKey: "agent:main:sign-in-a", transport: SignInTransport(gate: gate),
            modelPickerStore: ChatModelPickerStore(defaults: defaults))
    }

    func cleanup() {
        self.presentation.invalidate()
        self.model.detachTransport()
        self.gate.finishAll()
        self.defaults.removePersistentDomain(forName: self.defaultsName)
    }
}

@MainActor
private final class SignInBoundary {
    private(set) var contextRequestCount = 0
    private(set) var catalogRequestCount = 0
    private(set) var returnedContextRequests: Set<Int> = []
    private(set) var cancelledContextRequests: Set<Int> = []
    private var contexts: [Int: CheckedContinuation<OpenClawChatModelSignInContext?, Never>] = [:]
    private var catalogs: [Int: CheckedContinuation<OpenClawChatModelCatalogSnapshot, any Error>] = [:]

    func context() async -> OpenClawChatModelSignInContext? {
        let index = self.contextRequestCount
        self.contextRequestCount += 1
        let result = await withCheckedContinuation { self.contexts[index] = $0 }
        self.returnedContextRequests.insert(index)
        if Task.isCancelled { self.cancelledContextRequests.insert(index) }
        return result
    }

    func catalog() async throws -> OpenClawChatModelCatalogSnapshot {
        let index = self.catalogRequestCount
        self.catalogRequestCount += 1
        return try await withCheckedThrowingContinuation { self.catalogs[index] = $0 }
    }

    func finishContext(_ index: Int, agentID: String?) {
        let context = agentID.map { agentID in
            OpenClawChatModelSignInContext(agentID: agentID, request: { _, _ in
                Issue.record("Presentation tests must not perform account requests")
                throw CancellationError()
            }, isCurrent: { true })
        }
        self.contexts.removeValue(forKey: index)?.resume(returning: context)
    }

    func finishCatalog(_ index: Int, fails: Bool = false) {
        guard let continuation = self.catalogs.removeValue(forKey: index) else { return }
        if fails {
            continuation.resume(throwing: URLError(.cannotConnectToHost))
        } else {
            continuation.resume(returning:
                OpenClawChatModelCatalogSnapshot(choices: [], availabilityIsSessionScoped: true))
        }
    }

    func finishAll() {
        for index in Array(self.contexts.keys) { self.finishContext(index, agentID: nil) }
        for index in Array(self.catalogs.keys) { self.finishCatalog(index) }
    }
}

private struct SignInTransport: OpenClawChatTransport {
    let gate: SignInBoundary

    func acquireModelSignInContext(agentID: String?) async -> OpenClawChatModelSignInContext? {
        await self.gate.context()
    }

    func loadModelCatalog(sessionKey: String, agentID: String?) async throws -> OpenClawChatModelCatalogSnapshot {
        try await self.gate.catalog()
    }

    func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }
    func requestHealth(timeoutMs: Int) async throws -> Bool { throw CancellationError() }
    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload { throw CancellationError() }
    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        Issue.record("Presentation tests must not send chat messages")
        throw CancellationError()
    }
}
