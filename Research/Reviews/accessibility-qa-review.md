# Independent accessibility and QA review

Reviewed on 2026-09-30 UTC. Scope: the working-tree source before the main agent's accessibility fixes, existing test sources, and saved validation logs. This review did not run a build, control a Simulator, inspect a live accessibility tree, or claim an interaction pass. Only this report was edited by the reviewer. Line numbers refer to that reviewed snapshot.

## Findings to address

### 1. Connection errors lack a reliable visible and spoken destination

**Priority: P2. Confirmed missing behavior in source; VoiceOver execution remains unverified.**

`Sources/Companion/CompanionApp.swift:112` inserts the error into the first section of the connection Form, while the submit button is below the server fields and token-storage section (`:147`). Submission clears keyboard focus (`:148`) but does not scroll to the error or set accessibility focus/announce it. With a scrolled Form, especially at large content sizes, submitting an invalid URL can leave its explanation above the visible area. A VoiceOver user is not given a deliberate failure announcement.

Move the new error into view and provide an accessibility focus/announcement path. Trigger that path on every failed submission, including when `errorMessage` is the same string as on the previous attempt; watching only string changes misses repeated invalid submissions. Keep the explanation textual, as it currently is, rather than relying on red color. Verify both insecure-URL and missing-token failures, correction, and repeat failure.

The main agent acknowledged this finding and is preparing a scroll/focus correction. That correction is not verified by this review.

### 2. The native iOS message editor has no accessible purpose label

**Priority: P2. Confirmed source omission; exact spoken result remains unverified.**

`Vendor/OpenClawKit/Sources/OpenClawChatUI/ChatComposerTextViewIOS.swift:193` creates a `UITextView`, sets Dynamic Type and `accessibilityIdentifier`, but never sets `accessibilityLabel`. The wrapper at `ChatComposer.swift:888` does not supply one either. Its placeholder is a separate SwiftUI `Text` in an overlay (`:847`), which is not explicitly associated with the native editable element. An identifier is a testing address, not a spoken name; the empty editor therefore lacks a deliberate description of its purpose.

Supply a localized input label and, when disabled, an explanatory hint using the same connection state as the visible placeholder. Avoid having the overlay placeholder read as an unrelated duplicate. Check the empty, focused, populated, and disconnected editor with VoiceOver. The actual text value must remain available, and disabled traits from the existing `accessibilityTraits` implementation must be preserved.

Several reusable controls still use English strings, including `Send message` (`ChatComposer+CleanControls.swift:38`), `Stop response` (`ChatComposer.swift:1244`), and model/permission menus. There is no Korean localization resource in this module. Treat this as a product localization gap to inventory, not proof that upstream accessibility is absent.

### 3. The welcome layout has no overflow recovery at accessibility text sizes

**Priority: P2. Structural risk confirmed; clipping was not reproduced by this reviewer.**

`CompanionApp.swift:74–96` is a non-scrolling `VStack` with a fixed 112-point character, fixed vertical padding, two minimum-height spacers, title, multi-line body, button, and status. Dynamic Type scales the native fonts, and the body explicitly retains its ideal vertical height. There is no scrolling or alternate arrangement when the content exceeds the viewport. The existing large-text test only asserts that the connect button is hittable, so even a future pass would not establish that the explanatory body and status are legible and reachable.

Use a scrollable content container that preserves the centered composition when it fits. Verify AX5 at the smallest supported iPhone viewport, including all copy, the primary action, and bottom status. The main agent has planned this correction; no post-fix render was inspected here.

### 4. Reduce Motion support is meaningful but not complete evidence for all UI motion

**Priority: P3. Confirmed code behavior and narrowly scoped gaps.**

`CompanionCharacterView.swift:22–24` pauses its timeline for Reduce Motion, a presented app sheet, and an inactive scene, and chooses a static pose for Reduce Motion. Hiding this decorative artwork from accessibility (`:45`) is appropriate while state is described elsewhere. It is not a selectable character and has no appearance preference UI or persistence.

The shared composer still explicitly animates slash-panel presentation without checking Reduce Motion (`ChatComposer.swift:1126`), and long user-message expansion does the same (`ChatMessageViews.swift:519`). These small transitions require review in the affected flow; they should not be described as already compliant merely because the character stops. Conversely, programmatic transcript scrolling explicitly uses a nil-animation transaction (`ChatScrollCommand.swift:61`), and streamed text/progress components contain existing Reduce Motion handling. Preserve those upstream protections.

The DEBUG `--ui-testing` argument unconditionally pauses the character. Consequently, these UI tests cannot verify normal idle or state-transition motion. A dedicated short recording without that argument, and a separate Reduce Motion recording, are necessary evidence. Sheet/background pause behavior remains a runtime check. Native glass does not need a custom blur fallback invented solely because there is no explicit `accessibilityReduceTransparency` read; its rendered result under that system setting remains unverified.

## What the tests actually establish

| Evidence | Established | Not established |
| --- | --- | --- |
| `Validation/core-tests-mac.log` | Swift Testing reports 5 tests passing on `arm64e-apple-macos14.0`; endpoint normalization/rejection and a Codable message identity round trip | iOS rendering, gateway/authentication, animation, keyboard, native input, server connection |
| `Tests/CompanionIntegrationTests/ConnectionTests.swift` | Five useful tests are written: invalid URL, empty token, idempotent disconnect, disconnected transport refusal, session-agent routing | Runtime pass was not present in the reviewed logs; no cancellation race, reconnect, history concurrency, or actual server test |
| `Validation/xcode-build-for-testing.log` | App/test build evidence available | Executing assertions or accessibility pass |
| `Validation/xcode-ui-tests.log:34–35` | UI automation setup reached, then execution allowance exceeded before a screen assertion | Large-text/keyboard test pass |
| `Validation/xcode-ui-paused.log:33–43` | Even after pausing the character: automation setup at 14.93 s, idle wait at 75.01 s, animation/event-loop monitoring unavailable at about 81 s, repeated accessibility snapshot requests at 83–85 s, then allowance exceeded | Fix of the automation stall, proof that the app is inaccessible, or completion of preview/history interaction tests |

The `Executed 0 tests` XCTest line in the portable log is followed by Swift Testing's explicit five-test pass; it must not be reported as zero tests, nor expanded into claims about the app. The message-identity test covers `ConversationMessage`, which the current app UI does not use. The four endpoint tests therefore supply most of the current production-path coverage.

`project.yml:95` lists only the three app-owned test bundles. The many vendored OpenClaw test files are not part of this scheme and were not exercised by the portable command. Their presence cannot be counted as validation of our vendor adaptations. For example, the upstream Dynamic Type source-guard test only inspects source strings; even running it would not replace rendered layout QA.

## Test improvements with the highest value

- Keep a short, serial smoke test for one visible toolbar control. If that fails before a reliable accessibility snapshot, stop the suite and record an infrastructure blocker. More identical retries and longer global timeouts do not add product evidence.
- Add deterministic, explicitly labeled DEBUG fixtures for connected-empty, long transcript, connection failure, history failure, and loading/cancelled states. Launch-driven screenshots are useful for geometry, typography and state copy, but are **rendered-only evidence**, not evidence that navigation or retry works.
- Once interactions are available, test invalid URL followed by correction/missing token, repeated identical errors, connection cancel followed by re-entry, interactive swipe dismissal as well as the Done button, history retry/search/no-results, and loss/recovery while typing. Current tests exercise only Done-button dismissal.
- In preview tests, assert that the editor/send controls cannot dispatch and that the server-unconnected label remains visible. Current `testPreviewTranscriptAndHistory` checks text/history presence only.
- Test real composer input, including Korean multi-stage input, line breaks, very long text, keyboard appearance/dismissal, and preserving a draft across sheet entry. Current `testLargeTextAndKeyboard` only opens the settings URL keyboard.
- For AX5, check every essential element is reachable and use a captured viewport to assess clipping; `isHittable` on one button is insufficient. Verify that the requested text category actually reached the app.
- Use one narrow injectable gateway/history seam for cancellation and out-of-order result tests if needed. Do not require real credentials to test these state transitions. A mocked pass must remain separate from live gateway validation.

## Bounded diagnostic recommendation

The existing paused-animation run is enough to reject the simple claim that the character timeline alone caused the stall. Preserve that log/result bundle and one short app-process sample if the main owner can obtain it without prolonged waiting. The duplicate `UIAccessibilityLoaderWebShared` warning in the iOS 27 runtime is an observed clue, not a demonstrated root cause; do not remove system accessibility components or reset permissions to silence it.

After a concrete code or environment change, permit one isolated smoke test with a wall-clock limit owned by the main build/Simulator operator. `-maximum-test-execution-time-allowance` did not prevent lengthy surrounding test infrastructure work, so it is not a complete outer deadline. If it still cannot snapshot the first control, stop only this task's test process and continue compile checks plus honest render-only QA. Do not launch parallel Simulators, erase the existing simulator, retry CUA indefinitely, or ask the user to keep their phone connected for this diagnosis.

Live gateway operation, device signing/installation, VoiceOver speech, Reduce Motion/Transparency execution, and actual keyboard/navigation flows remain independent unverified gates.

## Follow-up: review of the first fixes

Read-only source re-review on 2026-09-30 UTC, after the main agent's first accessibility/state patches. No new build or Simulator operation was performed by this reviewer. This section supersedes the original findings only to the extent stated below.

| Change | Source assessment | Remaining evidence |
| --- | --- | --- |
| Welcome uses `GeometryReader` → `ScrollView` → content with viewport `minHeight` (`CompanionApp.swift:82–108`) | The missing overflow recovery is addressed structurally, while retaining a full-height composition when content fits | Actual AX5 and smaller-screen renders; scrolling to every essential element |
| Connection submission increments `validationAttempt` and scrolls/focuses feedback (`:164–190`) | Repeated identical **connection-submit** failures now have an explicit event independent of string changes | Same-error repeat with VoiceOver, first-error layout timing, focus after interactive dismissal/re-entry |
| iOS editor receives `accessibilityInputLabel` from the current placeholder; set in both `makeUIView` and `updateUIView` | The missing accessible name is addressed, including changed disconnected copy; native text value and disabled-trait code remain intact | Actual empty/populated/disabled VoiceOver reading; avoid duplicate placeholder reading as noted below |
| Stop button adds `!isComposerEnabled` to its disabled condition (`ChatComposer.swift:1247`) | A stale pending run can no longer expose an enabled stop action through this control while the composer is offline | Render and interaction during a lost connection with a pending run |
| DEBUG settings/history/keyboard/invalid-address launch switches (`CompanionApp.swift:73–78,196–205`) | Separate screen entry can produce render evidence without relying on the blocked automation session; invalid URL fixture follows validation and does not need a gateway credential | `--ui-keyboard` only requests focus; inspect that the keyboard actually appears. Pair keyboard/invalid-address flags with `--ui-settings`. Screenshots do not prove tapping, cancellation, retry, or persistence |

### Remaining issues after these fixes

1. **The iOS placeholder overlay remains independently accessible.** `ChatComposer.swift:849–853` still renders `Text(placeholderText)` without excluding this decorative copy from the accessibility tree. The native editor now has that same label. Hide the overlay from accessibility on iOS, preserving the native input's name/value/traits; verify the resulting reading once VoiceOver is available. Duplicate spoken output is a risk inferred from this composition, not a recorded VoiceOver result.
2. **Repeated saved-token errors do not use the new feedback event.** `CompanionApp.swift:151,153` calls token load/delete without incrementing `validationAttempt`. If “no saved token” is returned twice, `onChange(errorMessage)` alone will not announce/scroll the second identical result. Additionally, `ConnectionStore.swift:176,188` silently returns for an invalid address. Use the same explicit feedback event for these synchronous actions, and make invalid-address preconditions visible or disable the actions with an explanation. This is a local failure path that does not require any real credential to exercise.
3. **Error-focus timing is still unverified.** Both `onChange` handlers can run for a first validation error; one focuses immediately and the other toggles after `Task.yield()`. Yielding is not recorded proof that the newly inserted error row is laid out or that VoiceOver moved. This is a runtime QA requirement, not a reason to add arbitrary sleep. If speech is duplicated or focus is lost in real use, consolidate the two paths around one cancellable feedback request.
4. The narrow Reduce Motion gaps, Korean control localization gaps, fixture/test coverage gaps, and environment-level XCTest blocker recorded above remain. The newly added structured-auth-error integration test is source coverage only until a run reports its results.

The first three fixes therefore improve the code materially, but do not convert the existing build/screenshot evidence into a VoiceOver or interaction pass.
