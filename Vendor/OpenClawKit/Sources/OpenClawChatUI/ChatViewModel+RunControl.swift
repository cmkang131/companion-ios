import Foundation
import OpenClawKit

struct ChatRunControlRequest {
    enum Outcome: Equatable { case requested, stopped, ended, failed, unconfirmed }
    var id = UUID()
    let session: OpenClawChatViewModel.SessionSnapshot
    let runIDs: Set<String>
    let sequenceFloors: [String: Int]
    var outcomes: [String: Outcome] = [:]
    var lease: OpenClawChatRunControlRouteLease?
}

extension OpenClawChatViewModel {
    private var confirmedStoppedOrEndedRunIDs: Set<String> {
        guard let request = companionRunControl, isCurrentSession(request.session) else { return [] }
        return Set(request.outcomes.compactMap { id, outcome in
            outcome == .stopped || outcome == .ended ? id : nil
        })
    }

    private var stoppableRunIDs: Set<String> {
        // A local send UUID is not proof that the server owns a run yet.
        let awaitingACK = Set(sendRecoveryLedger.entries.filter(\.isAwaitingAcknowledgement).map(\.id))
        return liveLocalRunIDs.union(liveAdvertisedRunIDs).subtracting(awaitingACK)
            .subtracting(confirmedStoppedOrEndedRunIDs)
    }

    public var companionRunActivity: OpenClawChatRunActivity {
        let request = companionRunControl.flatMap { isCurrentSession($0.session) ? $0 : nil }
        let priorState = companionStopState(for: request)
        let hasNewRun = !stoppableRunIDs.subtracting(request?.runIDs ?? []).isEmpty
        let state: OpenClawChatStopState = hasNewRun && (priorState == .stopped || priorState == .ended)
            ? .idle : priorState
        let available = !isTransportDetached && !usesWebConversation
        let knownCount = available ? stoppableRunIDs.count : 0
        let isRefreshing = companionRunControlRefreshID != nil
        return OpenClawChatRunActivity(
            hasActiveRun: available && (hasActiveSessionRunWithoutChatSnapshot ||
                !liveLocalRunIDs.union(liveAdvertisedRunIDs).subtracting(confirmedStoppedOrEndedRunIDs).isEmpty),
            knownRunCount: knownCount,
            requestedRunCount: state == .idle ? 0 : request?.runIDs.count ?? 0,
            stopState: state,
            canStop: available && healthOK && knownCount > 0 && !isAborting && !isRefreshing && state != .requested,
            canRefresh: available && !isAborting && !isRefreshing,
            isRefreshing: isRefreshing)
    }

    private func companionStopState(for request: ChatRunControlRequest?) -> OpenClawChatStopState {
        guard let request else { return .idle }
        let outcomes = request.runIDs.compactMap { request.outcomes[$0] }
        if outcomes.count == request.runIDs.count {
            if outcomes.allSatisfy({ $0 == .stopped }) { return .stopped }
            if outcomes.allSatisfy({ $0 == .stopped || $0 == .ended }) { return .ended }
        }
        if isAborting { return .requesting }
        if outcomes.contains(.unconfirmed) { return .unconfirmed }
        if outcomes.contains(.failed) {
            return outcomes.contains(.requested) ? .unconfirmed : .failed
        }
        return outcomes.contains(.requested) ? .requested : .unconfirmed
    }

    /// Reserves the current conversation and exact known runs synchronously,
    /// before a button's asynchronous work can race navigation. Never resends.
    @discardableResult
    public func requestStopCurrentRuns() -> Task<Void, Never>? {
        guard companionRunActivity.canStop else { return nil }
        let runIDs = stoppableRunIDs
        let request = ChatRunControlRequest(session: currentSessionSnapshot(), runIDs: runIDs,
            sequenceFloors: Dictionary(uniqueKeysWithValues: runIDs.map { ($0, liveRunStateByRunID[$0]?.sequence ?? 0) }))
        companionRunControl = request
        isAborting = true
        let transport = self.transport
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performStopRequest(request, transport: transport)
        }
        companionRunControlTask = task
        return task
    }

    private func ownsStopRequest(_ request: ChatRunControlRequest) -> Bool {
        isCurrentSession(request.session) && companionRunControl?.id == request.id
    }

    private func performStopRequest(_ request: ChatRunControlRequest, transport: any OpenClawChatTransport) async {
        defer {
            if ownsStopRequest(request) {
                isAborting = false
                companionRunControlTask = nil
            }
        }
        guard ownsStopRequest(request) else { return }
        guard !Task.isCancelled, let lease = await transport.acquireRunControlRouteLease() else {
            for runID in request.runIDs { recordStopOutcome(.failed, runID: runID, request: request) }
            return
        }
        guard ownsStopRequest(request) else { return }
        companionRunControl?.lease = lease
        for runID in request.runIDs.sorted() {
            guard ownsStopRequest(request) else { return }
            if companionRunControl?.outcomes[runID] == .stopped || companionRunControl?.outcomes[runID] == .ended {
                continue
            }
            guard !Task.isCancelled, stoppableRunIDs.contains(runID) else {
                recordStopOutcome(.unconfirmed, runID: runID, request: request)
                continue
            }
            do {
                let receipt = try await lease.requestStop(request.session.key, request.session.deliveryAgentID, runID)
                guard ownsStopRequest(request) else { return }
                recordStopOutcome(!Task.isCancelled && receipt == .requested ? .requested : .unconfirmed,
                    runID: runID, request: request)
            } catch {
                guard ownsStopRequest(request) else { return }
                let outcome: ChatRunControlRequest.Outcome =
                    error is OpenClawChatRunControlError || error is GatewayResponseError ? .failed : .unconfirmed
                recordStopOutcome(outcome, runID: runID, request: request)
            }
        }
    }

    private func recordStopOutcome(_ outcome: ChatRunControlRequest.Outcome, runID: String,
                                   request: ChatRunControlRequest) {
        guard ownsStopRequest(request), request.runIDs.contains(runID),
              companionRunControl?.outcomes[runID] != .stopped,
              companionRunControl?.outcomes[runID] != .ended else { return }
        companionRunControl?.outcomes[runID] = outcome
    }

    /// Explicit, read-only confirmation. A missing history row never proves
    /// cancellation; only a terminal observation tied to the exact run does.
    @discardableResult
    public func refreshCurrentRunActivity() -> Task<Void, Never>? {
        guard companionRunActivity.canRefresh else { return nil }
        let refreshID = UUID()
        companionRunControlRefreshID = refreshID
        let session = currentSessionSnapshot()
        let request = companionRunControl
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.companionRunControlRefreshID == refreshID {
                    self.companionRunControlRefreshID = nil
                    self.companionRunControlRefreshTask = nil
                }
            }
            guard !Task.isCancelled, self.isCurrentSession(session) else { return }
            if let request, self.ownsStopRequest(request) {
                // Confirmation keeps the original mutation route. A new socket
                // may refresh history, but cannot attest an old route's Stop.
                let lease = request.lease
                for runID in request.runIDs.sorted() {
                    let observation = await lease?.observe(runID) ?? .unavailable
                    guard !Task.isCancelled, self.ownsStopRequest(request),
                          self.companionRunControlRefreshID == refreshID else { return }
                    switch observation {
                    case .stopped: self.recordStopOutcome(.stopped, runID: runID, request: request)
                    case .ended: self.recordStopOutcome(.ended, runID: runID, request: request)
                    case .unavailable: self.recordStopOutcome(.unconfirmed, runID: runID, request: request)
                    case .active: break
                    }
                }
            }
            guard !Task.isCancelled, self.isCurrentSession(session),
                  self.companionRunControlRefreshID == refreshID else { return }
            await self.refreshHistoryAfterRun(historyRequest: self.beginHistoryRequest(for: session))
        }
        companionRunControlRefreshTask = task
        return task
    }

    /// Observes strict evidence separately from the upstream compatibility
    /// cleanup. Legacy missing-ID events may clean up there, never confirm Stop.
    func observeCompanionRunControlEvent(_ event: OpenClawChatTransportEvent) {
        switch event {
        case .routeChanged, .seqGap, .health(false):
            invalidateCompanionRunControl(preservingUncertainty: true)
            return
        default: break
        }
        guard let request = companionRunControl, ownsStopRequest(request) else { return }
        let runID: String
        let sessionKey: String
        let agentID: String?
        let outcome: ChatRunControlRequest.Outcome
        switch event {
        case let .chat(chat):
            guard let id = ChatPayloadDecoding.trimmedNonEmptyString(chat.runId),
                  let key = ChatPayloadDecoding.trimmedNonEmptyString(chat.sessionKey) else { return }
            runID = id
            sessionKey = key
            agentID = chat.agentId
            switch chat.state {
            case "aborted": outcome = .stopped
            case "final", "error": outcome = .ended
            default: return
            }
        case let .agent(agent):
            guard agent.stream == "lifecycle", let sequence = agent.seq,
                  sequence > max(request.sequenceFloors[agent.runId] ?? 0,
                                 liveRunStateByRunID[agent.runId]?.sequence ?? 0),
                  let key = ChatPayloadDecoding.trimmedNonEmptyString(agent.data["sessionKey"]?.stringValue)
            else { return }
            runID = agent.runId
            sessionKey = key
            agentID = agent.data["agentId"]?.stringValue
            let phase = agent.data["phase"]?.stringValue?.lowercased()
            let status = agent.data["status"]?.stringValue?.lowercased()
            if agent.data["aborted"]?.boolValue == true || phase == "aborted" || status == "aborted" {
                outcome = .stopped
            } else if ["end", "complete", "completed", "error", "failed"].contains(phase ?? "") ||
                ["ok", "success", "succeeded", "complete", "completed", "error", "failed"].contains(status ?? "") {
                outcome = .ended
            } else { return }
        default: return
        }
        guard request.runIDs.contains(runID),
              matchesCurrentSessionKey(incoming: sessionKey, agentId: agentID, current: request.session.key)
        else { return }
        recordStopOutcome(outcome, runID: runID, request: request)
    }

    func invalidateCompanionRunControl(preservingUncertainty: Bool = false) {
        companionRunControlTask?.cancel()
        companionRunControlTask = nil
        companionRunControlRefreshTask?.cancel()
        companionRunControlRefreshTask = nil
        companionRunControlRefreshID = nil
        isAborting = false
        if preservingUncertainty, var request = companionRunControl {
            request.id = UUID()
            for runID in request.runIDs where request.outcomes[runID] != .stopped && request.outcomes[runID] != .ended {
                request.outcomes[runID] = .unconfirmed
            }
            companionRunControl = request
        } else { companionRunControl = nil }
    }
}
