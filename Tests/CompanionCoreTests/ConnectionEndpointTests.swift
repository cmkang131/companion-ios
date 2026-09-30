import Testing
import Foundation
@testable import CompanionCore

@Test func secureEndpoint() throws {
    #expect(try ConnectionEndpoint(" https://example.com/gateway ").url.absoluteString == "wss://example.com/gateway")
    #expect(try ConnectionEndpoint("wss://example.com").url.host == "example.com")
}
@Test func rejectsUnsafeInputs() {
    for endpoint in ["", "localhost", "http://example.com", "ws://example.com", "https://user:secret@example.com", "https://example.com?token=secret", "https://example.com#secret"] {
        #expect(throws: (any Error).self) { try ConnectionEndpoint(endpoint) }
    }
}
@Test func preservesMessageIdentity() throws {
    let original = ConversationMessage(text: "안녕하세요")
    let decoded = try JSONDecoder().decode(ConversationMessage.self, from: JSONEncoder().encode(original))
    #expect(decoded == original)
    #expect(decoded.delivery == .draft)
}

@Test func endpointPreservesProxyPathAndNormalizesScheme() throws {
    #expect(try ConnectionEndpoint("HTTPS://example.com:443/openclaw").url.absoluteString == "wss://example.com:443/openclaw")
    #expect(try ConnectionEndpoint("https://[::1]:8443").url.port == 8443)
}

@Test func rejectsInvalidPortsAndWhitespace() {
    for value in ["https://example.com:0", "https://example.com:65536", "https://exa mple.com", "https://example.com/line\nbreak"] {
        #expect(throws: (any Error).self) { try ConnectionEndpoint(value) }
    }
}
