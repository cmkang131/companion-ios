import Foundation
import OpenClawKit
import OpenClawProtocol
import Testing
@testable import OpenClawChatUI

/// Holds only the RPC boundary. The production view model, question card,
/// request encoder, and response decoder perform recovery and mutations.
/// These synthetic replies do not establish live question or approval support.
@MainActor
struct QuestionLifecycleTests {
    @Test(arguments: [false, true])
    func unavailableRecoveryRetiresPendingControls(unadvertised: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Unsubmitted answer")
        fixture.boundary.advertisesQuestions = !unadvertised
        fixture.boundary.listError = QuestionFixture.permissionDenied(method: "question.list")

        await fixture.model.refreshQuestions()

        #expect(fixture.boundary.requests.filter { $0.method == "question.list" }.count ==
            (unadvertised ? 0 : 1))
        #expect(fixture.model.questionCards.isEmpty)
        #expect(card.status() == .unavailable)
        #expect(card.otherText.isEmpty)
        #expect(fixture.model.questionExpiryTasks.isEmpty)
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.isEmpty)
    }

    @Test(arguments: ["answered", "expired", "notFound"])
    func missingPendingQuestionRecoversThroughGet(outcome: String) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Unsubmitted answer")
        fixture.boundary.listRecords = []
        if outcome == "notFound" {
            fixture.boundary.getError = GatewayResponseError(
                method: "question.get", code: "INVALID_REQUEST", message: "Synthetic missing question",
                details: ["reason": AnyCodable("QUESTION_NOT_FOUND")])
        } else {
            fixture.boundary.getRecord = QuestionFixture.record(
                status: outcome == "answered" ? .answered : .expired,
                answers: outcome == "answered" ? QuestionAnswers(
                    answers: ["answer": AnyCodable(["Confirmed elsewhere"])]) : nil)
        }

        await fixture.model.refreshQuestions()

        let get = try #require(fixture.boundary.requests.first { $0.method == "question.get" })
        #expect(get.params["id"]?.value as? String == card.id)
        #expect(card.status() == (outcome == "answered" ? .answeredElsewhere :
            outcome == "expired" ? .expired : .unavailable))
        #expect(card.otherText.isEmpty)
        #expect(!card.canSubmit)
        #expect(fixture.model.questionCards.first === card)
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.isEmpty)
        if outcome == "answered" {
            #expect(card.terminalSummaryText(for: card.record.questions[0]) == "Confirmed elsewhere")
        }
    }

    @Test(arguments: [false, true])
    func answerAndSkipAreSingleFlightAndTerminal(skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "  Synthetic answer  ")
        let action = Task { await fixture.perform(on: card, skip: skip) }
        defer { action.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }

        #expect(card.status() == .submitting)
        #expect(card.isSkipping == skip)
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.count == 1)
        let request = try #require(fixture.boundary.mutations.first)
        #expect(request.method == "question.resolve")
        #expect(request.params["id"]?.value as? String == card.id)
        if skip {
            #expect(request.params["cancel"]?.value as? Bool == true)
            #expect(request.params["answers"] == nil)
        } else {
            let encoded = try JSONEncoder().encode(request.params)
            let object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            #expect(object["answers"] as? [String: [String: [String]]] ==
                ["answers": ["answer": ["Synthetic answer"]]])
            #expect(request.params["cancel"] == nil)
        }
        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        await action.value

        #expect(card.status() == (skip ? .cancelled : .answered))
        #expect(card.otherText.isEmpty)
        #expect(!card.isSubmitting)
        #expect(!card.isSkipping)
        #expect(fixture.model.questionExpiryTasks.isEmpty)
        if !skip {
            #expect(card.terminalSummaryText(for: card.record.questions[0]) == "Gateway-normalized answer")
        }
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.count == 1)
        #expect(fixture.model.messages.isEmpty)
    }

    @Test(arguments: [false, true])
    func deniedMutationClearsSecretDraftAndAllowsFreshAttempt(skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion(secret: true)
        card.setOtherText(questionID: "answer", value: "synthetic-not-a-credential")
        fixture.model.input = "Unrelated chat draft"
        fixture.model.errorText = "Unrelated chat notice"
        let action = Task { await fixture.perform(on: card, skip: skip) }
        defer { action.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.failMutation(0, error: QuestionFixture.permissionDenied(method: "question.resolve"))
        await action.value

        #expect(card.status() == .pending)
        #expect(!card.isSubmitting)
        #expect(!card.isSkipping)
        #expect(card.errorText?.isEmpty == false)
        #expect(card.otherText.isEmpty)
        #expect(!card.canSubmit)
        #expect(fixture.model.input == "Unrelated chat draft")
        #expect(fixture.model.errorText == "Unrelated chat notice")

        card.setOtherText(questionID: "answer", value: "fresh-synthetic-answer")
        #expect(card.errorText == nil)
        let retry = Task { await fixture.perform(on: card, skip: skip) }
        defer { retry.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 2 }
        fixture.boundary.finishMutation(1, response: QuestionFixture.confirmedResponse(skip: skip))
        await retry.value
        #expect(card.status() == (skip ? .cancelled : .answered))
        #expect(card.otherText.isEmpty)
    }

    @Test(arguments: [false, true], [false, true])
    func detachedOwnerDiscardsLateMutation(skip: Bool, fails: Bool) async throws {
        let fixture = try QuestionFixture()
        let replacement = try QuestionFixture()
        defer { fixture.cleanup(); replacement.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Synthetic answer")
        let action = Task { await fixture.perform(on: card, skip: skip) }
        defer { action.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.model.detachTransport()
        replacement.model.input = "Replacement owner draft"
        replacement.model.errorText = "Replacement owner notice"
        if fails {
            fixture.boundary.failMutation(0, error: QuestionFixture.permissionDenied(method: "question.resolve"))
        } else {
            fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        }
        await action.value

        #expect(card.status() == .unavailable)
        #expect(card.errorText == nil)
        #expect(fixture.model.questionCards.isEmpty)
        #expect(fixture.model.questionExpiryTasks.isEmpty)
        #expect(replacement.model.input == "Replacement owner draft")
        #expect(replacement.model.errorText == "Replacement owner notice")
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.count == 1)
        #expect(replacement.boundary.mutations.isEmpty)
    }

    @Test func sameConnectionSessionSwitchKeepsTheOriginalQuestionCompletion() async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let source = try fixture.addQuestion()
        let destination = try fixture.addQuestion(id: "question-b", sessionKey: "agent:main:question-b")
        source.setOtherText(questionID: "answer", value: "Answer for conversation A")
        destination.setOtherText(questionID: "answer", value: "Draft for conversation B")
        let action = Task { await fixture.model.submitQuestion(source) }
        defer { action.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }

        fixture.model.switchSession(to: "agent:main:question-b")
        try await self.waitUntil { !fixture.model.isLoading }
        fixture.model.input = "Conversation B chat draft"
        #expect(fixture.model.visibleQuestionCards.map(\.id) == [destination.id])
        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: false))
        await action.value

        // Question authority belongs to the connection. Moving between its
        // sessions must not discard an acknowledged answer to the source card.
        #expect(source.status() == .answered)
        #expect(destination.status() == .pending)
        #expect(destination.otherText["answer"] == "Draft for conversation B")
        #expect(fixture.model.input == "Conversation B chat draft")
        #expect(fixture.model.visibleQuestionCards.map(\.id) == [destination.id])
        #expect(fixture.boundary.mutations[0].params["id"]?.value as? String == source.id)
    }

    @Test(arguments: [false, true])
    func confirmedMutationOutranksUnavailableRecoveryWithoutReinsertingCard(skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Synthetic answer")
        let action = Task { await fixture.perform(on: card, skip: skip) }
        defer { action.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.listError = QuestionFixture.permissionDenied(method: "question.list")
        await fixture.model.refreshQuestions()
        #expect(card.status() == .unavailable)
        #expect(fixture.model.questionCards.isEmpty)

        // Upstream intentionally gives a confirmed mutation priority over a
        // concurrent recovery failure, while detached authority is fenced above.
        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        await action.value
        #expect(card.status() == (skip ? .cancelled : .answered))
        #expect(fixture.model.questionCards.isEmpty)
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.count == 1)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !condition() {
            try #require(ContinuousClock.now < deadline, "Timed out waiting for the synthetic question RPC")
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

@MainActor
private final class QuestionFixture {
    let boundary: QuestionRPCBoundary
    let model: OpenClawChatViewModel
    private let defaultsName: String
    private let defaults: UserDefaults

    init() throws {
        let boundary = QuestionRPCBoundary()
        let name = "QuestionLifecycleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        self.boundary = boundary
        self.defaultsName = name
        self.defaults = defaults
        self.model = OpenClawChatViewModel(
            sessionKey: "agent:main:question-a", transport: QuestionRPCTransport(boundary: boundary),
            modelPickerStore: ChatModelPickerStore(defaults: defaults))
        self.model.questionRefreshRetryDelaysMs = []
    }

    func addQuestion(
        id: String = "question-a", sessionKey: String = "agent:main:question-a", secret: Bool = false
    ) throws -> OpenClawQuestionCardModel {
        let record = Self.record(id: id, sessionKey: sessionKey, secret: secret)
        self.boundary.listRecords.append(record)
        self.model.upsertQuestion(record)
        return try #require(self.model.questionCards.first { $0.id == id })
    }

    func perform(on card: OpenClawQuestionCardModel, skip: Bool) async {
        if skip { await self.model.skipQuestion(card) } else { await self.model.submitQuestion(card) }
    }

    func cleanup() {
        self.model.detachTransport()
        self.boundary.finishAll()
        self.defaults.removePersistentDomain(forName: self.defaultsName)
    }

    static func record(
        id: String = "question-a", sessionKey: String = "agent:main:question-a", secret: Bool = false,
        status: QuestionStatus = .pending, answers: QuestionAnswers? = nil
    ) -> QuestionRecord {
        QuestionRecord(
            id: id, questions: [.init(questionid: "answer", header: "Synthetic question",
                question: "Provide an answer", options: [], issecret: secret)],
            agentid: "main", sessionkey: sessionKey,
            createdatms: 1, expiresatms: Int(Date().addingTimeInterval(3600).timeIntervalSince1970 * 1000),
            status: status, answers: answers)
    }

    static func permissionDenied(method: String) -> GatewayResponseError {
        GatewayResponseError(method: method, code: "FORBIDDEN", message: "Synthetic permission denial",
            details: ["code": AnyCodable("MISSING_SCOPE"), "missingScope": AnyCodable("operator.questions"),
                "requiredScopes": AnyCodable(["operator.questions"])])
    }

    static func confirmedResponse(skip: Bool) -> Data {
        Data((skip ? #"{"status":"cancelled"}"# :
            #"{"status":"answered","answers":{"answers":{"answer":["Gateway-normalized answer"]}}}"#).utf8)
    }
}

@MainActor
private final class QuestionRPCBoundary {
    var advertisesQuestions = true
    var listRecords: [QuestionRecord] = []
    var listError: GatewayResponseError?
    var getRecord: QuestionRecord?
    var getError: GatewayResponseError?
    private(set) var requests: [OpenClawChatGatewayRequest] = []
    private(set) var mutations: [OpenClawChatGatewayRequest] = []
    private var pending: [Int: CheckedContinuation<Data, any Error>] = [:]

    func request(_ request: OpenClawChatGatewayRequest) async throws -> Data {
        self.requests.append(request)
        switch request.method {
        case "question.list":
            if let error = self.listError { throw error }
            return try JSONEncoder().encode(QuestionListResult(questions: self.listRecords))
        case "question.get":
            if let error = self.getError { throw error }
            guard let record = self.getRecord else { throw CancellationError() }
            return try JSONEncoder().encode(QuestionGetResult(question: record))
        case "question.resolve":
            let index = self.mutations.count
            self.mutations.append(request)
            return try await withCheckedThrowingContinuation { self.pending[index] = $0 }
        default:
            // Session switching also subscribes and starts unrelated metadata
            // reads. They are outside this boundary and receive no synthetic data.
            throw CancellationError()
        }
    }

    func finishMutation(_ index: Int, response: Data) {
        self.pending.removeValue(forKey: index)?.resume(returning: response)
    }

    func failMutation(_ index: Int, error: any Error) {
        self.pending.removeValue(forKey: index)?.resume(throwing: error)
    }

    func finishAll() {
        for index in Array(self.pending.keys) { self.failMutation(index, error: CancellationError()) }
    }
}

private struct QuestionRPCTransport: OpenClawChatGatewayTransport {
    let boundary: QuestionRPCBoundary
    var chatGatewayAgentID: String? { "main" }

    func sessionTarget(for sessionKey: String, overrideAgentID: String?) -> OpenClawChatSessionTarget {
        OpenClawChatSessionTarget(sessionKey: sessionKey, agentID: overrideAgentID)
    }

    func requestChatGateway(_ request: OpenClawChatGatewayRequest) async throws -> Data {
        try await self.boundary.request(request)
    }

    func gatewayAdvertisesMethod(_ method: String) async -> Bool? {
        guard method == "question.list" else { return nil }
        return await self.boundary.advertisesQuestions
    }

    func events() -> AsyncStream<OpenClawChatTransportEvent> { AsyncStream { $0.finish() } }
    func requestHealth(timeoutMs: Int) async throws -> Bool { throw CancellationError() }
    func requestHistory(sessionKey: String) async throws -> OpenClawChatHistoryPayload { throw CancellationError() }
    func sendMessage(sessionKey: String, message: String, thinking: String, idempotencyKey: String,
                     attachments: [OpenClawChatAttachmentPayload]) async throws -> OpenClawChatSendResponse {
        Issue.record("Question lifecycle tests must not send chat messages")
        throw CancellationError()
    }
}
