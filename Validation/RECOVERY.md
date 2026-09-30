# Recovery evidence — 2026-10-01 KST

## Latest question entry-point fix — bf8ece6

Authoritative source: **`bf8ece67afce77f05bad2af4bec0acb05e9da288`**. Implementation is in `2d12951`; subsequent source commits adjust tests and notices only. [The manifest](question-gate-bf8ece6/manifest.json) ties seven raw logs to their exact source commits. Current successful logs verify all 566 tracked blobs against source bf8ece6. The prior rendered checkpoint is preserved separately below.

The transcript previously rendered raw question cards with implicit all-scope and no host connection gate. Closing the activity sheet could expose unspecified questions without their scope explanation, and preview could still reach question actions. Transcript and activity now use the same scoped presentation and actual action callbacks. The production model admits submit/skip only for a current visible card, healthy transport and the connection owner's live policy. It checks host/health access again after awaiting route acquisition. The host hook checks preview, phase and connection generation; a SwiftUI disabled modifier is supplementary. Already admitted same-connection requests retain original question ownership, and terminal/expiry/route priorities are preserved.

| Validation | Result and exact limit |
|---|---|
| App production-model integration at bf8ece6 | PASS: 114 test functions in 11 suites + core 5, 76.6 s including rebuild. Both presentation factories' actual callbacks, direct model bypass attempts, real ConnectionStore preview/disconnect hook, synthetic healthy preview, unhealthy transport, held lease/policy loss, foreign scope, terminal/expiry combinations and prior regressions. Controlled boundaries, not UI events or live RPCs. |
| Normal iOS build at bf8ece6 | PASS, 5.6 s: app entry UI included; arm64 Simulator, jobs 2, Debug dylib disabled, signing disabled. No installation or launch. |
| Privacy at bf8ece6 | PASS: exact archive, 182 Swift sources, 8 helper cases / 7 categories. Narrow source/harness scope, not an OSLog sink or general security proof. |
| Shared question wiring / built bundle | PASS: mutation-tested source guards for both call sites, common callbacks and model gate; bundle platform/resources metadata. Not tap interaction. |
| Selected upstream question tests at 4a3838a | BLOCKED during wider test-target compilation, exit 1 after 79.1 s. Missing excluded RealtimeTalk/PCM types prevented selected tests from running. Three fixtures' new healthy-state preconditions are source-corrected; no execution pass claimed. No retry or Talk enablement. |
| Prior artifact 615294e | PASS from exact Git blobs: 27 changed paths contain docs/evidence only relative to 99ba308, and all 22 manifest references (10 original PNGs / 9 logs plus records/contact) match their committed hashes. This preserves prior evidence, not new-source runtime proof. |

A separate read-only source review found no production blocker in 2d12951 and identified the three upstream fixture preconditions; those were corrected. Its suggested policy-loss plus terminal/expiry intersection is now an executed integration regression. Production files and wiring scripts are unchanged between 2d12951 and bf8ece6.

The normal built app is preserved at `.build-render-products/bf8ece6/Companion.app`; **built-only** executable SHA-256 is `f2ef67599f67c0229f02089704ce47aaa960fdda00d94aa99c66596d9fca87bf`. It was not installed. Existing 99ba308 screenshots cannot establish the changed common question presentation, touch events, scrolling, VoiceOver or OS accessibility behavior. No account, server setting, credentials, physical-device work or live model call occurred. The earlier interaction runner remains blocked as documented below. **The P2 has source/model/build evidence; new-render and real-interaction validation remain open.**

## Earlier rendered activity/question checkpoint — 99ba308

Authoritative application/test/script source: **`99ba308b5f02911072d76dc5ad76d3b08834b3dd`** on `recovery/task-controls`. The earlier reviewed stable branch `recovery/safe-follow-up` remains at `e8afca70b87ae945c870a31a41a903c6a078b7af`. The follow-up adds current-conversation control to the stable composer/data-recovery work; it does not establish full Muse/dot parity.

See [`controls-99ba308/manifest.json`](controls-99ba308/manifest.json) for ten original Simulator PNGs, nine raw validation logs, the runtime record, contact sheet, source/hash attribution and limits. Every new raw log identifies the full source commit and verifies all 543 tracked blobs against it. Privacy ran from a fresh exact `git archive`. Later evidence/documentation commits do not alter the application/test/script source.

- Avatar/status entry opens native current-conversation activity. Actual run metadata, upstream progress and incoming question components are reused. It is not a global task dashboard.
- Stop distinguishes request admission, server acceptance, confirmed termination, failed dispatch and unconfirmed outcome. Per-run session/physical-route leases protect against navigation, replacement connections, late ACKs and unrelated terminal events. A new B remains stoppable while A awaits termination, without sending another stop for A. Draft text/attachments/reply are retained.
- Question cancellation requires the pinned `cancelled` result. Empty, answered, rejected and invalid payloads do not create a false skipped state. Server terminal events outrank late mutation responses; expiry and route/owner retirement have explicit recovery behavior.
- Current-conversation questions and unspecified-scope questions are separate. Nil, empty and whitespace session keys all remain unspecified, including after navigation. Questions are not execution/purchase approvals; access scopes remain unchanged.

| Check at exact source 99ba308 | Observed result | Scope |
|---|---|---|
| macOS production-model regression | PASS, 105 test functions in 11 suites + 5 core, 3.7 s | Controlled fake gateway/credential boundaries; parameterized cases are not counted as extra functions. No iOS test or live execution claim. |
| Normal native Simulator build | PASS, 7.3 s | Xcode 27, Debug normal `build`, arm64, jobs 2, signing disabled, `ENABLE_DEBUG_DYLIB=NO`. |
| Dedicated Simulator install | PASS, 1.1 s | Only task5's own simulator/bundle. Not phone installation. |
| Privacy exact-archive check | PASS, 182 Swift sources; 8 helper cases / 7 categories | Lexical diagnostic guard plus production helper/legacy outbox synthetic harness. Not general dataflow, control-flow proof or an OSLog sink capture. |
| UI source wiring / bundle validation | PASS | Cancel/activity call-site and mutation guards; platform, resources and path checks. Not tap interaction. |
| Native content captures | PASS within fixture scope, 10 PNGs | Nine modes in 140.6 s; separate AX5 footer in 16.5 s. All use `--ui-testing`; no motion evidence. |
| Runtime product attribution | PASS | Running own app process observed; installed/built main executable and CompanionCore hashes independently matched. |
| Real UI interaction / OS accessibility / live server | NOT VERIFIED | Earlier XCTest setup timeout remains unresolved. No new accounts, server, credentials or live model calls. |

Normal app preserved at `.build-render-products/99ba308/Companion.app`; installed main executable SHA-256 is `403a6bfd55743da38f9a946b17fd56311341474f6d6a58224d400378612bf595`. `runtime.json` and its raw log record the actual container, process, observation time and companion framework hash. The evidence files use only synthetic chat/questions.

The earlier `9051adb` **build-for-testing** app produced blank screens. A bounded sample of its own process showed main-thread dynamic-loader work before application entry. Those blank PNGs are excluded from final render evidence. A normal build with Debug dylib disabled, preserved separately and reinstalled, produced actual content. This is an observed recovery, not a proven root-cause diagnosis. Test products must not overwrite the preserved render source.

Direct pixel review confirms the compact composer; distinct stop accepted/confirmed/failure copy; current versus unspecified question scope; persistent disconnected-preview label; AX5 activity controls; and vertically stacked AX5 question actions visible at the lower viewport. The question upper and lower screenshots use programmatic scroll positions. They do not establish real scrolling, touch targets, VoiceOver order or interactive dismissal. The footer buttons and all preview server controls remain disabled; stop-state fixtures exercise the production model via a synthetic lease.

Library: **Companion-99ba308-activity-question-renders.png**, `libfile_c1b249b350708191b24c4a2321c6e369`. Nine uncropped, scaled screenshots form the sheet; the tenth original is the AX5 question upper viewport. Earlier motion footage is separate and does not prove live state transitions, frame rate or OS Reduce Motion behavior.

Remaining product gaps and backend/permission/validation blockers are explicit in [`Research/IMPLEMENTATION-MATRIX.md`](../Research/IMPLEMENTATION-MATRIX.md). No real approval, browser takeover, remote artifact download, voice, memory or durable-task integration is claimed. Data recovery is still memory-only. **This checkpoint is reviewable progress, not a complete-app or release certification.**

## Earlier preserved composer/data-recovery checkpoint — 58d9ef8

Application/test source: **`58d9ef8311663acf8ca427fa55d8f2b18154af62`**. This supersedes 72cc293 and intermediate 7539fec for current UI and recovery behavior. Later documentation/evidence commits do not change this source. See [`followup-58d9ef8/manifest.json`](followup-58d9ef8/manifest.json): seven actual PNGs, raw logs, SHA-256 values, launch flags, UTC capture times, build settings and directly compared installed/built executable hashes are joined there.

- Reused one-row native composer; model/effort/branch and model-access controls moved into settings. Repetitive timestamps/ellipsis removed; actual message context actions retained, with Korean timestamps/actions. No dummy microphone.
- Same-endpoint in-memory snapshots preserve text, ready attachment bytes and reply; interrupted imports are identified, and delayed imports cannot mutate the replacement draft.
- Submitted-send ledger retains unknown/error/timeout ACK outcomes. Only pinned gateway acceptance statuses `started`, `ok`, `in_flight`, `accepted` retire originals. History review requires a settled entry whose revision still matches. Explicit restoration is checked again and preserves newer text/attachments/replies; unchanged restored drafts reuse their idempotency key.
- Retained sends can return directly to their originating session even if that new session is absent from the server listing. Endpoint/connection/attachment ownership guards apply. There is no automatic resend.
- Cancelled/retired model sign-in and refresh completions cannot change new errors/input/catalog state. Shared login presentation keeps settings dismissal/owner fencing.
- Connected input attachments use upstream encoding and advertised size limits. The gateway's missing output-media loader is represented as unavailable; disconnected inline widgets wait without pretending to have loaded.

| Check at exact source 58d9ef8 | Result | Evidence and limits |
|---|---|---|
| macOS production regression | PASS | `logs/tests-58d9ef8.log`: 66 test functions in 8 suites, plus 5 core tests. Includes parameterized cases. Fake transport/credential boundaries; not live-server or iOS execution. |
| Native normal app build | PASS | `logs/build-58d9ef8.log`: exit 0, 8.8 s; Xcode 27, arm64 Simulator, jobs 2, signing disabled, Debug dylib disabled. |
| Native test product build | PASS | `logs/build-testing-58d9ef8.log`: exit 0, 24.4 s. Compiled app and tests; execution is separate. |
| Privacy archive scan/harness | PASS | `logs/privacy-58d9ef8.log`: 180 source files plus synthetic leak mutations; 8 production-helper cases across 7 categories. Not an OSLog sink, complete dataflow proof or live app security test. |
| Cancel UI source guard | PASS | `logs/cancel-wiring-58d9ef8.log`; source/mutation check only. |
| Actual native render | PASS with stated scope | `logs/capture-58d9ef8.log`, seven PNGs, 113.3 s. Dedicated simulator only, programmatic fixture launch/focus/scroll, no live server. AX5 welcome now has two-line introduction and visible safe-area CTA. |
| XCUITest interaction | BLOCKED | `logs/ui-interaction-58d9ef8.log`: automation setup stalled, test exceeded its allowance, runner restarted with 0 tests, outer timeout exit 124 at 100 s. This is **not a pass**. No further unchanged retries. |

All log paths above are relative to `followup-58d9ef8/`; hashes are in the manifest. Outer process exit codes and elapsed times were returned by the bounded command tool; child stdout/stderr is preserved verbatim. Installed executable SHA was read from the dedicated simulator container and matched the built executable before captures.

Library deliverables: `Companion-58d9ef8-native-renders.png` (`libfile_773e5eb78d588191b1c08cc82873bbeb`) and `Companion-composer-before-after.png` (`libfile_1201b90dca908191bac9026fbcc2713f`). The latter intentionally compares 72cc293 with intermediate 7539fec; its after panel is not labelled as 58d9ef8. Intermediate source 7539fec had 56 integration + 5 core tests and 180-source privacy checks; its images/logs remain in `followup-7539fec/` for that comparison.

Remaining gates: live pairing/auth/sending/streaming/reconnect; server interpretation of incoming attachments; remote media downloads; real tap/long-press/repeated-sheet behavior; VoiceOver and real OS Reduce Motion/Transparency settings; physical phone/signing/distribution. The model-settings screenshot exposes the section entry after programmatic scroll, not proof of all lower-row hit targets. Recovery is memory-only and does not survive process termination; the UI now says so. Prior motion footage establishes a labelled gallery's blink/microposes, not live state transitions or frame-time performance. Character body shading is still flatter than the reference. **This checkpoint is not a claim that the complete app or live integration is finished.**

## Earlier preserved checkpoint — 72cc293

Earlier application source: **`72cc293b24052518cfe03ae87f4a9a801d3e33ac`**. Later evidence/documentation commits do not change the application. For this earlier checkpoint, use [`final-72cc293/manifest.json`](final-72cc293/manifest.json) and its named media; the newer follow-up below supersedes its composer/recovery presentation. Each capture records launch arguments, content-size setting, UTC timestamp and SHA-256; the manifest also records the installed executable hash and build settings.

The older local `recovery-*.png` and `final-*-777d4e5.png` files are intermediate diagnostics, not final evidence. In particular, `recovery-preview-settled.png` predates the disconnected sign-in/footer fix and `recovery-large-type-final.png` predates the fixed accessibility connection action. They are not included in this delivery.

The recovery repository is an isolated copy. The original workspace was only read. No CUA, account interaction, physical phone, signing setup, device trust change, network security change, or other project's process was used. The only simulator controlled was **Companion Recovery Task5**, UUID `022EC407-377F-4563-A350-CD12D1BA7795`, iPhone 17e / iOS 27.0. Commands were bounded; only owned processes were terminated.

## Validation matrix

| Check | Exact source | Observed result | Scope and limit |
|---|---|---|---|
| Native Simulator build | `72cc293` | PASS; `final-source-build.log`, exit 0, 12.9 s | Xcode 27, normal Debug `build`, arm64, jobs 2, signing disabled, `ENABLE_DEBUG_DYLIB=NO` |
| Native install/launch/screenshots | `72cc293` | PASS; manifest media | Actual Simulator pixels; fixtures and disconnected UI, not live service validation |
| Production connection/model regression | `72cc293` | PASS; `tests-72cc293.log`, 25 tests in 2 suites | macOS SwiftPM, real store/model with controlled fake gateway/credential boundaries; app entry views excluded |
| Portable core regression | `72cc293` | PASS; same log, 5 tests | Endpoint validation/normalization and identity, not UI or server behavior |
| Public diagnostic source guard | `72cc293` git archive | PASS; `privacy-72cc293.log`, 175 Swift files | Lexical guard with synthetic interpolation/direct/concat/typed/chained-alias mutations; not general Swift dataflow |
| Production privacy helper/classifier | `72cc293` git archive | PASS; same log, 8 cases across 7 categories | Real error/helper code and extracted legacy outbox classifier; not an OSLog sink capture or app integration test |
| Cancel button source wiring | `72cc293` git archive | PASS; `check_app_contract.py` | Production button invokes `cancelConnection`; mutation to `disconnect` rejected. Static source check, not a tap |
| XCUITest preview/history | `777d4e5` app; existing runner | BLOCKED; `ui-preview-777d4e5.log` | Automation session setup exceeded 60 s; outer command terminated at 100 s / exit 124. Restart's “0 tests passed” is not a pass |
| Earlier iOS unit-test runner | `c457709` app build | BLOCKED; `recovery-unit-tests.log` | 180 s outer timeout before completed tests; not counted as a pass |

Integration regressions cover all-session draft restoration across failed/cancelled retries; explicit-disconnect erasure policy; endpoint isolation; emptied drafts; delayed connection callbacks; token revocation including re-opt-in and delete failure; history ordering and invalidation; preview history without send permission; and completion correlation (missing IDs, late/foreign/duplicate/error/abort/empty/detached events). The number 25 counts test declarations reported by Swift Testing, not inflated parameter-case totals.

The privacy check deliberately retains raw typed errors for auth/wire/outbox classification while keeping remote text out of public diagnostics. Private interpolation and fixed categories were reviewed at source level. Category substitution and access-control changes are not proven safe for every production control flow by the narrow harness. No live OSLog collection was performed. Early `ba78250` did not contain four shared-file fixes; privacy success is **not** attributed to that commit. The authoritative replay uses complete `72cc293` source extracted with `git archive`.

## Actual visual review

- Welcome: blue four-lobed body, dark oval eyes, small blue bump, native glass name pill, light background. Two right contour tangents were smoothed after review. Shading remains an original code approximation of the reference, not exact asset reproduction.
- Preview: gray assistant and pale-blue user bubbles; disabled composer; visible “미리보기 · 서버 미연결”. Unsupported sign-in/error footer is absent.
- History: real list populated by read-only PreviewTransport; the sheet itself also labels the preview as disconnected.
- Address error: local `http://example.com` validation shows the HTTPS/WSS explanation. No external connection or credentials are involved.
- Keyboard: native endpoint field receives focus through a Debug launch fixture and the system keyboard renders. This does not prove tap, submit, typing or interactive dismissal behavior.
- AX5: the simulator content-size setting was changed to accessibility-extra-extra-extra-large and then reset to large. The connection action remains visible at the bottom; long explanation content is scrollable. Actual scroll interaction and VoiceOver reading order remain untested.
- Static gallery: all three drawing states are explicitly labelled visual fixtures, with an opaque name pill and bottom diagnostic label. This exercises the app's static/opaque branches; it does not change or validate real OS Reduce Motion/Transparency preferences.
- Motion video: an actual simctl recording of the labelled gallery. It shows idle blinking and small pose changes of the reused animator, not live backend state transitions or verified task completion. The encoded video rate is metadata, not a measured app performance guarantee.

## Reproduce

```sh
python3 scripts/bounded_command.py --timeout 180 --log Validation/final-source-build.log -- \
  xcodebuild -project Companion.xcodeproj -scheme Companion -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build-xcode -clonedSourcePackagesDirPath .build-xcode/SourcePackages \
  -disableAutomaticPackageResolution -jobs 2 ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  ENABLE_DEBUG_DYLIB=NO CODE_SIGNING_ALLOWED=NO build

COMPANION_CONNECTION_TESTS=1 python3 scripts/bounded_command.py --timeout 180 \
  --log Validation/tests-72cc293.log -- \
  swift test --scratch-path .build-connection --jobs 2 --disable-sandbox
```

Use a dedicated simulator that you own. Install `.build-xcode/Build/Products/Debug-iphonesimulator/Companion.app`, then `simctl launch --terminate-running-process <UUID> com.cmkang131.companion <manifest flags>`. Wait for visible rendering before taking `simctl io <UUID> screenshot <path>`. Early screenshots taken 3 seconds after launch were sometimes blank/incomplete; final captures waited 14–15 seconds. `render_evidence_sheet.swift` only arranges actual screenshots without cropping or inventing UI.

An earlier `build-for-testing` app stalled before main in dyld dependency loading (3-second sample: `companion-launch-sample.txt`). A normal `build` with debug dylib disabled rendered successfully. Because both action and setting changed, the exact cause was not isolated. No runtime files were deleted or altered to work around the accessibility duplicate-class warning.

## Remaining blockers

No live OpenClaw host, credentials or authorized real server were available. Pairing/authentication, real model dispatch and event replay, end-to-end reconnect, real server history, approvals, artifacts/downloads, browser takeover, microphone/live voice, notifications and external outcomes remain unvalidated. No fake successful integrations were added. UI automation setup remains blocked; repeated sheet dismissal, VoiceOver, actual OS accessibility preferences and device behavior need a later authorized test. Phone installation, signing and distribution were explicitly outside the recovery scope.

The public research is in `Research/MUSE-DOT-EVIDENCE.md` and `REFERENCES.md`. It separates official claims and inspected promotional UI from original recommendations and untested behavior. The user's private reference pixels are outside the repository and are not uploaded with evidence.
