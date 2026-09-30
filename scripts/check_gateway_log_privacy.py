#!/usr/bin/env python3
"""Check chat/gateway log policy and run production error code with synthetic data.

Runs a small Swift interpreter harness, never an app or package build. Only local
source and temporary files are used; there are no server, keychain, or UI calls.
The lexical guard covers interpolations, direct arguments, simple concatenations,
and preceding declaration aliases. It is not general Swift dataflow analysis or
an OSLog capture; runtime assertions exercise the helper and outbox classifier.
"""

import argparse
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "Vendor/OpenClawKit/Sources/OpenClawKit"
CHAT = ROOT / "Vendor/OpenClawKit/Sources/OpenClawChatUI"
PROTOCOL = ROOT / "Vendor/OpenClawKit/Sources/OpenClawProtocol"


def snapshot_header(repository, source_commit, scope="lexical diagnostic guard + synthetic helper/outbox harness; not OSLog sink or live app"):
    """Attribute this exact tree, including this guard, before any PASS output.

    The reference repository supplies Git objects only. Every tracked blob must
    match the executed snapshot; the caller cannot claim a hash with a flag alone.
    Untracked files are irrelevant to the narrow source scan and never imported.
    """
    repository = Path(repository).resolve()
    full = subprocess.check_output(
        ["git", "-C", str(repository), "rev-parse", "--verify", source_commit + "^{commit}"],
        text=True).strip()
    entries = subprocess.check_output(
        ["git", "-C", str(repository), "ls-tree", "-rz", "--full-tree", full])
    checked = 0
    for entry in entries.split(b"\0"):
        if not entry:
            continue
        metadata, name = entry.split(b"\t", 1)
        mode, kind, expected = metadata.split()
        if kind != b"blob":
            raise SystemExit("Snapshot contains an unsupported non-file entry")
        path = ROOT / os.fsdecode(name)
        body = os.fsencode(os.readlink(path)) if mode == b"120000" else path.read_bytes()
        actual = hashlib.sha1(b"blob " + str(len(body)).encode() + b"\0" + body).hexdigest()
        if actual != expected.decode():
            raise SystemExit(f"Snapshot differs from {full}: {os.fsdecode(name)}")
        checked += 1
    print(f"SOURCE_COMMIT={full}", flush=True)
    print(f"CLEAN_SNAPSHOT=verified_all_{checked}_tracked_blobs_match_git_commit", flush=True)
    print(f"SCOPE={scope}", flush=True)


def closing(text, start, left="(", right=")"):
    depth = 1
    for index in range(start + 1, len(text)):
        if text[index] == left:
            depth += 1
        elif text[index] == right:
            depth -= 1
            if depth == 0:
                return index
    raise AssertionError("Unbalanced source fragment in privacy guard")


def unsafe(expression, preceding, seen=frozenset()):
    expression = expression.strip()
    if re.fullmatch(r"GatewayErrorDiagnostics\.category\(for: \w+\)", expression):
        return False
    if re.fullmatch(r"\w+", expression) and expression not in seen:
        assignments = list(re.finditer(
            rf"\b(?:let|var)\s+{re.escape(expression)}\s*=\s*([^\n]+)", preceding))
        if assignments:
            assignment = assignments[-1]
            return unsafe(assignment[1], preceding[:assignment.start()], seen | {expression})
    # NSError's numeric code is safe; its domain and userInfo are arbitrary strings.
    if re.fullmatch(r"\w+\.code", expression) and expression.startswith("nsError."):
        return False
    return bool(re.search(
        r"localizedDescription|errorDescription|\.message\b|\.userInfo\b|"
        r"\b(?:error|wrapped|failure|reason|nsError)\b|SYNTHETIC_SERVER_ECHO", expression))


def callback_unsafe(expression, preceding, seen=frozenset()):
    """Check common callback forms without treating literal labels as error data."""
    expression = expression.strip()
    if re.fullmatch(r"\w+", expression) and expression not in seen:
        assignments = list(re.finditer(
            rf"\b(?:let|var)\s+{re.escape(expression)}(?:\s*:\s*String)?\s*=\s*([^\n]+)", preceding))
        if assignments:
            assignment = assignments[-1]
            return callback_unsafe(assignment[1], preceding[:assignment.start()], seen | {expression})
    for interpolation in re.finditer(r"\\\(", expression):
        end = closing(expression, interpolation.start() + 1)
        if callback_unsafe(expression[interpolation.end():end], preceding, seen):
            return True
    # Interpolations were checked above. Ignore literal text such as "error="
    # and inspect the code around it, including each operand of a simple +.
    code = re.sub(r'"(?:\\.|[^"\\])*"', " ", expression)
    for operand in code.split("+"):
        operand = operand.strip()
        if not operand:
            continue
        if operand != expression and re.fullmatch(r"\w+", operand):
            if callback_unsafe(operand, preceding, seen):
                return True
        elif unsafe(operand, preceding, seen):
            return True
    return False


def violations(source):
    found = []
    for match in re.finditer(r"\\\(", source):
        end = closing(source, match.start() + 1)
        expression = source[match.end():end]
        public = re.search(r",\s*privacy:\s*\.public\s*$", expression)
        if public and unsafe(expression[:public.start()], source[:match.start()]):
            found.append((source.count("\n", 0, match.start()) + 1, "public error interpolation"))
    for match in re.finditer(r"\blogDiagnostic\s*\(", source):
        end = closing(source, match.end() - 1)
        argument = source[match.end():end]
        if callback_unsafe(argument, source[:match.start()]):
            found.append((source.count("\n", 0, match.start()) + 1, "raw diagnostic callback"))
    return found


def policy_check():
    # Reproduce direct, aliased, concatenated, and callback leaks. Private fields
    # and local categories must pass; a guard that accepts everything fails here.
    bad = [
        r'logger.error("failed \(error.localizedDescription, privacy: .public)")',
        'let failure = error.localizedDescription\n'
        + r'logger.error("failed \(failure, privacy: .public)")',
        'let failure = "SYNTHETIC_SERVER_ECHO_3BC4"\n'
        + r'logger.error("failed \(failure, privacy: .public)")',
        r'logDiagnostic("failed " + "error=\(error.localizedDescription)")',
        'logDiagnostic(error.localizedDescription)',
        'logDiagnostic("failed " + error.localizedDescription)',
        'let message = error.localizedDescription\nlogDiagnostic(message)',
        'let message = error.localizedDescription\nlogDiagnostic("failed " + message)',
        'let message: String = error.localizedDescription\n'
        + 'let diagnostic = message\nlogDiagnostic(diagnostic)',
        'let message = "failed " + error.localizedDescription\nlogDiagnostic(message)',
    ]
    good = [
        r'logger.error("failed \(error.localizedDescription, privacy: .private)")',
        'let failure = GatewayErrorDiagnostics.category(for: error)\n'
        + r'logger.error("failed \(failure, privacy: .public)")',
        r'logDiagnostic("failed error=\(GatewayErrorDiagnostics.category(for: error))")',
        'logDiagnostic("failed " + GatewayErrorDiagnostics.category(for: error))',
        'let message = GatewayErrorDiagnostics.category(for: error)\nlogDiagnostic(message)',
        'let message = GatewayErrorDiagnostics.category(for: error)\nlogDiagnostic("failed " + message)',
        'let diagnostic = "chat.ui run observation error=reported_error"\nlogDiagnostic(diagnostic)',
    ]
    assert all(violations(sample) for sample in bad), "Source guard missed a synthetic leak"
    assert not any(violations(sample) for sample in good), "Source guard rejects safe diagnostics"
    paths = sorted(set(
        list(KIT.glob("Gateway*.swift"))
        + list(CHAT.glob("*.swift"))
        + list((ROOT / "Sources/Companion/Upstream").glob("*.swift"))))
    failures = [f"{path.relative_to(ROOT)}:{line}: {reason}"
                for path in paths for line, reason in violations(path.read_text())]
    if failures:
        raise SystemExit("\n".join(failures))
    print(f"PASS: public error/diagnostic policy in {len(paths)} source files; synthetic leak mutations rejected")


def declaration(source, signature):
    start = source.index(signature)
    opening = source.index("{", start)
    return source[start:closing(source, opening, "{", "}") + 1]


def runtime_check():
    errors = (KIT / "GatewayErrors.swift").read_text()
    # Flatten only the module boundary. These are the real production models,
    # AnyCodable implementation, diagnostics helper, and legacy outbox classifier.
    errors = errors.replace("import OpenClawProtocol\n", "")
    errors = errors.replace("OpenClawProtocol.AnyCodable", "AnyCodable")
    outbox = (CHAT / "ChatViewModel+Outbox.swift").read_text()
    source = "\n".join([
        (PROTOCOL / "AnyCodable.swift").read_text(),
        (KIT / "AnyCodable+Helpers.swift").read_text(),
        (KIT / "String+TrimmedNonEmpty.swift").read_text(),
        declaration((PROTOCOL / "GatewayModels.swift").read_text(), "public struct ErrorShape:"),
        errors,
        "enum OutboxProbe {\nstruct BranchListingUnadvertisedError: Error {}\n"
        + declaration(outbox, "static func branchListingIsUnsupported(") + "\n}",
        (ROOT / "scripts/gateway_log_privacy_runtime.swift").read_text(),
    ])
    with tempfile.TemporaryDirectory(prefix="companion-log-privacy-") as directory:
        script = Path(directory) / "privacy.swift"
        script.write_text(source)
        env = dict(os.environ)
        env["CLANG_MODULE_CACHE_PATH"] = str(Path(directory) / "module-cache")
        subprocess.run(["swift", "-module-cache-path", env["CLANG_MODULE_CACHE_PATH"], str(script)],
                       check=True, env=env, timeout=60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-only", action="store_true", help="Skip the Swift interpreter harness")
    parser.add_argument("--source-commit", help="Expected commit, verified against every tracked blob")
    parser.add_argument("--reference-repository", type=Path, default=ROOT,
                        help="Git object repository when running from an exported archive")
    options = parser.parse_args()
    if options.source_commit:
        snapshot_header(options.reference_repository, options.source_commit)
    else:
        print("SOURCE_COMMIT=unattributed; CLEAN_SNAPSHOT=not_verified", flush=True)
    policy_check()
    if not options.source_only:
        runtime_check()
