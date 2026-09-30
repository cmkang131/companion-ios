#!/usr/bin/env python3
"""Narrow source guards for data-preserving cancel and activity wiring. Not UI tests."""
from pathlib import Path
import re

def cancellation_is_safe(source):
    match = re.search(r'Button\("연결 취소"[^\n]+', source)
    return bool(match and 'connection.cancelConnection()' in match[0]
                and 'connection.disconnect()' not in match[0])

root = Path(__file__).resolve().parents[1]
source = (root / 'Sources/Companion/CompanionApp.swift').read_text()
assert cancellation_is_safe(source), 'Cancel button must preserve drafts via cancelConnection()'
assert not cancellation_is_safe(source.replace('connection.cancelConnection()', 'connection.disconnect()'))
print('PASS: production cancel button wiring and destructive mutation guard (source check only)')

def activity_is_wired(source):
    return ('case .activity: ConversationActivitySheet(connection: connection)' in source
            and 'model.requestStopCurrentRuns()' in source
            and 'model.refreshCurrentRunActivity()' in source
            and '.disabled(!connection.canSend || !activity.canStop)' in source
            and 'OpenClawConversationQuestionsView(viewModel: model, scope: .currentConversation)' in source
            and 'OpenClawConversationQuestionsView(viewModel: model, scope: .unscoped)' in source
            and '.accessibilityIdentifier("activityHeaderButton")' in source
            and 'Button { sheet = .activity } label: { HStack' in source)

assert activity_is_wired(source), 'Activity must expose the guarded production stop/refresh and question paths'
assert not activity_is_wired(source.replace('model.requestStopCurrentRuns()', 'model.abort()'))
assert not activity_is_wired(source.replace('Button { sheet = .activity } label: { HStack',
                                           'Button { sheet = .connection } label: { HStack'))
print('PASS: activity header/production control wiring and mutations (source check only; no taps)')

# Both native entry points must share scope labels AND the model-backed action
# callbacks. This is a narrow wiring guard, complemented by executable callback
# and ConnectionStore regressions; it does not prove taps or accessibility.
chat = (root / 'Vendor/OpenClawKit/Sources/OpenClawChatUI/ChatView.swift').read_text()
questions = (root / 'Vendor/OpenClawKit/Sources/OpenClawChatUI/ChatQuestionCard.swift').read_text()
store = (root / 'Sources/Companion/ConnectionStore.swift').read_text()

def questions_are_shared(app, chat, questions, store):
    return ('OpenClawConversationQuestionsView(viewModel: self.viewModel, scope: .all)' in chat
            and 'OpenClawQuestionCards(' not in chat
            and 'OpenClawConversationQuestionsView(viewModel: model, scope: .currentConversation)' in app
            and 'OpenClawConversationQuestionsView(viewModel: model, scope: .unscoped)' in app
            and '대화가 지정되지 않은 질문' in questions
            and 'scope.explanation(isKorean:' in questions
            and 'self.cards(for: scope)' in questions
            and 'onSubmit: self.actions.submit, onSkip: self.actions.skip' in questions
            and '.disabled(!self.viewModel.canPerformQuestionActions)' in questions
            and questions.count('guard self.canPerformQuestionActions,') == 2
            and questions.count('guard self.canPerformQuestionActions else') == 2
            and 'questionActionsAllowed: { [weak self]' in store
            and 'return self.canSend && self.generation == owner' in store
            and store.count('OpenClawChatViewModel(sessionKey:') == 1)

assert questions_are_shared(source, chat, questions, store)
assert not questions_are_shared(source, chat.replace('OpenClawConversationQuestionsView', 'OpenClawQuestionCards'), questions, store)
assert not questions_are_shared(source.replace('scope: .unscoped', 'scope: .all'), chat, questions, store)
assert not questions_are_shared(source, chat, questions.replace('guard self.canPerformQuestionActions,', 'guard true,'), store)
assert not questions_are_shared(source, chat, questions, store.replace('return self.canSend &&', 'return true &&'))
print('PASS: transcript/activity share scope explanation and production action gate; bypass mutations rejected (source check only)')
