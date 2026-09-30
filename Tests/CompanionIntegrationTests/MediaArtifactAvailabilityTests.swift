import Foundation
import OpenClawKit
import Testing
@testable import Companion
@testable import OpenClawChatUI

@MainActor
struct MediaArtifactAvailabilityTests {
    @Test func productionAdapterDoesNotClaimMediaSupportWhenChatHealthChanges() {
        let transport: any OpenClawChatTransport = IOSGatewayChatTransport(gateway: GatewayNodeSession())
        let model = OpenClawChatViewModel(sessionKey: "media-policy-only", transport: transport)
        #expect(!transport.supportsMediaArtifactLoading)
        #expect(model.mediaArtifactAvailability == .unsupported)

        // Simulate only the UI health flag. This does not connect to a server or
        // prove retrieval; the adapter still has no managed artifact loader.
        model.healthOK = true
        #expect(model.mediaArtifactAvailability == .unsupported)
        #expect(model.mediaArtifactAvailability.unavailableReason != nil)
    }

    @Test func optedInAdapterLosesMediaActionsWhenDisconnected() {
        let model = OpenClawChatViewModel(sessionKey: "media-policy-only", transport: SupportedMediaTransport())
        #expect(model.mediaArtifactAvailability == .disconnected)
        #expect(model.mediaArtifactAvailability.unavailableReason != nil)

        model.healthOK = true
        #expect(model.mediaArtifactAvailability == .available)
        #expect(model.mediaArtifactAvailability.unavailableReason == nil)

        model.healthOK = false
        #expect(model.mediaArtifactAvailability == .disconnected)
    }

    private struct SupportedMediaTransport: OpenClawChatTransport {
        var supportsMediaArtifactLoading: Bool { true }

        func loadMediaArtifact(
            sessionKey: String,
            artifactId: String,
            kind: OpenClawChatMediaKind,
            playback: OpenClawChatPlaybackMode?) async throws -> OpenClawChatLoadedMedia?
        {
            throw CancellationError()
        }

        func events() -> AsyncStream<OpenClawChatTransportEvent> {
            AsyncStream { $0.finish() }
        }

        func requestHealth(timeoutMs: Int) async throws -> Bool { throw CancellationError() }

        func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload {
            throw CancellationError()
        }

        func sendMessage(
            sessionKey: String,
            message: String,
            thinking: String,
            idempotencyKey: String,
            attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse
        {
            throw CancellationError()
        }
    }
}
