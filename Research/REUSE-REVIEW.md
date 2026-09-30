# Reuse investigation — 2026-09-30

Implementation is paused at the user's request while this investigation is performed. Target: a private, single-user native iOS OpenClaw client, visually inspired by Muse, with a restrained dot-like character. Personal/noncommercial-only candidates are included but their actual terms and provenance still matter. No third-party source has been incorporated into the app yet.

## Strongest architectural candidate

Use the **official OpenClaw Swift modules**, not a newly invented gateway protocol. Source checkout: https://github.com/openclaw/openclaw, commit ebe57ef28af64c073de8264c7052ce519f1fda23. Root LICENSE is MIT. Package at apps/shared/OpenClawKit uses Swift tools 6.3, iOS 18+, with OpenClawProtocol, OpenClawNativeState, OpenClawKit, and OpenClawChatUI products. Inspected actual GatewayConnectOptions, GatewayChannel challenge signing, ChatTransport, package dependency declarations, and test filenames. These include device-scoped authentication, challenge timestamps, gateway identity, reconnect/backoff, chat events, progress cards, questions/approvals and streaming-related state.

Important: tests exist but were NOT run in this investigation. Match the server and client to a compatible pinned release. Avoid importing the full official app's Watch/WebRTC targets; use the reusable package. The Talk feature defaults on and introduces ElevenLabs support, so disable unnecessary features and audit dependency resolution rather than silently enabling a cloud voice provider. Phone background behavior and push are separate integration work; Apple's official hosted relay is not automatically available to custom builds.

## Candidates inspected

| Candidate | Evidence | Fit and decision |
|---|---|---|
| Official OpenClawKit | Source, manifest, MIT license, auth and transport code, tests inspected | First choice for protocol and data/state foundation; visual skin remains custom |
| caspian9/SmartChatApp | Full checkout, MIT license, project.yml, README, GatewayChatTransport code | Useful event/card rendering reference; early v0.0.1; README explicitly warns stubs report success without action and event mapping targets a particular server; not a ready-made foundation to trust wholesale |
| Parham-dev/OpenClaw-ios | Full checkout, README, actual dashboard screenshot | Native but dashboard-heavy, not Muse-like. Requires custom stats-server skill and broad server tools. README badge says MIT but no LICENSE file found in checkout; copying needs clarification. Exclude as main base |
| nano-muse/nanoMuse | Full checkout, README, directory structure, mascot image | GPL-3.0 project, Android/web/desktop; iOS planned. Dragon mascot image differs greatly from requested dot look. Useful product reference, not a SwiftUI base |
| nasawz/GrokBot | Full checkout, BSD-3-Clause license, Dart widget/controller/geometry data inspected | Actual configurable blink, gaze, spring and pose machinery; Flutter, not Swift. Can inform/port animation logic, but do not assume repository license clears third-party character geometry rights |
| Mr-XiaoLiang/GrokBot | Public README and repository license declaration | Android Jetpack Compose port of grok-icon-study; not direct iOS reuse |
| blessonism/grok-icon-study | README and live browser demo visually inspected | Actual Grok-style character study, 18 shapes/25 eye shapes described. Source includes a learning-only/no redistribution notice and extracted-app provenance. Demo visibly renders character; website accessibility text says geometry missing, a contradictory signal. Treat as study reference, not automatically licensed production asset |
| unionst/swift-chat | Full checkout, README, LICENSE inspected | Attractive iMessage-oriented package but CLOSED SOURCE binary under custom free-use license, not OSS. Not ideal for deep restyling, inspection or Linux tooling |
| exyte/Chat | Full checkout, MIT license, Package.swift inspected | Real native SwiftUI chat framework, iOS17+, customizable cells. Includes Giphy binary SDK, media picker, Kingfisher and popup dependencies; do not adopt the whole dependency tree merely for bubbles. Evaluate stripped components only if official chat is insufficient |
| rive-app/rive-ios | Official runtime README and licensing docs | MIT native runtime, supports SwiftUI and interactive state machines; reusable engine, not ready-made Muse/dot animation assets. Asset authoring and Linux cross-build compatibility remain unverified |
| b3ll/Motion | Official README | Interruptible physical animations in Swift; candidate only if native SwiftUI springs prove insufficient |
| EmergeTools/Pow and GetStream/swiftui-spring-animations | Public project descriptions/examples | Reference for specific micro-interactions, not a license to add decorative effects |

Other projects named Muse found in search were music players, coding-agent tools, model prompts or unrelated papers. No verified complete native iOS Muse clone or dot-character reconstruction has been found in this search. This is a search result, not proof none exists.

## Directly observed visual references

- Official Muse App Store screenshot: compact centered avatar and name, quiet grey assistant bubbles and pale blue user bubbles, inline browser/action card, restrained composer and bottom navigation. Animation timing cannot be inferred from a still.
- Parham OpenClaw dashboard screenshot: black background, large CPU/RAM/disk gauges, colorful command tiles; rejects the requested conversational aesthetic despite being native.
- nanoMuse avatar-moods.png: rendered yellow dragon with props, unsuitable as the requested character.
- grok-icon-study live demo: monochrome rounded body, white eyes, shape/expression controls, displayed in the cloud browser. This confirms a visible demo exists, not iOS performance or source completeness.

## Apple design basis

Primary reference: https://developer.apple.com/design/human-interface-guidelines/materials
Liquid Glass belongs to the controls/navigation layer, not every message or content card. Use sparingly; native controls already provide platform behavior. Do not stack blur/glass wrappers for decoration.

Official implementation reference: https://developer.apple.com/documentation/swiftui/landmarks-building-an-app-with-liquid-glass
Use native toolbar grouping, GlassEffectContainer/glassEffectID for related control transitions where warranted, standard materials for content. Respect Dynamic Type, contrast, Reduce Motion and Reduce Transparency. No emoji UI.

## Proposed next implementation decision

1. Keep SwiftUI, with a minimal native app shell and original restrained visuals.
2. Reuse official OpenClawKit protocol/auth/state instead of maintaining a separate homemade protocol.
3. Evaluate official OpenClawChatUI customization first; use SmartChatApp only for narrowly reviewed event/card patterns.
4. For character behavior, compare native OpenClawMascotAnimator's state/micro-motion architecture with Grok's spring-based study. Keep geometry/assets separately replaceable; do not let character choice dictate app framework.
5. Do not add Flutter, a webview shell, an admin dashboard, Giphy, or a cloud voice provider merely to accelerate the first screen.
6. Validate one chat screen, connection/reconnection and a small set of character states on a real iOS build before expanding to tabs.

## Remaining verification

- Actual official Muse motion/interaction reference beyond stills
- Native rendering and frame pacing on the user's device
- SDK cross-compilation; Xcode27 download is complete, but xtool SDK build failed on github.com DNS before extraction and has not been retried while implementation is paused
- Minimal official package build without unnecessary modules
- Server version, final HTTPS endpoint, authentication/pairing, and phone signing/install path
- Exact legal provenance of third-party Grok geometry, distinct from permissive licenses on wrapper code

## Follow-up source-level findings

- Official `OpenClawChatView` already exposes `drawsBackground`, `userAccent`, `showsAssistantAvatars`, `composerChrome: .clean`, `showsComposer`, assistant identity and intro/prompt options. This is stronger evidence for restyling an existing chat than for writing a new transcript implementation.
- Official native mascot code already uses `TimelineView`, independently stored animation state, pause support, reduced-motion static poses and mood transitions. Its lobster artwork is unsuitable; its architecture is a useful native reference without introducing Flutter.
- Exyte's current manifest imports GiphyUISDK directly. That is a meaningful integration cost for a light, restrained single-user client with no need for GIF search.
- Swift Chat's manifest downloads a binary XCFramework; the repository title alone should not be mistaken for source availability.
- Latest user direction: maximize reuse, ideally under about 10% custom glue/styling; light mode only. This is an implementation target, not a measured ratio. Keep the foundation coherent rather than adding many packages.
