import Foundation
import Testing
import OpenClawKit
@testable import OpenClawChatUI
@testable import Companion

@MainActor
struct AttachmentSnapshotTests {
    private static let session = "agent:main:attachment-draft"

    @Test func selectedAttachmentBytesReplyAndTextSurviveFailedAndCancelledRetries() async throws {
        let fixture = AttachmentSnapshotFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        let attachments = [attachment("one.txt", [1, 2]), attachment("two.txt", [3, 4])]
        let reply = replyTarget("original reply")
        original.input = "  unsubmitted text\nwith spacing  "
        original.attachments = attachments
        original.replyTarget = reply
        await fixture.dropConnection(0)
        fixture.failingConnections.insert(1)
        await store.connect()?.value
        #expect(store.phase == .failed)
        #expect(store.model == nil)
        let cancelled = try #require(store.connect())
        await store.cancelConnection()
        await cancelled.value
        #expect(store.model == nil)
        await store.connect()?.value
        let restored = try #require(store.model)
        #expect(restored.input == "  unsubmitted text\nwith spacing  ")
        #expect(restored.replyTarget == reply)
        #expect(restored.attachments.map(\.id) == attachments.map(\.id))
        #expect(restored.attachments.map(\.data) == [Data([1, 2]), Data([3, 4])])
        #expect(restored.interruptedAttachmentSessionKeys.isEmpty)
        #expect(restored.isAttachmentOwnerPinned)
        restored.switchSession(to: "agent:main:another")
        #expect(restored.sessionKey == Self.session)
        #expect(restored.attachments.map(\.id) == attachments.map(\.id))
        await store.disconnect()
    }

    @Test(arguments: [false, true])
    func otherEndpointAndExplicitDisconnectNeverRestoreSelectedAttachments(otherEndpoint: Bool) async throws {
        let fixture = AttachmentSnapshotFixture()
        let store = fixture.store()
        await store.connect()?.value
        let model = try #require(store.model)
        model.input = "private to original endpoint"
        model.attachments = [attachment("original.txt", [1])]
        model.replyTarget = replyTarget("original reply")
        if otherEndpoint {
            await fixture.dropConnection(0)
            store.endpoint = "https://second.example"
        } else {
            await store.disconnect()
            store.token = "test-only-not-a-credential"
        }
        await store.connect()?.value
        let replacement = try #require(store.model)
        #expect(replacement.input.isEmpty)
        #expect(replacement.attachments.isEmpty)
        #expect(replacement.replyTarget == nil)
        #expect(replacement.interruptedAttachmentSessionKeys.isEmpty)
        await store.disconnect()
    }

    @Test func interruptedRealImportKeepsReadyBytesAndNeverOverwritesReplacementDraft() async throws {
        let fixture = AttachmentSnapshotFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        let ready = attachment("ready.txt", [7, 8])
        original.input = "text with ready attachment"
        original.attachments = [ready]
        original.replyTarget = replyTarget("reply with ready attachment")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".txt")
        try Data("late imported bytes".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        await fixture.transports[0].holdAttachmentLimits()
        original.beginAttachmentStaging()
        let staging = Task {
            defer { original.endAttachmentStaging() }
            await original.loadAttachments(urls: [file])
        }
        await fixture.transports[0].waitForAttachmentLimits()
        await fixture.dropConnection(0)
        await store.connect()?.value
        let replacement = try #require(store.model)
        #expect(replacement.interruptedAttachmentSessionKeys == [Self.session])
        #expect(replacement.attachments.map(\.id) == [ready.id])
        #expect(replacement.attachments.first?.data == Data([7, 8]))
        #expect(replacement.attachmentStagingCount == 0)
        #expect(replacement.replyTarget == original.replyTarget)

        let newer = attachment("newer.txt", [9])
        let newerReply = replyTarget("new reply")
        replacement.input = "newer draft"
        replacement.attachments = [newer]
        replacement.replyTarget = newerReply
        await fixture.transports[0].releaseAttachmentLimits()
        await staging.value
        // Completion belongs to the retired presentation, not to its snapshot.
        #expect(original.attachments.count == 2)
        #expect(replacement.attachments.map(\.id) == [newer.id])
        #expect(replacement.input == "newer draft")
        #expect(replacement.replyTarget == newerReply)
        #expect(store.interruptedAttachmentSessionKeys == [Self.session])
        replacement.acknowledgeInterruptedAttachmentSelection(sessionKey: Self.session)
        #expect(store.interruptedAttachmentSessionKeys.isEmpty)
        #expect(replacement.attachments.map(\.id) == [newer.id])
        await store.disconnect()
    }

    @Test func missingImportBytesProduceOfflineNoticeAcrossFailedAndCancelledRetries() async throws {
        let fixture = AttachmentSnapshotFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        original.input = "no attachment bytes yet"
        original.beginAttachmentStaging()
        defer { original.endAttachmentStaging() }
        await fixture.dropConnection(0)
        fixture.failingConnections.insert(1)
        await store.connect()?.value
        #expect(store.model == nil)
        #expect(store.interruptedAttachmentSessionKeys == [Self.session])
        let cancelled = try #require(store.connect())
        await store.cancelConnection()
        await cancelled.value
        #expect(store.interruptedAttachmentSessionKeys == [Self.session])
        store.endpoint = "https://another.example"
        #expect(store.interruptedAttachmentSessionKeys.isEmpty)
        store.endpoint = "https://first.example"
        #expect(store.interruptedAttachmentSessionKeys == [Self.session])
        await store.connect()?.value
        let replacement = try #require(store.model)
        #expect(replacement.attachments.isEmpty)
        #expect(replacement.input == "no attachment bytes yet")
        #expect(replacement.interruptedAttachmentSessionKeys == [Self.session])
        await store.disconnect()
        #expect(store.interruptedAttachmentSessionKeys.isEmpty)
    }

    @Test func interruptedCaptureOwnerIsReportedWithoutInventingAttachmentBytes() {
        let transport = AttachmentSnapshotTransport()
        let original = OpenClawChatViewModel(sessionKey: Self.session, transport: transport,
            attachmentOwnerIsActive: { true })
        let snapshot = original.captureDraftSnapshot()
        original.detachTransport()
        let replacement = OpenClawChatViewModel(sessionKey: "ignored", transport: transport, draftSnapshot: snapshot)
        #expect(replacement.attachments.isEmpty)
        #expect(replacement.interruptedAttachmentSessionKeys == [Self.session])
        #expect(!replacement.isAttachmentOwnerPinned)
        replacement.detachTransport()
    }

    @Test(arguments: [false, true])
    func submittedReplyDoesNotReappearAfterLateAckOrOverwriteNewComposer(hasNewDraft: Bool) async throws {
        let transport = AttachmentSnapshotTransport()
        let original = OpenClawChatViewModel(sessionKey: Self.session, transport: transport)
        original.input = "submitted reply"
        original.replyTarget = replyTarget("quoted original")
        let send = try #require(original.send())
        await transport.waitForSend()
        let snapshot = original.captureDraftSnapshot()
        original.detachTransport()
        let replacement = OpenClawChatViewModel(sessionKey: "ignored", transport: transport, draftSnapshot: snapshot)
        #expect(replacement.replyTarget == nil)
        let newAttachment = attachment("new.txt", [4, 5])
        let newReply = replyTarget("newer quote")
        if hasNewDraft {
            replacement.input = "newer text"
            replacement.attachments = [newAttachment]
            replacement.replyTarget = newReply
        }
        try await transport.acceptSend()
        await send.value
        #expect(replacement.currentSendRecoveries.isEmpty)
        #expect(replacement.input == (hasNewDraft ? "newer text" : ""))
        #expect(replacement.attachments.map(\.id) == (hasNewDraft ? [newAttachment.id] : []))
        #expect(replacement.replyTarget == (hasNewDraft ? newReply : nil))
        replacement.detachTransport()
    }

    private func attachment(_ name: String, _ bytes: [UInt8]) -> OpenClawPendingAttachment {
        OpenClawPendingAttachment(url: nil, data: Data(bytes), fileName: name,
            mimeType: "text/plain", preview: nil)
    }

    private func replyTarget(_ text: String) -> OpenClawChatReplyTarget {
        OpenClawChatReplyTarget(messageID: UUID(), text: text, senderLabel: "Fixture")
    }
}

@MainActor
private final class AttachmentSnapshotFixture {
    let transports = (0..<4).map { _ in AttachmentSnapshotTransport() }
    var failingConnections: Set<Int> = []
    private var nextSession = 0
    private var callbacks: [Int: ConnectionSession.Callback] = [:]

    func store() -> ConnectionStore {
        let dependencies = ConnectionDependencies(makeSession: {
            let index = self.nextSession
            self.nextSession += 1
            return ConnectionSession(connect: { _, _, connected, disconnected in
                if self.failingConnections.contains(index) { throw URLError(.cannotConnectToHost) }
                self.callbacks[index] = disconnected
                await connected()
            }, disconnect: {}, acquireRoute: {
                ConnectionRoute(transport: self.transports[index],
                    mainSessionKey: { "agent:main:attachment-draft" }, isCurrent: { true })
            })
        }, saveToken: { _, _ in Issue.record("Unexpected credential write") },
            loadToken: { _ in Issue.record("Unexpected credential read"); return nil },
            deleteToken: { _ in Issue.record("Unexpected credential deletion") }, saveEndpoint: { _ in })
        let store = ConnectionStore(dependencies: dependencies, enablesLaunchFixtures: false)
        store.endpoint = "https://first.example"
        store.token = "test-only-not-a-credential"
        return store
    }

    func dropConnection(_ index: Int) async { await callbacks[index]?() }
}

private actor AttachmentSnapshotTransport: OpenClawChatTransport {
    private var holdsLimits = false
    private var limitsRequested = false
    private var limitsStarted: CheckedContinuation<Void, Never>?
    private var limitsRelease: CheckedContinuation<Void, Never>?
    private var sendStarted: CheckedContinuation<Void, Never>?
    private var pendingSend: CheckedContinuation<OpenClawChatSendResponse, any Error>?
    private var sentRunID: String?

    func holdAttachmentLimits() { holdsLimits = true }
    func waitForAttachmentLimits() async {
        if !limitsRequested { await withCheckedContinuation { limitsStarted = $0 } }
    }
    func releaseAttachmentLimits() { holdsLimits = false; limitsRelease?.resume(); limitsRelease = nil }
    func attachmentLimits() async -> GatewayAttachmentLimits? {
        limitsRequested = true
        limitsStarted?.resume()
        limitsStarted = nil
        if holdsLimits { await withCheckedContinuation { limitsRelease = $0 } }
        return nil
    }

    func waitForSend() async {
        if sentRunID == nil { await withCheckedContinuation { sendStarted = $0 } }
    }
    func acceptSend() throws {
        let response = try JSONDecoder().decode(OpenClawChatSendResponse.self,
            from: JSONSerialization.data(withJSONObject: ["runId": sentRunID ?? "", "status": "ok"]))
        pendingSend?.resume(returning: response)
        pendingSend = nil
    }
    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        sentRunID = idempotencyKey
        return try await withCheckedThrowingContinuation { continuation in
            pendingSend = continuation
            sendStarted?.resume()
            sendStarted = nil
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
