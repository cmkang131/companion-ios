# Third-party source

OpenClawKit / OpenClawChatUI / OpenClawProtocol / OpenClawNativeState
Source: https://github.com/openclaw/openclaw/tree/ebe57ef28af64c073de8264c7052ce519f1fda23/apps/shared/OpenClawKit
Copyright (c) 2026 OpenClaw Foundation. MIT License.
A complete license is retained at Vendor/OpenClawKit/LICENSE.
The application opts out of the default Talk trait. Local manifest-only patch removes the unused ElevenLabsKit package/product declaration because Swift Build reported a missing product while resolving a disabled trait. Upstream source files are unchanged; cloud voice is not enabled. Transitive dependency notices must be audited after resolution and before distribution.

Research checkouts are references only, excluded from the application's target sources. No Grok/Muse assets have been incorporated.

Cross-compilation compatibility patch: enable Swift cross-import overlays in the vendored Swift targets, so AVKit + SwiftUI exposes VideoPlayer under the open-source Linux compiler. No API replacement or feature stub is used. Generated Mermaid resources were built from the same pinned upstream source; their bundled NOTICE.txt is retained.

Simulator packaging: the app Info.plist is corrected to iPhoneSimulator only after the binary load commands prove it is an iOS Simulator executable. UIUserInterfaceStyle is set to Light.
