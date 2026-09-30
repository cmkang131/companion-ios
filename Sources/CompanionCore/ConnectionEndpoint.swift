import Foundation

public struct ConnectionEndpoint: Equatable, Sendable {
    public let url: URL
    public enum ValidationError: Error, Equatable { case empty, malformed, insecureScheme, embeddedCredentials, unexpectedQuery }

    public init(_ input: String) throws {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw ValidationError.empty }
        guard value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              var components = URLComponents(string: value), let host = components.host, !host.isEmpty,
              host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true
        else { throw ValidationError.malformed }
        guard components.user == nil, components.password == nil else { throw ValidationError.embeddedCredentials }
        guard components.query == nil, components.fragment == nil else { throw ValidationError.unexpectedQuery }
        switch components.scheme?.lowercased() {
        case "https", "wss": components.scheme = "wss"
        default: throw ValidationError.insecureScheme
        }
        guard let parsed = components.url else { throw ValidationError.malformed }
        url = parsed
    }
}

public enum DeliveryState: String, Codable, Sendable {
    case draft, sending, acknowledged, failed
}

public struct ConversationMessage: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let text: String
    public let createdAt: Date
    public var delivery: DeliveryState
    public init(text: String, id: UUID = UUID(), createdAt: Date = Date(), delivery: DeliveryState = .draft) {
        self.id = id; self.text = text; self.createdAt = createdAt; self.delivery = delivery
    }
}

extension ConnectionEndpoint.ValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .empty: return "서버 주소를 입력해 주세요."
        case .malformed: return "올바른 서버 주소를 입력해 주세요."
        case .insecureScheme: return "HTTPS 또는 WSS로 시작하는 주소를 사용해 주세요."
        case .embeddedCredentials: return "주소에 인증 정보를 넣지 말고 연결 토큰 칸을 사용해 주세요."
        case .unexpectedQuery: return "주소에서 물음표 뒤의 내용과 # 부분을 제거해 주세요."
        }
    }
}
