import Foundation
import OpenClawKit
import Testing
@testable import OpenClawChatUI

/// Ports the narrow upstream wire/admission checks into the Companion test target.
/// Synthetic bytes validate client contracts, not PDF parsing or server acceptance.
@MainActor
struct AttachmentContractTests {
    @Test func pdfFilePayloadRoundTripsThroughProductionRequestEncoder() throws {
        let bytes = Data([0, 1, 127, 128, 255])
        let request = OpenClawChatGatewayRequests.sendMessage(
            sessionKey: "agent:main:attachment-contract",
            agentID: nil,
            expectedSessionRoutingContract: nil,
            message: "첨부 계약 검사",
            thinking: nil,
            idempotencyKey: "synthetic-attachment-contract",
            attachments: [.init(
                type: "file", mimeType: "application/pdf", fileName: "synthetic.pdf",
                content: bytes.base64EncodedString())])
        let encoded = try JSONEncoder().encode(request.params)
        let envelope = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let attachments = try #require(envelope["attachments"] as? [[String: String]])
        #expect(request.method == "chat.send")
        #expect(attachments.count == 1)
        let file = try #require(attachments.first)
        #expect(file["type"] == "file")
        #expect(file["mimeType"] == "application/pdf")
        #expect(file["fileName"] == "synthetic.pdf")
        let content = try #require(file["content"])
        #expect(Data(base64Encoded: content) == bytes)
    }

    @Test func emptyAndOversizedFilesDoNotDisplaceAnAcceptedAttachment() async throws {
        let fixture = try AdmissionFixture(maximumBytes: 8)
        defer { fixture.cleanup() }
        let accepted = try fixture.file("accepted.pdf", bytes: Data("file".utf8))
        let oversized = try fixture.file("oversized.pdf", bytes: Data(repeating: 1, count: 9))
        let empty = try fixture.file("empty.txt", bytes: Data())

        await fixture.model.loadAttachments(urls: [accepted, oversized, empty])

        #expect(fixture.model.attachments.count == 1)
        let attachment = try #require(fixture.model.attachments.first)
        #expect(attachment.fileName == "accepted.pdf")
        #expect(attachment.mimeType == "application/pdf")
        #expect(attachment.type == "file")
        #expect(attachment.data == Data("file".utf8))
        #expect(fixture.model.errorText?.contains("oversized.pdf") == true)
        #expect(fixture.model.errorText?.contains("empty.txt") == true)
    }

    @Test func changedGatewayBudgetRejectsTheCombinedDraftBeforeSending() async throws {
        let fixture = try AdmissionFixture(maximumBytes: 8)
        defer { fixture.cleanup() }
        let first = try fixture.file("first.pdf", bytes: Data("first".utf8))
        let second = try fixture.file("second.txt", bytes: Data("two".utf8))
        await fixture.model.loadAttachments(urls: [first, second])
        #expect(fixture.model.attachments.count == 2)
        let attachmentIDs = fixture.model.attachments.map(\.id)

        // Both files still fit individually, but a refreshed route's budget
        // cannot carry their combined bytes in one chat.send envelope.
        await fixture.policy.setMaximumBytes(7)
        let admitted = await fixture.model.validateAttachmentBudgetForSend(
            fixture.model.attachments, session: fixture.model.currentSessionSnapshot())

        #expect(!admitted)
        #expect(fixture.model.attachments.map(\.id) == attachmentIDs)
        #expect(fixture.model.errorText?.contains("second.txt") == true)
    }

    private actor AdmissionPolicy {
        private var maximumBytes: Int

        init(maximumBytes: Int) { self.maximumBytes = maximumBytes }

        func setMaximumBytes(_ value: Int) { self.maximumBytes = value }

        func limits() -> GatewayAttachmentLimits {
            GatewayAttachmentLimits(maxBytes: self.maximumBytes, maxImageBytes: self.maximumBytes)
        }
    }

    @MainActor
    private final class AdmissionFixture {
        let directory: URL
        let defaultsName: String
        let defaults: UserDefaults
        let policy: AdmissionPolicy
        let model: OpenClawChatViewModel

        init(maximumBytes: Int) throws {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("companion-attachment-contract-\(UUID().uuidString)", isDirectory: true)
            let defaultsName = "CompanionAttachmentContractTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: defaultsName))
            let policy = AdmissionPolicy(maximumBytes: maximumBytes)
            let model = OpenClawChatViewModel(
                sessionKey: "attachment-contract",
                transport: AdmissionTransport(policy: policy),
                modelPickerStore: ChatModelPickerStore(defaults: defaults))
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
            self.directory = directory
            self.defaultsName = defaultsName
            self.defaults = defaults
            self.policy = policy
            self.model = model
        }

        func file(_ name: String, bytes: Data) throws -> URL {
            let url = self.directory.appendingPathComponent(name)
            try bytes.write(to: url)
            return url
        }

        func cleanup() {
            self.model.detachTransport()
            self.defaults.removePersistentDomain(forName: self.defaultsName)
            try? FileManager.default.removeItem(at: self.directory)
        }
    }

    private struct AdmissionTransport: OpenClawChatTransport {
        let policy: AdmissionPolicy

        func attachmentLimits() async -> GatewayAttachmentLimits? { await self.policy.limits() }

        func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }

        func requestHealth(timeoutMs: Int) async throws -> Bool { throw CancellationError() }

        func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
            throw CancellationError()
        }

        func sendMessage(
            sessionKey: String, message: String, thinking: String, idempotencyKey: String,
            attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse
        {
            throw CancellationError()
        }
    }
}
