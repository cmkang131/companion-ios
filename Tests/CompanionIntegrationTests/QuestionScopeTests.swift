import Foundation
import OpenClawProtocol
import Testing
@testable import OpenClawChatUI
@testable import Companion

@MainActor
struct QuestionScopeTests {
    @Test func unscopedQuestionsNeverAcquireCurrentConversationLabel() {
        let model = OpenClawChatViewModel(sessionKey: "agent:main:a", transport: PreviewTransport())
        defer { model.detachTransport() }
        model.upsertQuestion(record("a", session: "agent:main:a"))
        model.upsertQuestion(record("b", session: "agent:main:b"))
        model.upsertQuestion(record("unknown", session: nil))
        #expect(model.visibleQuestionCards(scope: .currentConversation).map(\.id) == ["a"])
        #expect(model.visibleQuestionCards(scope: .unscoped).map(\.id) == ["unknown"])
        #expect(Set(model.visibleQuestionCards(scope: .all).map(\.id)) == ["a", "unknown"])
        model.switchSession(to: "agent:main:b")
        #expect(model.visibleQuestionCards(scope: .currentConversation).map(\.id) == ["b"])
        #expect(model.visibleQuestionCards(scope: .unscoped).map(\.id) == ["unknown"])
    }

    @Test func scopeProjectionReusesQuestionIdentityAndPreservesDraft() throws {
        let model = OpenClawChatViewModel(sessionKey: "agent:main:a", transport: PreviewTransport())
        defer { model.detachTransport() }
        model.upsertQuestion(record("unknown", session: nil))
        let original = try #require(model.visibleQuestionCards.first)
        original.setOtherText(questionID: "detail", value: "draft stays with this question")
        let separate = try #require(model.visibleQuestionCards(scope: .unscoped).first)
        #expect(separate === original)
        #expect(separate.otherText["detail"] == "draft stays with this question")
        #expect(model.visibleQuestionCards(scope: .currentConversation).isEmpty)
        #expect(separate.status() == .pending)
    }

    private func record(_ id: String, session: String?) -> QuestionRecord {
        QuestionRecord(id: id, questions: [Question(questionid: "detail", header: "Details",
            question: "Synthetic scope check", options: [], isother: true)],
            agentid: "main", sessionkey: session, createdatms: 1,
            expiresatms: 4_000_000_000_000, status: .pending)
    }
}
