# Recovery evidence — 2026-10-01 KST

## Authoritative checkpoint

Application source: **`72cc293b24052518cfe03ae87f4a9a801d3e33ac`**. Later evidence/documentation commits do not change the application. Use only [`final-72cc293/manifest.json`](final-72cc293/manifest.json) and its named media for the final visual review. Each capture records launch arguments, content-size setting, UTC timestamp and SHA-256; the manifest also records the installed executable hash and build settings.

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
