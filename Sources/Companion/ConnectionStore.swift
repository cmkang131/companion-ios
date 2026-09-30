import Foundation
import Observation
import CompanionCore
import OpenClawKit
import OpenClawChatUI

/// A route retains the captured physical socket identity across the main-key await.
@MainActor
struct ConnectionRoute {
    let transport: any OpenClawChatTransport
    let mainSessionKey: () async -> String?
    let isCurrent: () async -> Bool
}

/// Thin boundary around the reused gateway, allowing deterministic lifecycle tests.
@MainActor
struct ConnectionSession {
    typealias Callback = @MainActor @Sendable () async -> Void
    let connect: (URL, String, @escaping Callback, @escaping Callback) async throws -> Void
    let disconnect: () async -> Void
    let acquireRoute: () async -> ConnectionRoute?

    static func live() -> Self {
        let gateway = GatewayNodeSession()
        return Self(connect: { address, credential, connected, disconnected in
            let options = GatewayConnectOptions(
                role: "operator", scopes: ["operator.read", "operator.write"], scopesAreExplicit: true,
                caps: [OpenClawGatewayClientCapability.agentKind], commands: [], permissions: [:],
                clientId: "openclaw-ios", clientMode: "ui", clientDisplayName: "Companion",
                includeDeviceIdentity: true, allowStoredDeviceAuth: false, deviceAuthGatewayID: nil)
            try await gateway.connect(url: address, token: credential, connectOptions: options, sessionBox: nil,
                onConnected: { await connected() }, onDisconnected: { _ in await disconnected() },
                onInvoke: { request in
                    BridgeInvokeResponse(id: request.id, ok: false,
                        error: OpenClawNodeError(code: .unavailable,
                            message: "This client does not expose device commands."))
                })
        }, disconnect: { await gateway.disconnect() }, acquireRoute: {
            guard let route = await gateway.currentRoute() else { return nil }
            return ConnectionRoute(transport: IOSGatewayChatTransport(gateway: gateway),
                mainSessionKey: { await gateway.waitForCurrentMainSessionKey(ifCurrentRoute: route) },
                isCurrent: { await gateway.currentRoute() == route })
        })
    }
}

@MainActor
struct ConnectionDependencies {
    var makeSession: () -> ConnectionSession
    var saveToken: (_ token: String, _ endpoint: String) throws -> Void
    var loadToken: (_ endpoint: String) -> String?
    var deleteToken: (_ endpoint: String) throws -> Void
    var saveEndpoint: (_ endpoint: String) -> Void

    static var live: Self {
        let service = "com.cmkang131.companion.gateway"
        return Self(makeSession: { .live() }, saveToken: { token, endpoint in
            try GenericPasswordKeychainStore.saveStringResult(token, service: service, account: endpoint).get()
        }, loadToken: { endpoint in
            GenericPasswordKeychainStore.loadString(service: service, account: endpoint)
        }, deleteToken: { endpoint in
            try GenericPasswordKeychainStore.deleteResult(service: service, account: endpoint).get()
        }, saveEndpoint: { UserDefaults.standard.set($0, forKey: "companion.endpoint") })
    }
}

@MainActor @Observable
final class ConnectionStore {
    enum Phase: Equatable { case disconnected, connecting, connected, failed }
    var phase: Phase = .disconnected
    var endpoint = UserDefaults.standard.string(forKey: "companion.endpoint") ?? ""
    var token = ""
    var rememberToken = false
    var errorMessage: String?
    var model: OpenClawChatViewModel?
    var sessions: [OpenClawChatSessionEntry] = []
    var historyError: String?
    var isLoadingHistory = false
    private(set) var isPreview = false
    @ObservationIgnored private let dependencies: ConnectionDependencies
    @ObservationIgnored private var gateway: ConnectionSession?
    @ObservationIgnored private var transport: (any OpenClawChatTransport)?
    @ObservationIgnored private var attempt: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var credentialRevision = UUID()
    @ObservationIgnored private var historyRequest = UUID()
    @ObservationIgnored private var activeEndpoint: URL?
    @ObservationIgnored private var retryDrafts: (endpoint: URL, snapshot: OpenClawChatDraftSnapshot)?

    var status: String {
        if isPreview { return "미리보기 · 서버 미연결" }
        switch phase {
        case .disconnected: return "연결되지 않음"
        case .connecting: return "연결 중"
        case .connected: return "연결됨"
        case .failed: return "연결을 확인해 주세요"
        }
    }

    var canSend: Bool { phase == .connected && !isPreview }

    init(dependencies: ConnectionDependencies = .live, enablesLaunchFixtures: Bool = true) {
        self.dependencies = dependencies
        #if DEBUG
        if enablesLaunchFixtures && ProcessInfo.processInfo.arguments.contains("--ui-preview") {
            isPreview = true
            let preview = PreviewTransport()
            transport = preview
            model = OpenClawChatViewModel(sessionKey: "preview", transport: preview)
        }
        if enablesLaunchFixtures && ProcessInfo.processInfo.arguments.contains("--ui-testing") { endpoint = "" }
        #endif
    }

    @discardableResult
    func connect() -> Task<Void, Never>? {
        guard phase != .connecting && phase != .connected else { return nil }
        let address: URL
        do { address = try ConnectionEndpoint(endpoint).url }
        catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "서버 주소를 확인해 주세요."
            return nil
        }
        let credential = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            errorMessage = "서버에서 발급한 연결 토큰을 입력해 주세요."
            return nil
        }
        attempt?.cancel()
        generation = UUID()
        let current = generation
        let previous = gateway
        let next = dependencies.makeSession()
        gateway = next
        if address != activeEndpoint { retryDrafts = nil }
        else { captureRetryDrafts() }
        activeEndpoint = address
        phase = .connecting
        errorMessage = nil
        model?.detachTransport()
        model = nil
        transport = nil
        resetHistory()
        isPreview = false
        let shouldRemember = rememberToken
        let savingRevision = credentialRevision
        attempt = Task { [weak self] in
            await previous?.disconnect()
            guard let self, !Task.isCancelled, self.generation == current else { return }
            do {
                try await next.connect(address, credential, { [weak self] in
                    await self?.didConnect(gateway: next, generation: current)
                }, { [weak self] in
                    self?.didDisconnect(generation: current)
                })
                guard !Task.isCancelled, self.generation == current, self.phase == .connected else { return }
                self.endpoint = address.absoluteString
                self.dependencies.saveEndpoint(self.endpoint)
                if shouldRemember && self.rememberToken && self.credentialRevision == savingRevision {
                    do {
                        try self.dependencies.saveToken(credential, self.endpoint)
                    } catch {
                        self.errorMessage = "연결했지만 토큰을 안전하게 저장하지 못했어요. 다음 실행 때 다시 입력해 주세요."
                    }
                }
            } catch {
                guard !Task.isCancelled, self.generation == current else { return }
                self.phase = .failed
                self.errorMessage = Self.connectionError(error)
                await next.disconnect()
            }
        }
        return attempt
    }

    private func didConnect(gateway: ConnectionSession, generation: UUID) async {
        guard !Task.isCancelled, self.generation == generation,
              let route = await gateway.acquireRoute() else { return }
        let mainKey = await route.mainSessionKey()
        // Generation alone does not detect automatic reconnects within one gateway.
        // A retired socket must not publish a model using a guessed default key.
        guard await route.isCurrent(), !Task.isCancelled, self.generation == generation else { return }
        if model == nil {
            let savedDrafts = retryDrafts.flatMap { $0.endpoint == activeEndpoint ? $0.snapshot : nil }
            self.transport = route.transport
            model = OpenClawChatViewModel(sessionKey: mainKey ?? "agent:main:main",
                transport: route.transport, draftSnapshot: savedDrafts)
            retryDrafts = nil
        } else { model?.resumeFromForeground() }
        phase = .connected
        errorMessage = nil
    }

    private func didDisconnect(generation: UUID) {
        guard self.generation == generation else { return }
        phase = .failed
        resetHistory()
        errorMessage = "서버와 연결이 끊어졌어요. 네트워크와 서버 상태를 확인한 뒤 다시 연결해 주세요."
    }

    /// Cancels only a pending attempt. The token and all text drafts remain in
    /// memory for retrying this endpoint; selecting a different endpoint discards them.
    func cancelConnection() async {
        guard phase == .connecting else { return }
        await retireConnection(preservingRetry: true)
    }

    /// Explicit disconnect erases the in-memory token and all session text drafts.
    /// A token separately saved in Keychain remains until the user deletes it.
    func disconnect() async {
        await retireConnection(preservingRetry: false)
    }

    private func retireConnection(preservingRetry: Bool) async {
        if preservingRetry { captureRetryDrafts() }
        generation = UUID()
        attempt?.cancel()
        attempt = nil
        let previous = gateway
        gateway = nil
        model?.detachTransport()
        model = nil
        transport = nil
        if !preservingRetry {
            activeEndpoint = nil
            retryDrafts = nil
            token = ""
        }
        resetHistory()
        phase = .disconnected
        errorMessage = nil
        isPreview = false
        await previous?.disconnect()
    }

    private func captureRetryDrafts() {
        guard let model, let activeEndpoint, !isPreview else { return }
        retryDrafts = (activeEndpoint, model.captureDraftSnapshot())
    }

    private func resetHistory() {
        historyRequest = UUID()
        sessions = []
        historyError = nil
        isLoadingHistory = false
    }

    func useSavedToken() {
        guard let normalized = validatedCredentialEndpoint() else { return }
        if let saved = dependencies.loadToken(normalized) {
            token = saved
            rememberToken = true
            errorMessage = nil
        } else { errorMessage = "이 서버에 저장된 토큰이 없어요." }
    }

    func forgetToken() {
        // Revocation wins even if an in-flight connection captured an earlier consent.
        credentialRevision = UUID()
        rememberToken = false
        guard let normalized = validatedCredentialEndpoint() else { return }
        do {
            try dependencies.deleteToken(normalized)
            token = ""
            rememberToken = false
            errorMessage = nil
        } catch { errorMessage = "저장된 토큰을 삭제하지 못했어요. 다시 시도해 주세요." }
    }

    private func validatedCredentialEndpoint() -> String? {
        do { return try ConnectionEndpoint(endpoint).url.absoluteString }
        catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "서버 주소를 확인해 주세요."
            return nil
        }
    }

    func loadHistory() async {
        guard canSend, !Task.isCancelled, let transport else { return }
        let current = generation
        let request = UUID()
        historyRequest = request
        isLoadingHistory = true
        historyError = nil
        defer { if generation == current && historyRequest == request { isLoadingHistory = false } }
        do {
            let result = try await transport.listSessions(limit: 100, search: nil, archived: false)
            guard !Task.isCancelled, canSend, generation == current && historyRequest == request else { return }
            sessions = result.sessions
        } catch {
            guard !Task.isCancelled, canSend, generation == current && historyRequest == request else { return }
            historyError = "대화 목록을 불러오지 못했어요. 다시 시도해 주세요."
        }
    }

    func openSession(_ session: OpenClawChatSessionEntry) {
        guard canSend else { return }
        model?.switchSession(to: session.key)
    }

    func newConversation() {
        guard let model, canSend else { return }
        let agent = OpenClawChatSessionKey.agentID(from: model.currentSessionTarget.sessionKey) ?? "main"
        model.switchSession(to: "agent:\(agent):companion-" + UUID().uuidString.lowercased())
    }

    func foreground() { if phase == .connected { model?.resumeFromForeground() } }

    static func connectionError(_ error: any Error) -> String {
        if let problem = GatewayConnectionProblemMapper.map(error: error) {
            if problem.needsPairingApproval {
                return "서버에서 이 기기의 연결 요청을 승인해 주세요. 승인 후 다시 연결할 수 있어요."
            }
            if problem.needsCredentialUpdate {
                return "서버가 인증을 거절했어요. 연결 토큰과 서버의 인증 설정을 확인해 주세요."
            }
            switch problem.kind {
            case .protocolMismatch:
                return "앱과 서버의 연결 규격이 달라요. OpenClaw 서버 버전을 확인해 주세요."
            case .tlsPinMismatch, .tlsCertificateUntrusted, .tlsCertificateUnavailable:
                return "서버 인증서를 확인할 수 없어요. 서버의 HTTPS 인증서를 확인해 주세요."
            case .authRateLimited:
                return "인증 시도가 너무 많아요. 잠시 후 다시 연결해 주세요."
            case .timeout:
                return "서버 응답이 늦어지고 있어요. 네트워크와 서버 상태를 확인해 주세요."
            default: break
            }
        }
        return "서버에 연결하지 못했어요. 주소, 인증서와 네트워크를 확인한 뒤 다시 시도해 주세요."
    }
}
