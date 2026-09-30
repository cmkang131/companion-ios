import Foundation
import Observation
import OpenClawKit

/// A submitted draft retained in memory until its acceptance is known or the user restores it.
public struct OpenClawChatSendRecovery: Identifiable, Equatable, Sendable {
    public enum Delivery: Equatable, Sendable { case notSent, unconfirmed }
    public let id: String
    public let sessionKey: String
    public let text: String
    public let attachmentCount: Int
    public let delivery: Delivery
    public let isAwaitingAcknowledgement: Bool
    public let hasCheckedHistory: Bool
    public var canRestore: Bool {
        !isAwaitingAcknowledgement && (delivery == .notSent || hasCheckedHistory)
    }
}

/// Shared only by presentations of the same endpoint. Late acknowledgements retire
/// the original send here even after its presentation was detached or replaced.
@MainActor @Observable
final class ChatSendRecoveryLedger {
    struct Entry {
        let id: String
        let sessionKey: String
        let composerSessionKey: String
        let text: String
        let attachments: [OpenClawPendingAttachment]
        let replyTarget: OpenClawChatReplyTarget?
        var delivery: OpenClawChatSendRecovery.Delivery?
        var isAwaitingAcknowledgement = true
        var hasCheckedHistory = false
    }

    var entries: [Entry] = []
    // A user-restored, unchanged draft keeps its original deduplication identity.
    var restoredBySession: [String: Entry] = [:]

    func recoveries(composerSessionKey: String? = nil) -> [OpenClawChatSendRecovery] {
        entries.compactMap { entry in
            guard composerSessionKey == nil || entry.composerSessionKey == composerSessionKey,
                  let delivery = entry.delivery else { return nil }
            return OpenClawChatSendRecovery(id: entry.id, sessionKey: entry.sessionKey, text: entry.text,
                attachmentCount: entry.attachments.count, delivery: delivery,
                isAwaitingAcknowledgement: entry.isAwaitingAcknowledgement,
                hasCheckedHistory: entry.hasCheckedHistory)
        }
    }

    func settle(_ id: String, delivery: OpenClawChatSendRecovery.Delivery?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        guard let delivery else {
            entries.remove(at: index)
            return
        }
        entries[index].delivery = delivery
        entries[index].isAwaitingAcknowledgement = false
        entries[index].hasCheckedHistory = false
    }
}

extension OpenClawChatViewModel {
    public var currentSendRecoveries: [OpenClawChatSendRecovery] {
        sendRecoveryLedger.recoveries(composerSessionKey: composerSessionKey(for: sessionKey))
    }

    public var allSendRecoveries: [OpenClawChatSendRecovery] { sendRecoveryLedger.recoveries() }

    /// Absence from a history page is not evidence of non-delivery. An uncertain
    /// entry remains uncertain after checking, but explicit restoration is allowed.
    @discardableResult
    public func refreshSendRecoveryHistory() async -> Bool {
        guard !isTransportDetached else { return false }
        let session = currentSessionSnapshot()
        let key = composerSessionKey(for: session.key)
        let ids = Set(sendRecoveryLedger.entries.filter { $0.composerSessionKey == key }.map(\.id))
        let result = await refreshHistoryAfterRun(historyRequest: beginHistoryRequest(for: session))
        guard !Task.isCancelled, isCurrentSession(session) else { return false }
        guard result.applied else {
            errorText = "전송 기록을 확인하지 못했어요. 연결 상태를 확인한 뒤 다시 시도해 주세요."
            return false
        }
        for index in sendRecoveryLedger.entries.indices where ids.contains(sendRecoveryLedger.entries[index].id) {
            sendRecoveryLedger.entries[index].hasCheckedHistory = true
        }
        return true
    }

    /// Called only after an explicit user choice. For uncertain delivery, the UI
    /// must explain that the server may already have accepted the message.
    /// Never replaces newer composer text, attachments, or a reply selection.
    @discardableResult
    public func restoreSendRecovery(id: String) -> Bool {
        guard !isTransportDetached, !isSubmittingDraft, !isSending, !isAttachmentOwnerPinned,
              input.isEmpty, attachments.isEmpty,
              let recovery = currentSendRecoveries.first(where: { $0.id == id }), recovery.canRestore,
              let index = sendRecoveryLedger.entries.firstIndex(where: { $0.id == id })
        else { return false }
        let entry = sendRecoveryLedger.entries[index]
        guard replyTarget == nil || replyTarget == entry.replyTarget else { return false }
        sendRecoveryLedger.entries.remove(at: index)
        sendRecoveryLedger.restoredBySession[entry.composerSessionKey] = entry
        input = entry.text
        attachments = entry.attachments
        replyTarget = entry.replyTarget
        errorText = nil
        return true
    }

    func reserveSendRecovery(
        proposedRunID: String,
        sessionKey: String,
        composerSessionKey: String,
        text: String,
        attachments: [OpenClawPendingAttachment],
        replyTarget: OpenClawChatReplyTarget?) -> String
    {
        let restored = sendRecoveryLedger.restoredBySession.removeValue(forKey: composerSessionKey)
        let sameDraft = restored?.text == text &&
            restored?.attachments.map(\.id) == attachments.map(\.id) && restored?.replyTarget == replyTarget
        let runID = sameDraft ? restored!.id : proposedRunID
        sendRecoveryLedger.entries.append(.init(id: runID, sessionKey: sessionKey, composerSessionKey: composerSessionKey,
            text: text, attachments: attachments, replyTarget: replyTarget))
        return runID
    }

    func suspendSendRecoveriesForDetach() {
        for index in sendRecoveryLedger.entries.indices where sendRecoveryLedger.entries[index].delivery == nil {
            sendRecoveryLedger.entries[index].delivery = .unconfirmed
        }
    }

    func reconcileSendRecoveries(in canonicalMessages: [OpenClawChatMessage], sessionKey: String) {
        let key = composerSessionKey(for: sessionKey)
        let accepted = Set(canonicalMessages.compactMap { message -> String? in
            guard message.role.lowercased() == "user" else { return nil }
            return message.idempotencyKey
        })
        sendRecoveryLedger.entries.removeAll {
            $0.composerSessionKey == key && accepted.contains("\($0.id):user")
        }
    }

    static func sendRecoveryDelivery(for error: any Error, beforeDispatch: Bool = false)
        -> OpenClawChatSendRecovery.Delivery
    {
        // Only typed pre-dispatch/ownership failures prove that no message ran.
        // Server errors and timeouts can follow partial work, so fail closed.
        if beforeDispatch || error is OpenClawChatTransportSendError || error is OpenClawChatSendOwnershipError {
            return .notSent
        }
        return .unconfirmed
    }
}
