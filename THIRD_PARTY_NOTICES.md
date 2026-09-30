# Third-party source

OpenClawKit / OpenClawChatUI / OpenClawProtocol / OpenClawNativeState
Source: https://github.com/openclaw/openclaw/tree/ebe57ef28af64c073de8264c7052ce519f1fda23/apps/shared/OpenClawKit
Copyright (c) 2026 OpenClaw Foundation. MIT License.
A complete license is retained at Vendor/OpenClawKit/LICENSE.
The application opts out of the default Talk trait. A local manifest patch removes the unused ElevenLabsKit package/product declaration because Swift Build reported a missing product while resolving a disabled trait. Cloud voice is not enabled. Transitive dependency notices must be audited after resolution and before distribution.

Research checkouts are references only, excluded from the application's target sources. No Grok/Muse assets have been incorporated.

Local source adaptations are intentionally small compared with the vendored foundation: iOS transport glue; safe gateway diagnostic categories/private error logs; text-draft capture/restore; a read-only response activity/completion projection; native iOS typography; composer accessibility and disconnected-state guards; reduced-motion transitions; and the code-drawn Companion character driven by the existing MIT mascot animator. These are local changes, not upstream behavior guarantees. No measured custom-code percentage is claimed.

The current character and app icon are code drawings based on a user-supplied visual reference. The private reference image is not bundled or committed. Companion is an independent OpenClaw client and does not claim to be an official Muse or OpenAI dot application.

Cross-compilation compatibility patch: enable Swift cross-import overlays in the vendored Swift targets, so AVKit + SwiftUI exposes VideoPlayer under the open-source Linux compiler. No API replacement or feature stub is used. Generated Mermaid resources were built from the same pinned upstream source; their bundled NOTICE.txt is retained.

Simulator packaging: the app Info.plist is corrected to iPhoneSimulator only after the binary load commands prove it is an iOS Simulator executable. UIUserInterfaceStyle is set to Light.
