import Foundation
import Testing
import OpenClawKit
@testable import OpenClawChatUI
@testable import Companion

@MainActor
struct SendRecoveryTests {
    private static let sessionA = "agent:main:session-a"
    private static let sessionB = "agent:main:session-b"

    @Test(arguments: [false, true])
    func failureAfterNavigationRetainsOriginalInItsSession(newConversation: Bool) async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let model = try #require(store.model)
        model.input = "  submitted A\noriginal spacing  "
        let send = try #require(model.send())
        await fixture.transports[0].waitForSendCount(1)
        if newConversation { store.newConversation() }
        else { store.openSession(try sessionEntry(Self.sessionB)) }
        let nextKey = model.sessionKey
        #expect(nextKey != Self.sessionA)
        model.input = "new B draft"
        await fixture.transports[0].finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        #expect(model.input == "new B draft")
        #expect(model.currentSendRecoveries.isEmpty)
        store.openSession(try sessionEntry(Self.sessionA))
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(recovery.text == "  submitted A\noriginal spacing  ")
        #expect(recovery.delivery == .notSent)
        #expect(recovery.canRestore)
        #expect(model.restoreSendRecovery(id: recovery.id))
        #expect(model.input == recovery.text)
        #expect(await fixture.transports[0].sendCount == 1)
        store.openSession(try sessionEntry(nextKey))
        #expect(model.input == "new B draft")
        await store.disconnect()
    }

    @Test func recoveryOpensUnlistedNewSessionAndRestoresAttachmentWithOriginalKey() async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let model = try #require(store.model)
        store.newConversation()
        let originalSession = model.sessionKey
        let attachment = OpenClawPendingAttachment(url: nil, data: Data([2, 4, 6]),
            fileName: "unsent.txt", mimeType: "text/plain", preview: nil)
        let reply = OpenClawChatReplyTarget(messageID: UUID(), text: "original reply", senderLabel: "Fixture")
        model.input = "  never listed by server\n"
        model.attachments = [attachment]
        model.replyTarget = reply
        let send = try #require(model.send())
        await fixture.transports[0].waitForSendCount(1)
        let runID = await fixture.transports[0].sentKey(0)
        await fixture.transports[0].finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        store.newConversation()
        let newerSession = model.sessionKey
        #expect(newerSession != originalSession)
        model.input = "newer conversation draft"
        await store.loadHistory()
        #expect(store.sessions.isEmpty)
        #expect(store.retainedSendRecoveries.first?.sessionKey == originalSession)
        #expect(store.openSendRecovery(id: runID))
        #expect(model.sessionKey == originalSession)
        #expect(model.currentSendRecoveries.first?.id == runID)
        #expect(model.input.isEmpty)
        #expect(model.canRestoreSendRecovery(id: runID))
        #expect(model.restoreSendRecovery(id: runID))
        #expect(model.input == "  never listed by server\n")
        #expect(model.attachments.first?.id == attachment.id)
        #expect(model.attachments.first?.data == Data([2, 4, 6]))
        #expect(model.replyTarget == reply)
        #expect(await fixture.transports[0].sendCount == 1)

        let explicitRetry = try #require(model.send())
        await fixture.transports[0].waitForSendCount(2)
        #expect(await fixture.transports[0].sentKey(1) == runID)
        await fixture.transports[0].finishSend(1, with: .success(try sendResponse(id: runID, status: "ok")))
        await explicitRetry.value
        #expect(store.retainedSendRecoveries.isEmpty)
        #expect(!store.openSendRecovery(id: runID))
        store.openSession(try sessionEntry(newerSession))
        #expect(model.input == "newer conversation draft")
        await store.disconnect()
    }

    @Test func recoveryNavigationHonorsEndpointConnectionAndAttachmentGuards() async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let model = try #require(store.model)
        model.input = "retained in A"
        let send = try #require(model.send())
        await fixture.transports[0].waitForSendCount(1)
        let runID = await fixture.transports[0].sentKey(0)
        await fixture.transports[0].finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        store.openSession(try sessionEntry(Self.sessionB))
        model.input = "B draft"
        #expect(!store.openSendRecovery(id: "unknown-recovery"))
        for endpoint in ["https://other.example", "not an endpoint"] {
            store.endpoint = endpoint
            #expect(!store.openSendRecovery(id: runID))
            #expect(model.sessionKey == Self.sessionB)
            #expect(model.input == "B draft")
        }
        store.endpoint = "https://first.example"
        let newerAttachment = OpenClawPendingAttachment(url: nil, data: Data([9]),
            fileName: "B.txt", mimeType: "text/plain", preview: nil)
        model.attachments = [newerAttachment]
        #expect(!store.openSendRecovery(id: runID))
        #expect(model.sessionKey == Self.sessionB)
        #expect(model.attachments.first?.id == newerAttachment.id)
        model.removeAttachment(newerAttachment.id)
        model.beginAttachmentStaging()
        #expect(!store.openSendRecovery(id: runID))
        #expect(model.sessionKey == Self.sessionB)
        model.endAttachmentStaging()
        await fixture.dropConnection(0)
        #expect(!store.openSendRecovery(id: runID))
        #expect(model.sessionKey == Self.sessionB)
        #expect(model.input == "B draft")
        await store.connect()?.value
        #expect(store.openSendRecovery(id: runID))
        #expect(store.model?.sessionKey == Self.sessionA)
        await store.disconnect()
        #expect(!store.openSendRecovery(id: runID))
    }

    @Test func failureNeverOverwritesNewerComposerDraft() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "first submitted draft"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        model.input = "newer unsent draft"
        await transport.finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(!model.restoreSendRecovery(id: recovery.id))
        #expect(model.input == "newer unsent draft")
        #expect(model.currentSendRecoveries.first?.text == "first submitted draft")
        model.detachTransport()
    }

    @Test func reconnectKeepsUnconfirmedSendUntilHistoryReviewAndExplicitRestore() async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        original.input = "submitted before disconnect"
        let send = try #require(original.send())
        await fixture.transports[0].waitForSendCount(1)
        await fixture.dropConnection(0)
        await store.connect()?.value
        let replacement = try #require(store.model)
        let pending = try #require(replacement.currentSendRecoveries.first)
        #expect(pending.delivery == .unconfirmed)
        #expect(pending.isAwaitingAcknowledgement)
        #expect(!replacement.restoreSendRecovery(id: pending.id))
        await fixture.transports[0].finishSend(0, with: .failure(URLError(.networkConnectionLost)))
        await send.value
        let failed = try #require(replacement.currentSendRecoveries.first)
        #expect(!failed.isAwaitingAcknowledgement)
        #expect(!failed.canRestore)
        #expect(await replacement.refreshSendRecoveryHistory())
        #expect(replacement.currentSendRecoveries.first?.delivery == .unconfirmed)
        #expect(replacement.restoreSendRecovery(id: failed.id))
        #expect(replacement.input == "submitted before disconnect")
        #expect(await fixture.transports[1].sendCount == 0)

        // Only this explicit new send dispatches, retaining the original key.
        let retried = try #require(replacement.send())
        await fixture.transports[1].waitForSendCount(1)
        #expect(await fixture.transports[1].sentKey(0) == failed.id)
        await fixture.transports[1].finishSend(0, with: .success(try sendResponse(id: failed.id, status: "ok")))
        await retried.value
        #expect(replacement.input.isEmpty)
        #expect(replacement.currentSendRecoveries.isEmpty)
        await store.disconnect()
    }

    @Test func lateAcceptedAckRemovesTransferredRecoveryWithoutTouchingNewDraft() async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        original.input = "accepted by server"
        let send = try #require(original.send())
        await fixture.transports[0].waitForSendCount(1)
        let runID = await fixture.transports[0].sentKey(0)
        await fixture.dropConnection(0)
        await store.connect()?.value
        let replacement = try #require(store.model)
        replacement.input = "new local draft"
        #expect(replacement.currentSendRecoveries.count == 1)
        await fixture.transports[0].finishSend(0, with: .success(try sendResponse(id: runID, status: "ok")))
        await send.value
        #expect(replacement.currentSendRecoveries.isEmpty)
        #expect(replacement.input == "new local draft")
        #expect(!replacement.restoreSendRecovery(id: runID))
        #expect(replacement.companionRunCompletionRevision == 0)
        await store.disconnect()
    }

    @Test(arguments: ["ok", "started", "accepted", "in_flight"])
    func acceptedAckAfterSessionSwitchNeverResurrectsSubmittedText(status: String) async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "accepted text"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        model.switchSession(to: Self.sessionB)
        model.input = "B draft"
        let runID = await transport.sentKey(0)
        await transport.finishSend(0, with: .success(try sendResponse(id: runID, status: status)))
        await send.value
        model.switchSession(to: Self.sessionA)
        #expect(model.currentSendRecoveries.isEmpty)
        #expect(model.input.isEmpty)
        model.switchSession(to: Self.sessionB)
        #expect(model.input == "B draft")
        model.detachTransport()
    }

    @Test(arguments: ["error", "timeout"])
    func terminalFailureAckRetainsTextAndRemainsUncertain(status: String) async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "terminal failure draft"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        let runID = await transport.sentKey(0)
        await transport.finishSend(0, with: .success(try sendResponse(id: runID, status: status)))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(recovery.text == "terminal failure draft")
        #expect(recovery.delivery == .unconfirmed)
        #expect(!recovery.canRestore)
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    @Test(arguments: ["", "pending", "queued", "future_status", "OK", " started "])
    func unsupportedAckRetainsTextAttachmentsAndReplyWithoutSuccess(status: String) async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport,
            haptics: OpenClawChatHaptics { event in
                if event == .messageSent || event == .runCompleted {
                    Issue.record("Unsupported acknowledgement produced a success haptic")
                }
            })
        let attachment = OpenClawPendingAttachment(url: nil, data: Data([10, 20, 30]),
            fileName: "retained.txt", mimeType: "text/plain", preview: nil)
        let reply = OpenClawChatReplyTarget(messageID: UUID(), text: "reply context", senderLabel: "Fixture")
        model.input = "  uncertain original\n"
        model.attachments = [attachment]
        model.replyTarget = reply
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        let runID = await transport.sentKey(0)
        await transport.finishSend(0, with: .success(try sendResponse(id: "untrusted-remote-run", status: status)))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(recovery.id == runID)
        #expect(recovery.text == "  uncertain original\n")
        #expect(recovery.attachmentCount == 1)
        #expect(recovery.delivery == .unconfirmed)
        #expect(!recovery.isAwaitingAcknowledgement)
        #expect(!recovery.canRestore)
        #expect(model.pendingRuns.isEmpty)
        #expect(model.replyTarget == reply)
        #expect(model.companionRunCompletionRevision == 0)
        #expect(await model.refreshSendRecoveryHistory())
        #expect(model.restoreSendRecovery(id: runID))
        #expect(model.input == recovery.text)
        #expect(model.attachments.first?.id == attachment.id)
        #expect(model.attachments.first?.data == Data([10, 20, 30]))
        #expect(model.replyTarget == reply)
        #expect(await transport.sendCount == 1)
        model.detachTransport()
    }

    @Test func cancelledSendRetainsUnconfirmedDraftAndDoesNotReplay() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "cancelled RPC original"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        send.cancel()
        await transport.finishSend(0, with: .failure(CancellationError()))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(recovery.text == "cancelled RPC original")
        #expect(recovery.delivery == .unconfirmed)
        #expect(!recovery.isAwaitingAcknowledgement)
        #expect(!model.restoreSendRecovery(id: recovery.id))
        #expect(await transport.sendCount == 1)
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    @Test func recoveryCannotOverwriteNewReplySelection() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        let originalReply = OpenClawChatReplyTarget(messageID: UUID(), text: "original reply", senderLabel: "Fixture")
        let newerReply = OpenClawChatReplyTarget(messageID: UUID(), text: "newer reply", senderLabel: "Fixture")
        model.input = "original text"
        model.replyTarget = originalReply
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        model.replyTarget = newerReply
        await transport.finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(!model.canRestoreSendRecovery(id: recovery.id))
        #expect(!model.restoreSendRecovery(id: recovery.id))
        #expect(model.input.isEmpty)
        #expect(model.replyTarget == newerReply)
        model.replyTarget = nil
        #expect(model.canRestoreSendRecovery(id: recovery.id))
        #expect(model.restoreSendRecovery(id: recovery.id))
        #expect(model.replyTarget == originalReply)
        #expect(model.input == "original text")
        model.detachTransport()
    }

    @Test func recoveryEligibilityAllowsOriginalReplyAndRechecksNewerDraft() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        let originalReply = OpenClawChatReplyTarget(messageID: UUID(), text: "original reply", senderLabel: "Fixture")
        model.input = "original text"
        model.replyTarget = originalReply
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        await transport.finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(model.replyTarget == originalReply)
        #expect(model.canRestoreSendRecovery(id: recovery.id))
        // Eligibility may change between drawing the button and tapping it.
        model.input = "newer draft"
        #expect(!model.restoreSendRecovery(id: recovery.id))
        #expect(!model.canRestoreSendRecovery(id: recovery.id))
        #expect(model.input == "newer draft")
        #expect(model.replyTarget == originalReply)
        model.input = ""
        #expect(model.canRestoreSendRecovery(id: recovery.id))
        #expect(model.restoreSendRecovery(id: recovery.id))
        #expect(model.input == "original text")
        #expect(model.replyTarget == originalReply)
        #expect(!model.canRestoreSendRecovery(id: recovery.id))
        #expect(!model.restoreSendRecovery(id: recovery.id))
        model.detachTransport()
    }

    @Test func editingRestoredDraftUsesNewDeduplicationKey() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "original text"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        let firstID = await transport.sentKey(0)
        await transport.finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        #expect(model.restoreSendRecovery(id: firstID))
        model.input = "edited text"
        let retry = try #require(model.send())
        await transport.waitForSendCount(2)
        let secondID = await transport.sentKey(1)
        #expect(secondID != firstID)
        await transport.finishSend(1, with: .success(try sendResponse(id: secondID, status: "ok")))
        await retry.value
        #expect(model.currentSendRecoveries.isEmpty)
        #expect(model.input.isEmpty)
        #expect(await transport.sendCount == 2)
        model.detachTransport()
    }

    @Test func failedHistoryCheckCannotAuthorizeUncertainRestoration() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "possibly delivered"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        await transport.finishSend(0, with: .failure(URLError(.timedOut)))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        await transport.setHistoryFailure(true)
        #expect(!(await model.refreshSendRecoveryHistory()))
        #expect(!model.restoreSendRecovery(id: recovery.id))
        #expect(model.currentSendRecoveries.first?.hasCheckedHistory == false)
        model.detachTransport()
    }

    @Test func onlyCanonicalMatchingUserHistoryRetiresUnconfirmedSend() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "matching text alone is not proof"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        let runID = await transport.sentKey(0)
        await transport.finishSend(0, with: .failure(URLError(.timedOut)))
        await send.value
        await transport.setHistoryMessages(try JSONSerialization.data(withJSONObject: [
            ["role": "user", "content": [["type": "text", "text": "matching text alone is not proof"]]],
            ["role": "assistant", "idempotencyKey": "\(runID):user", "content": []]
        ]))
        #expect(await model.refreshSendRecoveryHistory())
        #expect(model.currentSendRecoveries.count == 1)
        await transport.setHistoryMessages(try JSONSerialization.data(withJSONObject: [
            ["role": "user", "idempotencyKey": "\(runID):user",
             "content": [["type": "text", "text": "matching text alone is not proof"]]]
        ]))
        model.input = "newer draft"
        #expect(await model.refreshSendRecoveryHistory())
        #expect(model.currentSendRecoveries.isEmpty)
        #expect(model.input == "newer draft")
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    @Test func failedAttachmentSendRetainsBytesAndDoesNotOverwriteNewAttachment() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        let original = OpenClawPendingAttachment(url: nil, data: Data([1, 2, 3]),
            fileName: "original.txt", mimeType: "text/plain", preview: nil)
        model.input = "original with attachment"
        model.attachments = [original]
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        let newer = OpenClawPendingAttachment(url: nil, data: Data([4]),
            fileName: "new.txt", mimeType: "text/plain", preview: nil)
        model.attachments = [newer]
        await transport.finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await send.value
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(recovery.attachmentCount == 1)
        #expect(!model.restoreSendRecovery(id: recovery.id))
        #expect(model.attachments.first?.id == newer.id)
        model.removeAttachment(newer.id)
        #expect(model.restoreSendRecovery(id: recovery.id))
        #expect(model.attachments.first?.id == original.id)
        #expect(model.attachments.first?.data == Data([1, 2, 3]))
        #expect(model.input == "original with attachment")
        model.detachTransport()
    }

    @Test func endpointReplacementCannotImportOrReviveOldRecovery() async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        original.input = "first endpoint only"
        let send = try #require(original.send())
        await fixture.transports[0].waitForSendCount(1)
        await fixture.dropConnection(0)
        store.endpoint = "https://second.example"
        await store.connect()?.value
        let replacement = try #require(store.model)
        await fixture.transports[0].finishSend(0, with: .failure(URLError(.networkConnectionLost)))
        await send.value
        #expect(replacement.currentSendRecoveries.isEmpty)
        #expect(replacement.input.isEmpty)
        await store.disconnect()
    }

    @Test(arguments: [false, true])
    func failedOrCancelledRetryKeepsOfflineRecoveryReadableAndEndpointScoped(retryFails: Bool) async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        original.input = "offline retained text"
        let send = try #require(original.send())
        await fixture.transports[0].waitForSendCount(1)
        await fixture.dropConnection(0)
        if retryFails { fixture.failingConnections.insert(1) }
        let retry = try #require(store.connect())
        if !retryFails { await store.cancelConnection() }
        await retry.value
        #expect(store.model == nil)
        #expect(!store.canSend)
        #expect(store.retainedSendRecoveries.first?.text == "offline retained text")
        #expect(store.retainedSendRecoveries.first?.sessionKey == Self.sessionA)
        await fixture.transports[0].finishSend(0, with: .failure(URLError(.networkConnectionLost)))
        await send.value
        #expect(store.retainedSendRecoveries.first?.isAwaitingAcknowledgement == false)
        store.endpoint = "https://other.example"
        #expect(store.retainedSendRecoveries.isEmpty)
        store.endpoint = "https://first.example"
        #expect(store.retainedSendRecoveries.count == 1)
        await store.disconnect()
        #expect(store.retainedSendRecoveries.isEmpty)
    }

    @Test(arguments: [false, true])
    func historyCheckBeforePendingRPCSettlesCannotAuthorizeLaterRestoration(historyCompletesFirst: Bool) async throws {
        let fixture = SendConnectionFixture()
        let store = fixture.store()
        await store.connect()?.value
        let original = try #require(store.model)
        original.input = "still pending"
        let send = try #require(original.send())
        await fixture.transports[0].waitForSendCount(1)
        await fixture.dropConnection(0)
        await store.connect()?.value
        let replacement = try #require(store.model)
        await fixture.transports[1].holdNextHistoryRequest()
        let review = Task { await replacement.refreshSendRecoveryHistory() }
        await fixture.transports[1].waitForHeldHistoryRequest()
        if historyCompletesFirst {
            await fixture.transports[1].releaseHistoryRequest()
            #expect(await review.value)
            #expect(replacement.currentSendRecoveries.first?.hasCheckedHistory == false)
            #expect(replacement.currentSendRecoveries.first?.canRestore == false)
        }
        await fixture.transports[0].finishSend(0, with: .failure(URLError(.timedOut)))
        await send.value
        if !historyCompletesFirst {
            await fixture.transports[1].releaseHistoryRequest()
            #expect(await review.value)
        }
        #expect(replacement.currentSendRecoveries.first?.hasCheckedHistory == false)
        #expect(replacement.currentSendRecoveries.first?.canRestore == false)
        #expect(await replacement.refreshSendRecoveryHistory())
        let recovery = try #require(replacement.currentSendRecoveries.first)
        #expect(recovery.hasCheckedHistory)
        #expect(recovery.canRestore)
        #expect(replacement.restoreSendRecovery(id: recovery.id))
        #expect(replacement.input == "still pending")
        #expect(await fixture.transports[1].sendCount == 0)
        await store.disconnect()
    }

    @Test func historyReviewOfEarlierAttemptCannotAuthorizeRetriedSameKey() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "same key retry"
        let first = try #require(model.send())
        await transport.waitForSendCount(1)
        let runID = await transport.sentKey(0)
        await transport.finishSend(0, with: .failure(OpenClawChatTransportSendError.notDispatched))
        await first.value
        await transport.holdNextHistoryRequest()
        let staleReview = Task { await model.refreshSendRecoveryHistory() }
        await transport.waitForHeldHistoryRequest()
        #expect(model.restoreSendRecovery(id: runID))
        let retry = try #require(model.send())
        await transport.waitForSendCount(2)
        #expect(await transport.sentKey(1) == runID)
        await transport.finishSend(1, with: .failure(URLError(.timedOut)))
        await retry.value
        await transport.releaseHistoryRequest()
        #expect(await staleReview.value)
        let recovery = try #require(model.currentSendRecoveries.first)
        #expect(recovery.id == runID)
        #expect(recovery.delivery == .unconfirmed)
        #expect(!recovery.hasCheckedHistory)
        #expect(!recovery.canRestore)
        #expect(await model.refreshSendRecoveryHistory())
        #expect(model.currentSendRecoveries.first?.canRestore == true)
        model.detachTransport()
    }

    @Test func cancelledHistoryReviewCannotAuthorizeUncertainRestoration() async throws {
        let transport = RecoveryTestTransport()
        let model = OpenClawChatViewModel(sessionKey: Self.sessionA, transport: transport)
        model.input = "uncertain text"
        let send = try #require(model.send())
        await transport.waitForSendCount(1)
        await transport.finishSend(0, with: .failure(URLError(.timedOut)))
        await send.value
        await transport.holdNextHistoryRequest()
        let review = Task { await model.refreshSendRecoveryHistory() }
        await transport.waitForHeldHistoryRequest()
        review.cancel()
        await transport.releaseHistoryRequest()
        #expect(!(await review.value))
        #expect(model.currentSendRecoveries.first?.hasCheckedHistory == false)
        #expect(model.currentSendRecoveries.first?.canRestore == false)
        model.detachTransport()
    }

    private func sessionEntry(_ key: String) throws -> OpenClawChatSessionEntry {
        try JSONDecoder().decode(OpenClawChatSessionEntry.self,
            from: JSONSerialization.data(withJSONObject: ["key": key]))
    }

    private func sendResponse(id: String, status: String) throws -> OpenClawChatSendResponse {
        try JSONDecoder().decode(OpenClawChatSendResponse.self,
            from: JSONSerialization.data(withJSONObject: ["runId": id, "status": status]))
    }
}

@MainActor
private final class SendConnectionFixture {
    let transports = [RecoveryTestTransport(), RecoveryTestTransport()]
    var failingConnections: Set<Int> = []
    private var nextSession = 0
    private var disconnectCallbacks: [Int: ConnectionSession.Callback] = [:]

    func store() -> ConnectionStore {
        let dependencies = ConnectionDependencies(makeSession: {
            let index = self.nextSession
            self.nextSession += 1
            return ConnectionSession(connect: { _, _, connected, disconnected in
                if self.failingConnections.contains(index) { throw URLError(.cannotConnectToHost) }
                self.disconnectCallbacks[index] = disconnected
                await connected()
            }, disconnect: {}, acquireRoute: {
                ConnectionRoute(transport: self.transports[index],
                    mainSessionKey: { "agent:main:session-a" }, isCurrent: { true })
            })
        }, saveToken: { _, _ in Issue.record("Test attempted credential write") },
            loadToken: { _ in Issue.record("Test attempted credential read"); return nil },
            deleteToken: { _ in Issue.record("Test attempted credential deletion") }, saveEndpoint: { _ in })
        let store = ConnectionStore(dependencies: dependencies, enablesLaunchFixtures: false)
        store.endpoint = "https://first.example"
        store.token = "test-only-not-a-credential"
        return store
    }

    func dropConnection(_ index: Int) async { await disconnectCallbacks[index]?() }
}

private actor RecoveryTestTransport: OpenClawChatTransport {
    private var pending: [Int: CheckedContinuation<OpenClawChatSendResponse, any Error>] = [:]
    private var waiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var keys: [String] = []
    private var historyData = Data("[]".utf8)
    private var historyFails = false
    private var shouldHoldNextHistory = false
    private var heldHistoryStarted = false
    private var heldHistory: CheckedContinuation<Void, Never>?
    private var historyWaiters: [CheckedContinuation<Void, Never>] = []
    var sendCount: Int { keys.count }

    func sentKey(_ index: Int) -> String { keys[index] }

    func waitForSendCount(_ count: Int) async {
        guard keys.count < count else { return }
        await withCheckedContinuation { waiters[count, default: []].append($0) }
    }

    func finishSend(_ index: Int, with result: Result<OpenClawChatSendResponse, any Error>) {
        pending.removeValue(forKey: index)?.resume(with: result)
    }

    func setHistoryFailure(_ value: Bool) { historyFails = value }

    func setHistoryMessages(_ data: Data) { historyData = data }

    func holdNextHistoryRequest() {
        shouldHoldNextHistory = true
        heldHistoryStarted = false
    }

    func waitForHeldHistoryRequest() async {
        guard !heldHistoryStarted else { return }
        await withCheckedContinuation { historyWaiters.append($0) }
    }

    func releaseHistoryRequest() {
        heldHistory?.resume()
        heldHistory = nil
    }

    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
        // Capture the response at request start so delayed completion cannot
        // accidentally turn an older history page into a fresh review.
        let data = historyData
        let fails = historyFails
        if shouldHoldNextHistory {
            shouldHoldNextHistory = false
            await withCheckedContinuation { continuation in
                heldHistory = continuation
                heldHistoryStarted = true
                for waiter in historyWaiters { waiter.resume() }
                historyWaiters.removeAll()
            }
        }
        if fails { throw URLError(.notConnectedToInternet) }
        return OpenClawChatHistoryPayload(sessionKey: sessionKey, sessionId: nil,
            messages: try JSONDecoder().decode([AnyCodable].self, from: data), thinkingLevel: nil)
    }

    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        let index = keys.count
        keys.append(idempotencyKey)
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            for count in Array(waiters.keys) where count <= keys.count {
                for waiter in waiters.removeValue(forKey: count) ?? [] { waiter.resume() }
            }
        }
    }

    func listSessions(limit: Int?, search: String?, archived: Bool) async throws -> OpenClawChatSessionsListResponse {
        OpenClawChatSessionsListResponse(ts: nil, path: nil, count: 0, defaults: nil, sessions: [])
    }

    func requestHealth(timeoutMs: Int) async throws -> Bool { true }
    nonisolated func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }
    func setActiveSessionKey(_ sessionKey: String) async throws {}
}
