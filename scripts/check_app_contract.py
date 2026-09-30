#!/usr/bin/env python3
"""Narrow static guard for the data-preserving cancel button. Not a UI test."""
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
