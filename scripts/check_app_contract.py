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
            and 'OpenClawConversationQuestionsView(viewModel: model)' in source
            and '.accessibilityIdentifier("activityHeaderButton")' in source
            and 'Button { sheet = .activity } label: { HStack' in source)

assert activity_is_wired(source), 'Activity must expose the guarded production stop/refresh and question paths'
assert not activity_is_wired(source.replace('model.requestStopCurrentRuns()', 'model.abort()'))
assert not activity_is_wired(source.replace('Button { sheet = .activity } label: { HStack',
                                           'Button { sheet = .connection } label: { HStack'))
print('PASS: activity header/production control wiring and mutations (source check only; no taps)')
