# Companion — native OpenClaw client

Private, single-user SwiftUI iOS 26+ client built around the official MIT OpenClawKit and OpenClawChatUI sources. The current build runs in an iOS 27 Simulator. **A live OpenClaw gateway has not been connected or validated.** Companion is independent of Muse and OpenAI dot.

## Implemented

- Light-only native chat, history and connection sheets; restrained system Liquid Glass and native typography.
- Code-drawn blue four-lobed character with dark oval eyes, a small blue bump and glass name pill, based on the latest user reference. The private reference image is excluded from the repository.
- Existing upstream mascot animator reused for idle and response states. Response acknowledgement requires a nonempty terminal event with explicit current session and owned run correlation; it does not claim external task success.
- Per-session drafts and ready attachment bytes survive same-endpoint reconnect failure and cancellation in memory. Interrupted imports are identified for reselection. Explicit disconnect has a separate destructive confirmation; process termination does not preserve drafts.
- Submitted messages retain their original text, attachments and reply until acceptance is known. Uncertain delivery requires history review and explicit restoration, never automatic resending. New composer content is not overwritten.
- A compact native composer reuses upstream input/attachment/send controls. Model settings move to the connection sheet; message actions and localized timestamps remain in the long-press menu.
- Connected input attachments use upstream encoding and server-advertised limits. Unsupported output downloads and disconnected widget previews show explicit availability instead of nonfunctional actions.
- Revision/generation guards for token deletion, delayed connection callbacks and out-of-order history requests.
- Raw server error text removed from public diagnostics or made private, with narrow synthetic regression checks.
- Current-conversation activity exposes real run metadata, upstream progress cards and questions. Stop admission retains exact run/session and physical-route ownership; server acceptance and confirmed termination are separate states. New runs remain stoppable while earlier requests await termination.
- Incoming questions are separated by current-conversation versus unspecified scope. Skip requires a verified cancelled response; late RPCs cannot overwrite an authoritative terminal event or a replacement route. Questions are not execution/purchase approvals.
- Read-only, explicitly disconnected preview fixtures. Sending, attachments, question decisions, activity controls and model sign-in remain unavailable in preview.
- Dynamic Type, a visible connection action at AX5, semantic labels, and reduced-motion/transparency drawing paths.

Read [AGENTS.md](AGENTS.md) before changes. Reuse is an architectural preference; no measured custom-code percentage is claimed.

## Evidence and limits

See [Validation/RECOVERY.md](Validation/RECOVERY.md) for exact source hashes, actual screenshots/video, commands and limitations.

- Native iOS Simulator build, installation, launch and real screenshot capture succeeded on a dedicated recovery simulator.
- macOS SwiftPM tests exercised the production connection store/model with controlled fake boundaries: 105 integration test functions in 11 suites and 5 portable core tests passed at source `99ba308`. Parameterized cases are additional coverage, not added to this function count.
- Exact-commit privacy guard and synthetic production helper checks passed. These are not OSLog sink or live-server security tests.
- Latest exact-source renders cover compact chat, activity/progress, stop accepted/confirmed/failed, scoped/unscoped questions and AX5 top/footer positions. Earlier attributed evidence covers disconnected welcome/history, local validation and keyboard. Programmatic fixture launch/focus/scroll is separate from interaction testing.
- A rebuilt test runner at `58d9ef8` also stalled during automation-session setup and reached the 100-second outer timeout. Repeated interactive sheet/navigation QA is not passed; screenshots alone do not prove it.

Still unverified: live pairing/authentication, real sending/streaming/reconnect, server approvals/artifacts/browser control, VoiceOver interaction, real OS Reduce Motion/Transparency settings, phone installation/signing and release distribution. Activity is limited to current-conversation response control, not a global durable-task dashboard. Execution/purchase approvals, browser takeover and voice are not implemented. See [the implementation matrix](Research/IMPLEMENTATION-MATRIX.md) for protocol support, integration gaps and blockers.

## Build on macOS

Use Xcode 27 with the iOS 27 Simulator runtime. Run only one build at a time:

```sh
xcodebuild -project Companion.xcodeproj -scheme Companion \
  -configuration Debug -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build-xcode -jobs 2 \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES ENABLE_DEBUG_DYLIB=NO \
  CODE_SIGNING_ALLOWED=NO build
```

This produces `.build-xcode/Build/Products/Debug-iphonesimulator/Companion.app`, not a phone-installable IPA. The recovery machine's earlier `build-for-testing` product stalled in the dynamic loader; the normal build above rendered successfully. The exact cause was not isolated. Preserve the normal build in a separate directory before any subsequent test build; screenshots in `Validation/controls-99ba308` explicitly record its installed executable hash.

```sh
COMPANION_CONNECTION_TESTS=1 swift test --scratch-path .build-connection --jobs 2 --disable-sandbox
COMPANION_CORE_ONLY=1 swift test --scratch-path .build-core --jobs 2
python3 scripts/check_gateway_log_privacy.py
python3 scripts/check_app_contract.py
```

The macOS test target omits app entry views and replaces gateway/credential boundaries. It does not stand in for iOS runtime integration or a real Keychain/server test. `scripts/bounded_command.py` adds an outer timeout and terminates only the command group it owns.

## Debug rendering fixtures

Launch arguments: `--ui-testing` (paused mascot/empty endpoint), `--ui-preview`, `--ui-history`, `--ui-settings`, `--ui-keyboard`, `--ui-invalid-address`, `--ui-model-settings` (also requires preview/settings), `--ui-motion-gallery`, `--ui-send-recovery` and `--ui-artifact-preview` (the latter two also require `--ui-preview`). Preview content is synthetic and visually labelled. `--ui-accessibility-static` exercises static/opaque drawing branches with an on-screen label; it does not alter system accessibility preferences. Current activity fixtures additionally use `--ui-activity`, `--ui-stop`, `--ui-stop-confirmed`, `--ui-stop-failed`, `--ui-questions` or `--ui-unscoped-questions`; these require preview/activity. `--ui-questions-end` selects the lower question viewport for AX5 capture. Stop fixtures exercise the production model with a controlled synthetic route, never a live service. Fixtures are Debug-only.

## Sources and licenses

[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) records the pinned vendored foundation, local adaptations and license scope. Complete MIT and resolved dependency notices are retained in the app. Generated Mermaid resources retain their upstream notice. Default cloud Talk support is disabled.

[Research/MUSE-DOT-EVIDENCE.md](Research/MUSE-DOT-EVIDENCE.md) and [REFERENCES.md](REFERENCES.md) distinguish public illustrations, official claims, original implementation decisions and untested behavior. Private screenshots, SDKs, build caches, credentials and other projects are excluded from source delivery.
