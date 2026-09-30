import SwiftUI
import UIKit
import OpenClawChatUI

@main
struct CompanionApp: App {
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--ui-motion-gallery") {
                CompanionMotionGallery().modifier(CompanionAccessibilityFixture()).preferredColorScheme(.light)
            } else {
                CompanionHome().modifier(CompanionAccessibilityFixture()).preferredColorScheme(.light)
            }
            #else
            CompanionHome().preferredColorScheme(.light)
            #endif
        }
    }
}

struct CompanionHome: View {
    @State private var connection = ConnectionStore()
    @State private var sheet: Sheet?
    @State private var responseArrived = false
    @State private var acknowledgementTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    private enum Sheet: String, Identifiable { case connection, history, recovery; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            Group {
                if let model = connection.model {
                    OpenClawChatView(viewModel: model, drawsBackground: false,
                        showsSessionSwitcher: false,
                        userAccent: Color(red: 0.82, green: 0.91, blue: 0.98),
                        showsAssistantTrace: false, assistantName: "dot",
                        showsAssistantAvatars: false, composerChrome: .clean,
                        isComposerEnabled: connection.canSend,
                        isAttachmentInputEnabled: connection.canSend,
                        messagePlaceholder: connection.canSend ? "메시지" : "서버 연결 후 메시지",
                        emptyAssistantIntro: "어떤 이야기부터 할까요?", emptyAssistantPrompts: [])
                        .environment(\.openClawAssistantBubblesInCleanChrome, true)
                        .environment(\.openClawCompactConversation, true)
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                } else {
                    welcome
                }
            }
            .background(Color(white: 0.985))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { sheet = .history } label: { Image(systemName: "text.bubble") }
                        .accessibilityLabel("대화 목록").accessibilityIdentifier("historyButton")
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 7) {
                        if connection.model != nil {
                            CompanionCharacterView(mood: characterMood,
                                paused: sheet != nil || !connection.canSend).frame(width: 28, height: 28)
                        }
                        Text("dot").font(.headline.weight(.medium))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .connection } label: { Image(systemName: "slider.horizontal.3") }
                        .accessibilityLabel("연결 설정").accessibilityIdentifier("connectionButton")
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if !connection.presentationSendRecoveries.isEmpty || !connection.interruptedAttachmentSessionKeys.isEmpty {
                    Button { sheet = .recovery } label: {
                        Label("확인이 필요한 내용", systemImage: "exclamationmark.circle")
                            .font(.footnote).padding(.horizontal, 15).padding(.vertical, 8)
                            .background(Color(white: 0.955), in: Capsule()).frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityIdentifier("sendRecoveryButton")
                } else if connection.model != nil {
                    Button { sheet = .connection } label: {
                        Text(activityStatus).font(.footnote).foregroundStyle(.secondary)
                            .padding(.horizontal, 15).padding(.vertical, 7)
                            .background(Color(white: reduceTransparency ? 0.94 : 0.965), in: Capsule())
                            .frame(minHeight: 44)
                    }.buttonStyle(.plain).accessibilityHint("서버 연결 설정 열기")
                }
            }
            .sheet(item: $sheet) { selection in
                switch selection {
                case .connection: ConnectionSettings(connection: connection)
                case .history: ConversationHistory(connection: connection)
                case .recovery: SendRecoverySheet(connection: connection, openHistory: { sheet = .history })
                }
            }
        }
        .tint(.primary)
        .onChange(of: scenePhase) { _, value in if value == .active { connection.foreground() } }
        .onChange(of: connection.canSend) { _, value in if !value { clearAcknowledgement() } }
        .onChange(of: connection.model?.sessionKey) { _, _ in clearAcknowledgement() }
        .onChange(of: connection.model?.companionRunCompletionRevision ?? 0) { oldValue, newValue in
            guard newValue > oldValue, connection.canSend else { return }
            clearAcknowledgement()
            responseArrived = true
            acknowledgementTask = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(2.4)) } catch { return }
                responseArrived = false
            }
        }
        .onDisappear { clearAcknowledgement() }
        .task {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("--ui-settings") { sheet = .connection }
            if arguments.contains("--ui-history") { sheet = .history }
            if arguments.contains("--ui-send-recovery"), connection.isPreview, let model = connection.model {
                model.input = "검증용 메시지: 오후 일정을 함께 정리해 주세요."
                await model.send()?.value
                sheet = .recovery
            }
            #endif
        }
    }

    private var isResponding: Bool { connection.canSend && connection.model?.companionHasActiveResponse == true }
    private var characterMood: OpenClawMascotMood {
        guard connection.canSend else { return .attentive }
        return isResponding ? .thinking : responseArrived ? .happy : .attentive
    }
    private var activityStatus: String {
        guard connection.canSend else { return connection.status }
        return isResponding ? "응답 작성 중" : responseArrived ? "응답 도착" : "대화할 수 있어요"
    }
    private func clearAcknowledgement() {
        acknowledgementTask?.cancel()
        acknowledgementTask = nil
        responseArrived = false
    }

    private var welcome: some View {
        GeometryReader { viewport in
        ScrollView {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            VStack(spacing: -14) {
                CompanionCharacterView(mood: connection.phase == .connecting ? .curious : .attentive,
                    paused: sheet != nil).frame(width: dynamicTypeSize.isAccessibilitySize ? 96 : 156,
                        height: dynamicTypeSize.isAccessibilitySize ? 96 : 156)
                CompanionNamePill()
            }.padding(.bottom, 28)
            Text("여기 있어요").font(.title2.weight(.semibold))
                .padding(.bottom, 10)
            Text("OpenClaw에 연결해\n이야기를 시작하세요.")
                .font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if !dynamicTypeSize.isAccessibilitySize { connectButton.padding(.top, 26) }
            Spacer(minLength: 32)
            if !dynamicTypeSize.isAccessibilitySize {
                Text(connection.status).font(.footnote).foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
        }.padding(.horizontal, 28).frame(maxWidth: .infinity, minHeight: viewport.size.height)
        }.scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 8) {
                    connectButton
                    Text(connection.status).font(.footnote).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity).padding(16).background(Color(white: 0.985))
            }
        }
    }

    private var connectButton: some View {
        Button { sheet = .connection } label: {
            HStack(spacing: 9) {
                if connection.phase == .connecting { ProgressView() }
                Text(connection.phase == .connecting ? "연결 확인" : "서버 연결")
            }.padding(.horizontal, 12).frame(minHeight: 44)
        }
        .buttonStyle(.glass).controlSize(.large)
        .accessibilityIdentifier("connectWelcomeButton")
    }
}

/// Retained text is visible even when reconnect failed. Restoration never sends.
struct SendRecoverySheet: View {
    @Bindable var connection: ConnectionStore
    let openHistory: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var checkingHistory = false
    @State private var confirmation: OpenClawChatSendRecovery?
    @State private var feedback: String?

    var body: some View {
        NavigationStack {
            List {
                if connection.isPreview {
                    Section { Text("미리보기 · 서버 미연결").foregroundStyle(.secondary) }
                }
                if connection.presentationSendRecoveries.isEmpty && connection.interruptedAttachmentSessionKeys.isEmpty {
                    Text("확인이 필요한 메시지가 없어요.")
                }
                if !connection.interruptedAttachmentSessionKeys.isEmpty {
                    Section("첨부 선택 중 연결이 끊겼어요") {
                        Text("준비가 끝난 파일과 초안은 보관했어요. 불러오는 중이던 파일은 원래 대화에서 다시 선택해 주세요.")
                            .font(.subheadline)
                        if let model = connection.model,
                           connection.interruptedAttachmentSessionKeys.contains(model.sessionKey) {
                            Button("확인했어요") {
                                model.acknowledgeInterruptedAttachmentSelection(sessionKey: model.sessionKey)
                            }
                        }
                        if connection.canSend {
                            Button("대화 목록 열기", action: openHistory)
                        } else {
                            Text("서버 연결 후 원래 대화로 돌아갈 수 있어요.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(connection.presentationSendRecoveries) { item in
                    Section {
                        Text(item.text.isEmpty ? "첨부 파일이 있는 메시지" : item.text)
                            .textSelection(.enabled)
                        if item.attachmentCount > 0 {
                            Label("첨부 파일 \(item.attachmentCount)개 보관 중", systemImage: "paperclip")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Text(item.delivery == .notSent
                            ? "전송하지 못한 내용을 보관했어요."
                            : "서버에 전달됐을 수 있어요. 다시 보내기 전에 대화 기록을 확인해 주세요.")
                            .font(.footnote).foregroundStyle(.secondary)
                        Button("메시지 복사", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = item.text
                            feedback = "메시지를 복사했어요."
                        }.disabled(item.text.isEmpty)
                        if isCurrentSession(item) {
                            Button(checkingHistory ? "기록 확인 중" : "대화 기록 확인", systemImage: "arrow.clockwise") {
                                Task { await checkHistory() }
                            }.disabled(!connection.canSend || checkingHistory)
                            Button("초안에 복원", systemImage: "square.and.pencil") {
                                if item.delivery == .unconfirmed { confirmation = item }
                                else { restore(item) }
                            }.disabled(!canRestore(item))
                            if item.isAwaitingAcknowledgement {
                                Text("이전 전송의 응답을 기다리고 있어요. 원문은 복사할 수 있어요.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            } else if connection.model?.isSubmittingDraft == true || connection.model?.isSending == true || connection.model?.isAttachmentOwnerPinned == true {
                                Text("현재 전송이나 첨부 준비가 끝나면 복원할 수 있어요.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            } else if connection.model?.input.isEmpty == false || connection.model?.attachments.isEmpty == false || connection.model?.replyTarget != nil {
                                Text("새 초안과 첨부, 답장 선택은 그대로 유지돼요. 복원하려면 먼저 입력창을 확인해 주세요.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        } else if connection.canSend {
                            Button("원래 대화 찾기", action: openHistory)
                        } else {
                            Text("연결 후 원래 대화에서 기록 확인과 초안 복원을 할 수 있어요.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let feedback { Section { Text(feedback).font(.footnote) } }
            }
            .navigationTitle("보관한 내용").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
            .confirmationDialog("이미 전달됐을 수 있어요", isPresented: Binding(
                get: { confirmation != nil }, set: { if !$0 { confirmation = nil } }),
                titleVisibility: .visible, presenting: confirmation) { item in
                Button("초안에 복원") { restore(item); confirmation = nil }
                Button("취소", role: .cancel) { confirmation = nil }
            } message: { _ in
                Text("기록에 없는 메시지도 서버에서 처리 중일 수 있어요. 복원한 내용을 전송하기 전에 중복 요청이 아닌지 확인해 주세요.")
            }
        }
    }

    private func isCurrentSession(_ item: OpenClawChatSendRecovery) -> Bool {
        connection.model?.currentSendRecoveries.contains(where: { $0.id == item.id }) == true
    }
    private func canRestore(_ item: OpenClawChatSendRecovery) -> Bool {
        connection.canSend && item.canRestore && isCurrentSession(item)
            && connection.model?.input.isEmpty == true && connection.model?.attachments.isEmpty == true
            && connection.model?.replyTarget == nil
            && connection.model?.isSubmittingDraft == false && connection.model?.isSending == false
            && connection.model?.isAttachmentOwnerPinned == false
    }
    private func restore(_ item: OpenClawChatSendRecovery) {
        guard connection.canSend, connection.model?.restoreSendRecovery(id: item.id) == true else {
            feedback = "상태가 바뀌었어요. 연결과 입력 중인 초안을 확인해 주세요."
            return
        }
        dismiss()
    }
    private func checkHistory() async {
        guard connection.canSend, let model = connection.model, !checkingHistory else { return }
        checkingHistory = true
        defer { checkingHistory = false }
        let success = await model.refreshSendRecoveryHistory()
        guard connection.model === model else { return }
        feedback = success ? "기록을 새로 확인했어요. 전달 여부가 불확실한 메시지는 계속 보관해요."
            : "기록을 불러오지 못했어요. 원문은 계속 보관해요."
    }
}

extension ConnectionStore {
    /// Read-only presentation fixture; production dispatch remains disabled.
    fileprivate var presentationSendRecoveries: [OpenClawChatSendRecovery] {
        #if DEBUG
        if isPreview && ProcessInfo.processInfo.arguments.contains("--ui-send-recovery") {
            return model?.allSendRecoveries ?? []
        }
        #endif
        return retainedSendRecoveries
    }
}

struct ConnectionSettings: View {
    @Bindable var connection: ConnectionStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focus: Field?
    @AccessibilityFocusState private var errorFocused: Bool
    @State private var validationAttempt = 0
    @State private var confirmsDisconnect = false
    private enum Field { case endpoint, token }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                Section {
                    Label(connection.status, systemImage: connection.phase == .connected ? "checkmark.circle" : "network")
                        .accessibilityIdentifier("connectionStatus")
                    if let error = connection.errorMessage {
                        Text(error).foregroundStyle(.red).font(.subheadline)
                            .accessibilityIdentifier("connectionError")
                            .accessibilityFocused($errorFocused)
                    }
                }
                .id("connectionFeedback")
                Section {
                    TextField("https://your-server.example", text: $connection.endpoint)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .endpoint).submitLabel(.next)
                        .onSubmit { focus = .token }
                        .accessibilityLabel("서버 주소").accessibilityIdentifier("endpointField")
                    SecureField("연결 토큰", text: $connection.token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .focused($focus, equals: .token).submitLabel(.done)
                        .accessibilityIdentifier("tokenField")
                } header: { Text("서버") } footer: {
                    Text("HTTPS 또는 WSS 주소를 사용해 주세요. 연결 토큰은 OpenClaw 서버에서 발급받을 수 있어요.")
                }
                .disabled(connection.phase == .connecting || connection.phase == .connected)
                Section {
                    Toggle("이 기기에 토큰 저장", isOn: $connection.rememberToken)
                        .disabled(connection.phase == .connecting || connection.phase == .connected)
                    Button("저장된 토큰 사용") { connection.useSavedToken(); validationAttempt += 1 }
                        .disabled(connection.phase == .connecting || connection.phase == .connected)
                    Button("저장된 토큰 삭제", role: .destructive) { connection.forgetToken(); validationAttempt += 1 }
                } footer: {
                    Text("선택하면 연결 성공 후 이 기기의 키체인에만 저장해요. 첫 연결 시 기기 인증 키가 생성되며, 서버에서 기기 승인이 필요할 수 있어요.")
                }
                Section {
                    if connection.phase == .connected {
                        Button("연결 해제", role: .destructive) { confirmsDisconnect = true }
                    } else if connection.phase == .connecting {
                        HStack { ProgressView(); Text("서버에 연결하는 중이에요") }
                        Button("연결 취소", role: .cancel) { Task { await connection.cancelConnection() } }
                    } else {
                        Button(connection.phase == .failed ? "다시 연결" : "연결") {
                            focus = nil
                            connection.connect()
                            validationAttempt += 1
                        }.frame(maxWidth: .infinity).accessibilityIdentifier("connectSubmit")
                    }
                }
                Section {
                    LabeledContent("앱", value: "Companion 0.2")
                    LabeledContent("연결 방식", value: "OpenClaw Gateway")
                    NavigationLink("오픈소스 라이선스") { LicensesView() }
                }
                if let model = connection.model {
                    Section("대화 설정") {
                        OpenClawChatSessionSettings(viewModel: model, isEnabled: connection.canSend)
                    }
                }
            }
            .onChange(of: validationAttempt) { _, _ in
                if connection.errorMessage != nil {
                    proxy.scrollTo("connectionFeedback", anchor: .top)
                    errorFocused = false
                    Task { @MainActor in
                        await Task.yield()
                        errorFocused = true
                    }
                }
            }
            .onChange(of: connection.errorMessage) { _, value in
                if value != nil {
                    proxy.scrollTo("connectionFeedback", anchor: .top)
                    errorFocused = true
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("연결 설정").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } } }
            .confirmationDialog("연결을 해제할까요?", isPresented: $confirmsDisconnect, titleVisibility: .visible) {
                Button("초안을 지우고 연결 해제", role: .destructive) { Task { await connection.disconnect() } }
                Button("취소", role: .cancel) {}
            } message: {
                Text("이 기기의 모든 대화 초안과 입력한 토큰이 지워져요. 키체인에 따로 저장한 토큰과 서버 대화는 유지돼요.")
            }
            .task {
                #if DEBUG
                let arguments = ProcessInfo.processInfo.arguments
                if arguments.contains("--ui-keyboard") { focus = .endpoint }
                if arguments.contains("--ui-invalid-address") {
                    connection.endpoint = "http://example.com"
                    connection.connect()
                    validationAttempt += 1
                }
                #endif
            }
            }
        }.presentationDragIndicator(.visible)
    }
}

struct ConversationHistory: View {
    @Bindable var connection: ConnectionStore
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            Group {
                if connection.model == nil {
                    ContentUnavailableView("아직 연결하지 않았어요", systemImage: "bubble.left.and.bubble.right",
                        description: Text("서버 연결 후 대화를 불러올 수 있어요."))
                } else if connection.isLoadingHistory && connection.sessions.isEmpty {
                    ProgressView("대화를 불러오는 중")
                } else if let error = connection.historyError {
                    ContentUnavailableView {
                        Label("대화를 불러오지 못했어요", systemImage: "wifi.exclamationmark")
                    } description: { Text(error) } actions: {
                        Button("다시 시도") { Task { await connection.loadHistory() } }
                    }
                } else if connection.sessions.isEmpty {
                    ContentUnavailableView("첫 이야기를 시작해 보세요", systemImage: "bubble.left",
                        description: Text("나눈 대화가 여기에 표시돼요."))
                } else {
                    List(filteredSessions) { session in
                        Button {
                            connection.openSession(session)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(title(session)).font(.body).foregroundStyle(.primary).lineLimit(2)
                                if let preview = session.lastMessagePreview, !preview.isEmpty {
                                    Text(preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                                }
                            }.padding(.vertical, 5)
                        }
                    }.listStyle(.plain).searchable(text: $search, prompt: "대화 검색")
                    .overlay {
                        if filteredSessions.isEmpty { ContentUnavailableView.search(text: search) }
                    }
                    .refreshable { await connection.loadHistory() }
                }
            }
            .navigationTitle("대화").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .top, spacing: 0) {
                if connection.isPreview {
                    Text("미리보기 · 서버 미연결").font(.footnote).foregroundStyle(.secondary)
                        .padding(10).frame(maxWidth: .infinity).background(Color(white: 0.965))
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("완료") { dismiss() } }
                if connection.canSend {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { connection.newConversation(); dismiss() } label: { Image(systemName: "square.and.pencil") }
                            .accessibilityLabel("새 대화")
                    }
                }
            }
        }.task { await connection.loadHistory() }
        .presentationDragIndicator(.visible)
    }

    private var filteredSessions: [OpenClawChatSessionEntry] {
        connection.sessions.filter { search.isEmpty || title($0).localizedCaseInsensitiveContains(search) }
    }
    private func title(_ session: OpenClawChatSessionEntry) -> String {
        session.displayName ?? session.derivedTitle ?? session.label ?? "새 대화"
    }
}
