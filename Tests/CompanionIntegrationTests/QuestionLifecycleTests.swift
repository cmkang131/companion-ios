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
    /// These are the same presentation factories and action callbacks used by
    /// ChatView and the activity sheet, not a synthetic copy of their guards.
    @Test(arguments: [OpenClawConversationQuestionScope.all, .unscoped], [false, true])
    func bothEntrypointCallbacksRefuseReadOnlyHostAndKeepAnswers(scope: OpenClawConversationQuestionScope,
                                                               skip: Bool) async throws {
        let fixture = try QuestionFixture(questionActionsAllowed: { false })
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion(sessionKey: nil, secret: true)
        card.setOtherText(questionID: "answer", value: "synthetic-retained-answer")
        let presentation = OpenClawConversationQuestionsView(viewModel: fixture.model, scope: scope)
        #expect(presentation.presentedScopes == [.unscoped])
        #expect(!fixture.model.canPerformQuestionActions)
        let callbacks = presentation.cards(for: .unscoped).actions
        if skip { await callbacks.skip(card) } else { await callbacks.submit(card) }
        // Direct model callers also cannot bypass the shared production gate.
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.leaseRequestCount == 0)
        #expect(fixture.boundary.mutations.isEmpty)
        #expect(card.status() == .pending)
        #expect(card.otherText["answer"] == "synthetic-retained-answer")
        #expect(card.errorText == nil)
    }

    @Test(arguments: [OpenClawConversationQuestionScope.all, .currentConversation], [false, true])
    func bothEntrypointCallbacksRefuseUnhealthyTransport(scope: OpenClawConversationQuestionScope,
                                                       skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "retained")
        fixture.model.healthOK = false
        let callbacks = OpenClawConversationQuestionsView(viewModel: fixture.model, scope: scope)
            .cards(for: .currentConversation).actions
        if skip { await callbacks.skip(card) } else { await callbacks.submit(card) }
        #expect(fixture.boundary.leaseRequestCount == 0)
        #expect(card.status() == .pending)
        #expect(card.otherText["answer"] == "retained")
    }

    @Test(arguments: [OpenClawConversationQuestionScope.all, .currentConversation], [false, true])
    func bothEntrypointCallbacksStillDispatchWhenConnected(scope: OpenClawConversationQuestionScope,
                                                         skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Synthetic answer")
        let callbacks = OpenClawConversationQuestionsView(viewModel: fixture.model, scope: scope)
            .cards(for: .currentConversation).actions
        let action = Task { if skip { await callbacks.skip(card) } else { await callbacks.submit(card) } }
        defer { action.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        await action.value
        #expect(fixture.boundary.leaseRequestCount == 1)
        #expect(card.status() == (skip ? .cancelled : .answered))
    }

    @Test(arguments: [OpenClawConversationQuestionScope.all, .currentConversation], [false, true])
    func permissionLossDuringRouteAcquisitionNeverDispatches(scope: OpenClawConversationQuestionScope,
                                                            skip: Bool) async throws {
        for loss in ["host", "health"] {
            var allowed = true
            let fixture = try QuestionFixture(questionActionsAllowed: { allowed })
            defer { fixture.cleanup() }
            let card = try fixture.addQuestion(secret: true)
            card.setOtherText(questionID: "answer", value: "synthetic-retained-answer")
            fixture.boundary.holdLeaseAcquisition = true
            let callbacks = OpenClawConversationQuestionsView(viewModel: fixture.model, scope: scope)
                .cards(for: .currentConversation).actions
            let action = Task { if skip { await callbacks.skip(card) } else { await callbacks.submit(card) } }
            defer { action.cancel() }
            try await self.waitUntil { fixture.boundary.leaseRequestCount == 1 }
            if loss == "host" { allowed = false } else { fixture.model.healthOK = false }
            fixture.boundary.releaseLeaseAcquisition()
            await action.value
            #expect(fixture.boundary.mutations.isEmpty)
            #expect(card.status() == .pending)
            #expect(!card.isSubmitting && !card.isSkipping)
            #expect(card.otherText["answer"] == "synthetic-retained-answer")
            #expect(card.errorText?.contains("서버 연결") == true)
        }
    }

    @Test(arguments: [OpenClawConversationQuestionScope.all, .currentConversation], [false, true])
    func retainedCallbackCannotStartForeignSessionQuestion(scope: OpenClawConversationQuestionScope,
                                                          skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion(sessionKey: "agent:main:foreign")
        card.setOtherText(questionID: "answer", value: "retained")
        let presentation = OpenClawConversationQuestionsView(viewModel: fixture.model, scope: scope)
        #expect(presentation.presentedScopes.isEmpty)
        let callbacks = presentation.cards(for: .currentConversation).actions
        if skip { await callbacks.skip(card) } else { await callbacks.submit(card) }
        #expect(fixture.boundary.leaseRequestCount == 0)
        #expect(card.status() == .pending)
    }

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

    @Test(arguments: ["{}", #"{"status":"answered","answers":{"answers":{}}}"#,
        #"{"status":"rejected"}"#, "not-json"])
    func gatewayCancellationRequiresTheCancelledContract(payload: String) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let transport = QuestionRPCTransport(boundary: fixture.boundary)
        let request = Task { () -> OpenClawChatQuestionMutationError? in
            do {
                try await transport.cancelQuestion(id: "question-a")
                Issue.record("An unconfirmed cancellation payload must not succeed")
                return nil
            } catch { return error as? OpenClawChatQuestionMutationError }
        }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.finishMutation(0, response: Data(payload.utf8))
        let error = await request.value
        #expect(error == .cancellationUnconfirmed)
    }

    @Test(arguments: ["{}", #"{"status":"answered","answers":{"answers":{}}}"#,
        #"{"status":"rejected"}"#])
    func unconfirmedSkipRemainsActionableAndRecoversInsteadOfClaimingSkipped(payload: String) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        let request = Task { await fixture.model.skipQuestion(card) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.finishMutation(0, response: Data(payload.utf8))
        await request.value

        #expect(card.status() == .pending)
        #expect(card.record.status == .pending)
        #expect(!card.isSubmitting)
        #expect(!card.isSkipping)
        #expect(card.errorText == OpenClawChatQuestionMutationError.cancellationUnconfirmed.localizedDescription)
        #expect(fixture.boundary.requests.contains { $0.method == "question.list" })
        #expect(fixture.boundary.mutations.count == 1)
    }

    @Test func unconfirmedSkipRecoversAnAuthoritativeAnswerWithoutClaimingSkipped() async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        let request = Task { await fixture.model.skipQuestion(card) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.listRecords = []
        fixture.boundary.getRecord = QuestionFixture.record(status: .answered,
            answers: QuestionAnswers(answers: ["answer": AnyCodable(["Recovered server answer"])]))
        fixture.boundary.finishMutation(0, response: Data("{}".utf8))
        await request.value
        #expect(card.status() == .answeredElsewhere)
        #expect(card.terminalSummaryText(for: card.record.questions[0]) == "Recovered server answer")
        #expect(card.errorText == nil)
        #expect(!card.isSubmitting)
    }

    @Test(arguments: ["expiry", "route"])
    func invalidatedQuestionCannotDispatchAfterDelayedLeaseAcquisition(reason: String) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        fixture.boundary.holdLeaseAcquisition = true
        let request = Task { await fixture.model.skipQuestion(card) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.leaseRequestCount == 1 }
        #expect(card.isSubmitting)
        if reason == "expiry" {
            fixture.model.expireQuestionIfNeeded(card, at: Date(
                timeIntervalSince1970: Double(card.record.expiresatms) / 1000 + 1))
        } else {
            fixture.boundary.routeID = UUID()
            fixture.model.handleTransportEvent(.routeChanged)
        }
        fixture.boundary.releaseLeaseAcquisition()
        await request.value
        #expect(fixture.boundary.mutations.isEmpty)
        #expect(card.status() == (reason == "expiry" ? .expired : .pending))
        #expect(!card.isSubmitting)
        #expect(!card.isSkipping)
    }

    @Test(arguments: [false, true], [false, true])
    func localExpiryDuringMutationAllowsOnlyConfirmedServerOutcome(skip: Bool, succeeds: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion(secret: true)
        card.setOtherText(questionID: "answer", value: "synthetic-expiring-answer")
        let request = Task { await fixture.perform(on: card, skip: skip) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.model.expireQuestionIfNeeded(card, at: Date(
            timeIntervalSince1970: Double(card.record.expiresatms) / 1000 + 1))
        #expect(card.status() == .expired)
        #expect(card.otherText.isEmpty)
        #expect(!card.isSubmitting)
        #expect(fixture.model.questionExpiryTasks.isEmpty)

        if succeeds {
            fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        } else {
            fixture.boundary.failMutation(0, error: QuestionFixture.permissionDenied(method: "question.resolve"))
        }
        await request.value
        #expect(card.status() == (succeeds ? (skip ? .cancelled : .answered) : .expired))
        #expect(card.errorText == nil)
        #expect(card.otherText.isEmpty)
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.count == 1)
    }

    @Test(arguments: [QuestionStatus.answered, .cancelled, .expired], [false, true])
    func terminalEventCannotBeOverwrittenByLateMutation(status: QuestionStatus, skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Synthetic answer")
        let request = Task { await fixture.perform(on: card, skip: skip) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.model.handleTransportEvent(.questionResolved(.init(id: card.id, status: status,
            answers: status == .answered ? QuestionAnswers(
                answers: ["answer": AnyCodable(["Authoritative event answer"])]) : nil)))
        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        await request.value

        #expect(card.record.status == status)
        #expect(!card.wasAnsweredLocally)
        #expect(card.otherText.isEmpty)
        #expect(card.errorText == nil)
        #expect(!card.isSubmitting)
        if status == .answered {
            #expect(card.terminalSummaryText(for: card.record.questions[0]) == "Authoritative event answer")
        }
        await fixture.model.submitQuestion(card)
        await fixture.model.skipQuestion(card)
        #expect(fixture.boundary.mutations.count == 1)
    }

    @Test(arguments: [false, true])
    func terminalEventIgnoresLateMutationFailure(skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Synthetic answer")
        let request = Task { await fixture.perform(on: card, skip: skip) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.model.handleTransportEvent(.questionResolved(.init(id: card.id, status: .expired)))
        fixture.boundary.failMutation(0, error: QuestionFixture.permissionDenied(method: "question.resolve"))
        await request.value
        #expect(card.status() == .expired)
        #expect(card.errorText == nil)
        #expect(!card.isSubmitting)
        #expect(!card.isSkipping)
    }

    @Test func replacedLeaseCannotDispatchOnTheNewConnection() async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let transport = QuestionRPCTransport(boundary: fixture.boundary)
        let acquired = await transport.acquireQuestionMutationRouteLease()
        let lease = try #require(acquired)
        fixture.boundary.routeID = UUID()
        do {
            try await lease.cancel("question-a")
            Issue.record("A retired question lease must not dispatch")
        } catch {
            #expect(error is OpenClawChatQuestionMutationError)
        }
        #expect(fixture.boundary.mutations.isEmpty)
    }

    @Test(arguments: [false, true])
    func replacementRouteDiscardsResponseEvenBeforeRouteEvent(skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Synthetic answer")
        let request = Task { await fixture.perform(on: card, skip: skip) }
        defer { request.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.routeID = UUID()
        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        await request.value
        #expect(card.status() == .pending)
        #expect(card.errorText == OpenClawChatQuestionMutationError.routeChanged.localizedDescription)
        #expect(!card.isSubmitting)
    }

    @Test(arguments: [false, true])
    func lateOldRouteCannotClearTheNewRoutesQuestionSubmission(skip: Bool) async throws {
        let fixture = try QuestionFixture()
        defer { fixture.cleanup() }
        let card = try fixture.addQuestion()
        card.setOtherText(questionID: "answer", value: "Old connection answer")
        let oldRequest = Task { await fixture.perform(on: card, skip: skip) }
        defer { oldRequest.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 1 }
        fixture.boundary.routeID = UUID()
        fixture.model.handleTransportEvent(.routeChanged)
        #expect(!card.isSubmitting)
        card.setOtherText(questionID: "answer", value: "New connection answer")
        let newRequest = Task { await fixture.perform(on: card, skip: skip) }
        defer { newRequest.cancel() }
        try await self.waitUntil { fixture.boundary.mutations.count == 2 }

        fixture.boundary.finishMutation(0, response: QuestionFixture.confirmedResponse(skip: skip))
        await oldRequest.value
        #expect(card.status() == .submitting)
        #expect(card.isSkipping == skip)
        #expect(card.errorText == nil)
        #expect(card.otherText["answer"] == "New connection answer")
        fixture.boundary.finishMutation(1, response: QuestionFixture.confirmedResponse(skip: skip))
        await newRequest.value
        #expect(card.status() == (skip ? .cancelled : .answered))
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

    init(questionActionsAllowed: @escaping @MainActor () -> Bool = { true }) throws {
        let boundary = QuestionRPCBoundary()
        let name = "QuestionLifecycleTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        self.boundary = boundary
        self.defaultsName = name
        self.defaults = defaults
        self.model = OpenClawChatViewModel(
            sessionKey: "agent:main:question-a", transport: QuestionRPCTransport(boundary: boundary),
            questionActionsAllowed: questionActionsAllowed,
            modelPickerStore: ChatModelPickerStore(defaults: defaults))
        self.model.healthOK = true
        self.model.questionRefreshRetryDelaysMs = []
    }

    func addQuestion(
        id: String = "question-a", sessionKey: String? = "agent:main:question-a", secret: Bool = false
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
        id: String = "question-a", sessionKey: String? = "agent:main:question-a", secret: Bool = false,
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
    var routeID = UUID()
    var holdLeaseAcquisition = false
    private(set) var leaseRequestCount = 0
    private var leaseContinuation: CheckedContinuation<UUID, Never>?
    var advertisesQuestions = true
    var listRecords: [QuestionRecord] = []
    var listError: GatewayResponseError?
    var getRecord: QuestionRecord?
    var getError: GatewayResponseError?
    private(set) var requests: [OpenClawChatGatewayRequest] = []
    private(set) var mutations: [OpenClawChatGatewayRequest] = []
    private var pending: [Int: CheckedContinuation<Data, any Error>] = [:]

    func acquireRoute() async -> UUID {
        self.leaseRequestCount += 1
        guard self.holdLeaseAcquisition else { return self.routeID }
        return await withCheckedContinuation { self.leaseContinuation = $0 }
    }

    func releaseLeaseAcquisition() {
        self.leaseContinuation?.resume(returning: self.routeID)
        self.leaseContinuation = nil
    }

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
        self.releaseLeaseAcquisition()
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

    func acquireQuestionMutationRouteLease() async -> OpenClawChatQuestionMutationRouteLease? {
        let route = await self.boundary.acquireRoute()
        let boundary = self.boundary
        // Same production lease initializer as the iOS adapter; the actual
        // Gateway socket has its own final pre-dispatch fence in addition.
        return OpenClawChatQuestionMutationRouteLease(
            request: { try await boundary.request($0) },
            isCurrent: { await boundary.routeID == route })
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
