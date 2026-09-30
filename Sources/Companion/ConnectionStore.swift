import Foundation
import Observation
import CompanionCore
import OpenClawKit
import OpenClawChatUI

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
    @ObservationIgnored private var gateway: GatewayNodeSession?
    @ObservationIgnored private var transport: (any OpenClawChatTransport)?
    @ObservationIgnored private var attempt: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var credentialRevision = UUID()
    @ObservationIgnored private var historyRequest = UUID()
    @ObservationIgnored private var activeEndpoint: URL?
    @ObservationIgnored private var retryDraft: (endpoint: URL, session: String, text: String)?
    private static let keychainService = "com.cmkang131.companion.gateway"

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

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-preview") {
            isPreview = true
            let preview = PreviewTransport()
            transport = preview
            model = OpenClawChatViewModel(sessionKey: "preview", transport: preview)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") { endpoint = "" }
        #endif
    }

    func connect() {
        guard phase != .connecting && phase != .connected else { return }
        let address: URL
        do { address = try ConnectionEndpoint(endpoint).url }
        catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "서버 주소를 확인해 주세요."
            return
        }
        let credential = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !credential.isEmpty else {
            errorMessage = "서버에서 발급한 연결 토큰을 입력해 주세요."
            return
        }
        attempt?.cancel()
        generation = UUID()
        let current = generation
        let previous = gateway
        let next = GatewayNodeSession()
        gateway = next
        if address != activeEndpoint { retryDraft = nil }
        else if let model, !isPreview {
            retryDraft = (address, model.currentSessionTarget.sessionKey, model.input)
        }
        activeEndpoint = address
        phase = .connecting
        errorMessage = nil
        model?.detachTransport()
        model = nil
        transport = nil
        sessions = []
        historyRequest = UUID()
        historyError = nil
        isLoadingHistory = false
        isPreview = false
        let shouldRemember = rememberToken
        let savingRevision = credentialRevision
        attempt = Task { [weak self] in
            await previous?.disconnect()
            guard let self, !Task.isCancelled, self.generation == current else { return }
            let options = GatewayConnectOptions(
                role: "operator", scopes: ["operator.read", "operator.write"], scopesAreExplicit: true,
                caps: [OpenClawGatewayClientCapability.agentKind], commands: [], permissions: [:],
                clientId: "openclaw-ios", clientMode: "ui", clientDisplayName: "Companion",
                includeDeviceIdentity: true, allowStoredDeviceAuth: false, deviceAuthGatewayID: nil)
            do {
                try await next.connect(url: address, token: credential, connectOptions: options, sessionBox: nil,
                    onConnected: { [weak self] in
                        await self?.didConnect(gateway: next, generation: current)
                    }, onDisconnected: { [weak self] _ in
                        await self?.didDisconnect(generation: current)
                    }, onInvoke: { request in
                        BridgeInvokeResponse(id: request.id, ok: false,
                            error: OpenClawNodeError(code: .unavailable, message: "This client does not expose device commands."))
                    })
                guard !Task.isCancelled, self.generation == current else { return }
                self.endpoint = address.absoluteString
                UserDefaults.standard.set(self.endpoint, forKey: "companion.endpoint")
                if shouldRemember && self.rememberToken && self.credentialRevision == savingRevision {
                    do {
                        try GenericPasswordKeychainStore.saveStringResult(credential,
                            service: Self.keychainService, account: self.endpoint).get()
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
    }

    private func didConnect(gateway: GatewayNodeSession, generation: UUID) async {
        guard self.generation == generation else { return }
        if model == nil {
            let transport = IOSGatewayChatTransport(gateway: gateway)
            self.transport = transport
            let route = await gateway.currentRoute()
            let key: String
            if let route { key = await gateway.waitForCurrentMainSessionKey(ifCurrentRoute: route) ?? "agent:main:main" }
            else { return }
            guard self.generation == generation else { return }
            let savedDraft = retryDraft.flatMap { $0.endpoint == activeEndpoint ? $0 : nil }
            model = OpenClawChatViewModel(sessionKey: savedDraft?.session ?? key, transport: transport)
            if let savedDraft { model?.input = savedDraft.text }
            retryDraft = nil
        } else { model?.resumeFromForeground() }
        phase = .connected
        errorMessage = nil
    }

    private func didDisconnect(generation: UUID) {
        guard self.generation == generation else { return }
        phase = .failed
        errorMessage = "서버와 연결이 끊어졌어요. 네트워크와 서버 상태를 확인한 뒤 다시 연결해 주세요."
    }

    func disconnect() async {
        generation = UUID()
        attempt?.cancel()
        attempt = nil
        let previous = gateway
        gateway = nil
        model?.detachTransport()
        model = nil
        transport = nil
        activeEndpoint = nil
        retryDraft = nil
        sessions = []
        historyRequest = UUID()
        historyError = nil
        isLoadingHistory = false
        phase = .disconnected
        errorMessage = nil
        isPreview = false
        token = ""
        await previous?.disconnect()
    }

    func useSavedToken() {
        guard let normalized = try? ConnectionEndpoint(endpoint).url.absoluteString else { return }
        if let saved = GenericPasswordKeychainStore.loadString(service: Self.keychainService, account: normalized) {
            token = saved
            rememberToken = true
            errorMessage = nil
        } else { errorMessage = "이 서버에 저장된 토큰이 없어요." }
    }

    func forgetToken() {
        // Revocation wins even if an in-flight connection captured an earlier consent.
        credentialRevision = UUID()
        rememberToken = false
        guard let normalized = try? ConnectionEndpoint(endpoint).url.absoluteString else { return }
        do {
            try GenericPasswordKeychainStore.deleteResult(service: Self.keychainService, account: normalized).get()
            token = ""
            rememberToken = false
            errorMessage = nil
        } catch { errorMessage = "저장된 토큰을 삭제하지 못했어요. 다시 시도해 주세요." }
    }

    func loadHistory() async {
        guard let transport else { return }
        let current = generation
        let request = UUID()
        historyRequest = request
        isLoadingHistory = true
        historyError = nil
        defer { if generation == current && historyRequest == request { isLoadingHistory = false } }
        do {
            let result = try await transport.listSessions(limit: 100, search: nil, archived: false)
            guard generation == current && historyRequest == request else { return }
            sessions = result.sessions
        } catch {
            guard generation == current && historyRequest == request else { return }
            historyError = "대화 목록을 불러오지 못했어요. 다시 시도해 주세요."
        }
    }

    func openSession(_ session: OpenClawChatSessionEntry) { model?.switchSession(to: session.key) }

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
