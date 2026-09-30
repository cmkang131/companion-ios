# 다운로드 / Downloads

[프리뷰 다운로드 페이지](https://github.com/cmkang131/companion-ios/releases/tag/v0.1.0-preview)

- **Companion-Source.zip**: 전체 프로젝트 소스와 검증 기록
- **Companion-Integration-Preview.zip**: 소스 + ARM64 iOS Simulator용 빌드

현재 전체 소스는 릴리스의 Companion-Source.zip 안에 있습니다. GitHub의 자동 Source code ZIP에는 포함되지 않습니다.
아이폰 직접 설치용 IPA가 아니며, 서버 연결과 최종 디자인은 아직 미완성입니다.

# Native Companion — first integration build

Private, single-user native iOS companion for an eventual OpenClaw gateway.
This is a **disconnected integration prototype**, not a finished Muse clone.

## Current implementation
- SwiftUI, iOS 26+, light mode only
- Official OpenClawKit/OpenClawChatUI source reused at a pinned revision
- Thin native navigation, history and connection sheets
- Native chat composer is disabled until an actual gateway is configured
- No model calls, server connection, credentials, signing identity or personal messages
- Neutral circle placeholder, not the final dot-like character
- No emoji in the app-owned UI

Read `AGENTS.md` before making changes. Prioritize existing compatible code; the user's intended custom-code share is minimal glue/styling, not a measured percentage guarantee.

## Verified on 2026-09-30
- Swift 6.4 Linux portable core tests: 3 passed
- xtool 1.20.1 + official Xcode 27 SDK: full native simulator compilation/link passed
- Binary load commands: ARM64 iOS Simulator, minimum iOS 26
- Corrected xtool's simulator bundle platform metadata from iPhoneOS to iPhoneSimulator
- Light-only bundle metadata and complete bundled diagram renderer resources checked

## Not yet verified or implemented
- No iOS simulator/device execution, screenshots, animation/fidelity or interaction QA
- No live OpenClaw gateway test
- No final character or Muse-level motion polish
- No signing, iPhone installation, TestFlight or App Store upload

The first build is a framework-integration milestone, not a usable assistant.

## Build
Use Swift 6.4 and xtool with the official Darwin SDK installed. From this folder:

    xtool dev build --triple arm64-apple-ios-simulator

The output is `xtool/Companion.app`. Validate and correct simulator metadata using the supplied script and an available LLVM objdump:

    python3 scripts/validate_bundle.py xtool/Companion.app --objdump /path/to/llvm-objdump --fix-metadata

This produces a simulator app, not a phone-installable IPA. Never relabel a device binary as a simulator binary; the validation checks its load commands first.

Portable tests:

    COMPANION_CORE_ONLY=1 swift test --scratch-path .build-core

Run core tests separately from dependency resolution/build. Core tests cover only the small portable module; they do not validate the upstream chat UI or gateway integration.

## Dependencies and notices
`Vendor/OpenClawKit` is source-vendored, with a preserved MIT license and recorded cross-compilation patches in `THIRD_PARTY_NOTICES.md`. The generated Mermaid resources and notices are included. `Package.resolved` pins the resolved Swift dependencies. The default cloud Talk trait is disabled.

`Research/REUSE-REVIEW.md` records the source-level comparison and remaining questions. Research assets and downloaded SDKs are not part of the application target and must not be bundled or redistributed with the source deliverable.
