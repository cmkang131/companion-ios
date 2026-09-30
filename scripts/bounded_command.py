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
p.add_argument('command', nargs=argparse.REMAINDER)
a = p.parse_args()
command = a.command[1:] if a.command[:1] == ['--'] else a.command
os.makedirs(os.path.dirname(os.path.abspath(a.log)), exist_ok=True)
started = time.monotonic()
with open(a.log, 'w') as output:
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
    print(f'Exit {result}; elapsed {time.monotonic() - started:.1f}s', flush=True)
sys.exit(result)
