# UI and motion review — 2026-09-30

Read-only review of the current integration. No app code, build, Simulator, CUA, or asset modification was performed by this reviewer. Findings describe the version read during this review; the coordinating agent may subsequently fix them.

## Evidence and limits

- Read `AGENTS.md`, `CompanionApp.swift`, `ConnectionStore.swift`, `PreviewTransport.swift`, `CompanionCharacterView.swift`, the reused mascot animator, and the upstream chat/composer/message/typography implementations.
- Directly inspected `Validation/current.png` and `Validation/character-motion-frames.png`.
- Directly inspected the materialized personal `dot-reference.png`, the official Muse video frame at 24 seconds, and the official article's status/activity image (`muse-official-status.png`). Reference files remain outside this repository; none is a redistributable app asset.
- The current app image proves the rendered disconnected welcome screen. It does not prove the connected transcript, keyboard, failure/retry, or accessibility layouts.
- The motion contact sheet visibly contains single-eye and two-eye closures. It does not demonstrate tool work, completion, or real server events.
- The personal dot reference has a blue, textured, four-volume silhouette and two dark oval eyes. The current dark pebble has a different silhouette, surface, eye polarity, and visual weight. The user has rejected the interim character; small radius/color adjustments cannot establish reference fidelity. The final character choice remains unresolved.
- The official Muse status image shows avatar/name/current activity, segmented activity controls, and flat activity rows. It is an activity screen, not a complete chat screen. No measurements of the chat composer or bottom tabs can be justified from this image.

## Small fixes and decisions, in order

### 1. Make connection state authoritative over character activity

`CompanionHome` chooses its toolbar mood solely from `model.pendingRunCount`. `ConnectionStore.didDisconnect` retains the model while setting phase to failed. A stale pending run can therefore keep a thinking pose after the connection fails. This is a code path, not a reproduced network result.

Use a small presentation resolver with connection/preview state ahead of run activity. Keep a neutral static expression when activity is unknown. Show a concise textual status and accessibility value alongside identity when it carries useful information. Animation must remain optional decoration; a 28-point character's gaze shift cannot be the only work signal.

Do not interpret a decreasing/zero pending count as successful completion. Cancelled, failed, disconnected, and completed runs need authoritative terminal information. Do not add celebratory motion until that mapping is verified.

Acceptance: pending run → connection lost does not retain a working claim; cancel/failure does not produce success; Reduce Motion and VoiceOver retain the same status meaning.

### 2. Check the existing assistant-bubble switch before restyling

The app selects `.clean` composer chrome but does not enable `openClawAssistantBubblesInCleanChrome`. Its upstream default is false (`ChatMessageViews.swift`, `OpenClawAssistantBubblesInCleanChromeKey`). User messages receive the pale-blue accent, while assistant messages normally use the unfilled clean presentation.

The observed Muse video has subdued gray assistant bubbles. The public environment flag can opt into the existing implementation for both streaming and completed messages. This is a small, licensed reuse opportunity, subject to a real preview screenshot. Avoid writing another message renderer.

Acceptance: inspect short/long Korean text, a streaming fixture and its completed counterpart, Markdown lists, and narrow/wide messages at standard and accessibility sizes. Confirm that the flag does not add unwanted wrappers to tool/run content.

### 3. Keep one typography system across onboarding and conversation

The app's welcome/settings use system text styles. `OpenClawChatTypography` uses Inter for iOS body text, Red Hat Display for headings, and JetBrains Mono for code. Its relative text styles support scaling, but the family choice differs from the app shell and relies on fallback for unsupported scripts.

For this native-first app, prefer an app-scoped system-font option or a narrowly documented typography adaptation over per-view overrides. Preserve monospace for code. Decide after inspecting a mixed Korean/Latin transcript; do not substitute a font solely to imitate a promotional frame.

Acceptance: compare identical Korean/Latin strings in settings, transcript, input, and history; check baseline/weight continuity at default and maximum supported Dynamic Type.

### 4. Verify the composer as a composer, not only as settings input

`CleanChatComposerSurface` already uses native `.glassEffect` on iOS 26+, with a 104-point minimum resting height and a separate 44-point control row. The attachment control also owns other settings; disabling attachments does not mean that all its contents disappear. Inspect before removing it or collapsing the input to a guessed Muse pill.

The existing large-text/keyboard UI test exercises the server-address field. `--ui-preview` disables the chat composer because `canSend` is false. Those paths cannot establish chat draft growth, keyboard avoidance, return-key behavior, or disabled-send contrast.

Use an explicitly marked, local-only draft fixture to exercise editing without dispatch if needed. Keep the server-disconnected disclosure and make all send attempts unavailable. Do not relax production dispatch guards for screenshot convenience.

Acceptance: one line → long multiline draft → interactive keyboard dismissal → reopen; long pasted text; readable disabled state; no clipped action at maximum Dynamic Type. Keep only supported, useful controls visible.

### 5. Protect the welcome flow at large text sizes

The welcome uses a non-scrolling `VStack`, a fixed 112-point character, fixed spacers and padding, and vertically fixed-size explanatory text. It can run out of vertical space as Dynamic Type grows. This is a layout risk; no accessibility-size render was reviewed here.

A scroll-capable native container, with the normal-size composition maintained, is a small resilience improvement. Do not introduce a new dashboard or more onboarding copy. The actual connection call to action and status must remain reachable.

## Integration boundaries that affect design

- **Work during another run is not implemented merely by enabling the input.** Upstream `OpenClawChatViewModel.canSend` rejects `hasBlockingRunActivity`, which combines pending runs, advertised live runs, unsnapshotted active runs, and branch switching. Muse's parallel-message behavior requires an explicit transport/session contract. Do not delete this guard as a styling change.
- **The header's run test is narrower than the transcript's.** `pendingRunCount` alone misses other upstream active-run states. Reuse a narrowly exposed read-only activity projection, or state only what is actually known. Avoid a second independently inferred state machine in the view.
- **Inspect stop availability on disconnection.** `ChatComposer.sendButton` renders stop from pending count and disables it only for `isAborting`; `isComposerEnabled` is not that branch's guard. Check whether a retained run can present an actionable stop after transport loss. Do not promise the stop reached the server when delivery is unknown.
- **Appearance editing is absent.** There is no picker/import UI, appearance identifier, or saved selection. The current vector is replaceable in code only. The official status image's edit affordance does not justify showing one before an actual editor exists.
- **Activity/approval pages require real data.** The official image provides a useful information hierarchy. It does not authorize fabricated activity, permission summaries, goals, or memories. Preserve clear boundaries in the design while the independent feature research and gateway review complete.

## Motion policy to retain

The current wrapper reuses the MIT animator rather than implementing another engine. It pauses on inactive scenes and while the app-owned settings/history sheet is open, and uses a static pose for Reduce Motion. Keep those properties. The current wrapper only renders eyes, gaze, stretch, tilt, and float; upstream hats, claws, mouths, sparkles, and tap reactions are not implemented by this drawing and must not be advertised as present.

Use ordinary SwiftUI/native sheet and keyboard transitions. Hold ambient motion quiet while reading/editing. A future character asset should plug into the same presentation state contract without changing chat/transport behavior. No new particle effects or generic working/success loops are needed for the present stability pass.

## Sources

- [Repository rules](../../AGENTS.md)
- [Official Muse design article](https://introducing.muse.ai/) — source of the directly inspected status/activity image; full feature research is owned by the parent task.
- [Official Muse video](https://about.fb.com/ltam/wp-content/uploads/sites/14/2026/09/Muse-Sizzle-16x9-1.mp4) — the inspected 24-second frame is promotional/composited, not a complete phone layout.
- [Apple Liquid Glass sample documentation](https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass) — previously investigated by the coordinating task; the present review verifies actual reuse of the native API in code.

No new external library or copied product asset is proposed by this review.
