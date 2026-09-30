#!/usr/bin/env python3
"""Capture labelled Debug fixtures on this task's dedicated Simulator only.
Screenshots establish rendering, not taps, live Gateway behavior, or OS accessibility.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path
import subprocess
import time

DEVICE = '022EC407-377F-4563-A350-CD12D1BA7795'
DEVICE_NAME = 'Companion Recovery Task5'
BUNDLE = 'com.cmkang131.companion'
MODES = {
    'compact': ('large', ['--ui-preview']),
    'ax5-welcome': ('accessibility-extra-extra-extra-large', []),
    'ax5-chat': ('accessibility-extra-extra-extra-large', ['--ui-preview']),
    'recovery': ('large', ['--ui-preview', '--ui-send-recovery']),
    'artifact': ('large', ['--ui-preview', '--ui-artifact-preview']),
    'keyboard': ('large', ['--ui-settings', '--ui-keyboard']),
    'settings': ('large', ['--ui-preview', '--ui-settings']),
}

def run(args, allowed=(0,)):
    result = subprocess.run(args, capture_output=True, text=True, timeout=20)
    if result.returncode not in allowed:
        raise RuntimeError(f'{args[:4]} failed ({result.returncode}): {result.stderr.strip()}')
    return result.stdout.strip()

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

parser = argparse.ArgumentParser()
parser.add_argument('--output', required=True, type=Path)
parser.add_argument('--source', required=True)
parser.add_argument('--mode', action='append', choices=MODES)
args = parser.parse_args()
assert run(['git', 'rev-parse', 'HEAD']) == args.source
assert not run(['git', 'diff', '--name-only', 'HEAD']), 'Commit source changes before capture'
devices = json.loads(run(['xcrun', 'simctl', 'list', 'devices', '-j']))
device = next(d for group in devices['devices'].values() for d in group if d['udid'] == DEVICE)
assert device['name'] == DEVICE_NAME and device['state'] == 'Booted'
installed = Path(run(['xcrun', 'simctl', 'get_app_container', DEVICE, BUNDLE, 'app']))
built = Path('.build-xcode/Build/Products/Debug-iphonesimulator/Companion.app/Companion')
assert sha(installed / 'Companion') == sha(built), 'Installed executable differs from current build'
args.output.mkdir(parents=True, exist_ok=True)
index = args.output / 'captures.json'
data = json.loads(index.read_text()) if index.exists() else {
    'source_commit': args.source, 'simulator_id': DEVICE, 'simulator_name': DEVICE_NAME,
    'built_executable_sha256': sha(built), 'installed_executable_sha256': sha(installed / 'Companion'),
    'captures': [], 'limits': ['Debug synthetic fixtures, no live server',
        'Programmatic launch/keyboard focus, not tap interaction',
        'Simulator content-size category only; no VoiceOver or OS Reduce Motion verification']}
assert data['source_commit'] == args.source
try:
    for mode in args.mode or MODES:
        size, flags = MODES[mode]
        run(['xcrun', 'simctl', 'ui', DEVICE, 'content_size', size])
        # Only this project's installed bundle is terminated. A stopped bundle is harmless.
        run(['xcrun', 'simctl', 'terminate', DEVICE, BUNDLE], allowed=(0, 3))
        launch_flags = ['--ui-testing'] + flags + ['-AppleLanguages', '(ko)', '-AppleLocale', 'ko_KR']
        run(['xcrun', 'simctl', 'launch', DEVICE, BUNDLE] + launch_flags)
        time.sleep(14)
        path = args.output / f'{mode}.png'
        run(['xcrun', 'simctl', 'io', DEVICE, 'screenshot', str(path)])
        record = {'file': path.name, 'flags': launch_flags, 'content_size': size,
                  'captured_utc': datetime.datetime.now(datetime.timezone.utc).isoformat(),
                  'sha256': sha(path), 'size_bytes': path.stat().st_size}
        data['captures'] = [c for c in data['captures'] if c['file'] != path.name] + [record]
        index.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
        print(f'Captured {mode}: {record["sha256"]}', flush=True)
finally:
    run(['xcrun', 'simctl', 'ui', DEVICE, 'content_size', 'large'])
