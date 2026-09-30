import Foundation
import Testing
@testable import OpenClawChatUI
@testable import Companion

@MainActor
struct CharacterStateTests {
    @Test(arguments: ["aborted", "error", "delta"])
    func nonFinalEventsNeverAcknowledgeCompletion(state: String) throws {
        let model = OpenClawChatViewModel(sessionKey: "preview", transport: PreviewTransport())
        model.pendingRuns.insert("owned-run")
        model.handleTransportEvent(.chat(try event(state: state, runID: "owned-run", text: "fixture output")))
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    @Test func onlyOwnedFinalOutputAcknowledgesOnce() throws {
        let model = OpenClawChatViewModel(sessionKey: "preview", transport: PreviewTransport())
        model.pendingRuns.insert("owned-run")
        #expect(model.companionHasActiveResponse)
        model.handleTransportEvent(.chat(try event(state: "final", runID: "another-run", text: "unrelated")))
        #expect(model.companionRunCompletionRevision == 0)
        model.handleTransportEvent(.chat(try event(state: "final", runID: "owned-run", text: "fixture output")))
        #expect(model.companionRunCompletionRevision == 1)
        model.handleTransportEvent(.chat(try event(state: "final", runID: "owned-run", text: "duplicate")))
        #expect(model.companionRunCompletionRevision == 1)
        model.detachTransport()
        #expect(!model.companionHasActiveResponse)
    }

    @Test func emptyFinalAndDetachedTransportNeverAcknowledge() throws {
        let model = OpenClawChatViewModel(sessionKey: "preview", transport: PreviewTransport())
        model.pendingRuns.insert("owned-run")
        model.handleTransportEvent(.chat(try event(state: "final", runID: "owned-run", text: " ")))
        #expect(model.companionRunCompletionRevision == 0)
        model.pendingRuns.insert("late-run")
        model.detachTransport()
        model.handleTransportEvent(.chat(try event(state: "final", runID: "late-run", text: "late")))
        #expect(model.companionRunCompletionRevision == 0)
        #expect(!model.companionHasActiveResponse)
    }

    @Test(arguments: [(true, false), (false, true), (true, true)])
    func missingCorrelationNeverAcknowledges(missingRun: Bool, missingSession: Bool) throws {
        let model = OpenClawChatViewModel(sessionKey: "preview", transport: PreviewTransport())
        model.pendingRuns.insert("owned-run")
        model.handleTransportEvent(.chat(try event(state: "final", runID: missingRun ? nil : "owned-run",
            text: "unattributed output", session: missingSession ? nil : "preview")))
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    @Test func foreignSessionOrLateFinalNeverAcknowledges() throws {
        let model = OpenClawChatViewModel(sessionKey: "preview", transport: PreviewTransport())
        model.pendingRuns.insert("owned-run")
        model.handleTransportEvent(.chat(try event(state: "final", runID: "owned-run",
            text: "foreign session", session: "agent:main:other")))
        #expect(model.companionRunCompletionRevision == 0)
        model.pendingRuns.insert("old-run")
        model.switchSession(to: "agent:main:new")
        model.handleTransportEvent(.chat(try event(state: "final", runID: "old-run", text: "late output")))
        #expect(model.companionRunCompletionRevision == 0)
        model.detachTransport()
    }

    private func event(state: String, runID: String?, text: String, session: String? = "preview") throws -> OpenClawChatEventPayload {
        var value: [String: Any] = ["state": state,
            "message": ["role": "assistant", "content": [["type": "text", "text": text]]]]
        value["runId"] = runID
        value["sessionKey"] = session
        return try JSONDecoder().decode(OpenClawChatEventPayload.self,
            from: JSONSerialization.data(withJSONObject: value))
    }
}
