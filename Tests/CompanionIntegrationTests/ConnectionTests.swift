import Testing
import OpenClawChatUI
import OpenClawKit
@testable import Companion

@MainActor
struct ConnectionTests {
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
}
