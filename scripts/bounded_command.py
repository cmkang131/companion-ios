#!/usr/bin/env python3
"""Run only a newly spawned command under an outer timeout, keeping its log."""
import argparse
import os
import signal
import subprocess
import sys
import time

p = argparse.ArgumentParser()
p.add_argument('--timeout', type=float, required=True)
p.add_argument('--log', required=True)
p.add_argument('--source-commit', help='Verify and log the exact tracked snapshot before execution')
p.add_argument('command', nargs=argparse.REMAINDER)
a = p.parse_args()
command = a.command[1:] if a.command[:1] == ['--'] else a.command
os.makedirs(os.path.dirname(os.path.abspath(a.log)), exist_ok=True)
started = time.monotonic()
with open(a.log, 'w') as output:
    output.write('RUNNER_STARTED_UTC=' + time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()) + '\n')
    if a.source_commit:
        from contextlib import redirect_stdout
        from pathlib import Path
        from check_gateway_log_privacy import snapshot_header
        root = Path(__file__).resolve().parents[1]
        untracked = subprocess.check_output(['git', '-C', str(root), 'ls-files', '--others',
            '--exclude-standard', '--', 'Sources', 'Tests', 'Vendor', 'scripts'], text=True).strip()
        if untracked:
            raise SystemExit('Untracked source inputs exist; commit before attributed validation')
        with redirect_stdout(output):
            snapshot_header(root, a.source_commit, scope='source attribution for the following validation command')
        output.write('VALIDATION_COMMAND_SCOPE=see command output below; snapshot header is source attribution only\n')
    output.flush()
    process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
    print(f'Started owned process {process.pid}; deadline {a.timeout:g}s; log {a.log}', flush=True)
    try:
        result = process.wait(timeout=a.timeout)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGKILL)
            process.wait()
        result = 124
    elapsed = time.monotonic() - started
    output.write(f'\nRUNNER_EXIT={result}; ELAPSED_SECONDS={elapsed:.1f}\n')
    output.flush()
    print(f'Exit {result}; elapsed {elapsed:.1f}s', flush=True)
sys.exit(result)
