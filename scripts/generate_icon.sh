#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p .build-tools/module-cache
xcrun swiftc -j 2 -module-cache-path .build-tools/module-cache -target arm64-apple-macos26.0 \
  Vendor/OpenClawKit/Sources/OpenClawChatUI/OpenClawMascotAnimator.swift \
  Vendor/OpenClawKit/Sources/OpenClawChatUI/OpenClawMascotView.swift \
  Vendor/OpenClawKit/Sources/OpenClawChatUI/OpenClawMascotCanvas+Accessories.swift \
  Vendor/OpenClawKit/Sources/OpenClawChatUI/ChatTypography.swift \
  Vendor/OpenClawKit/Sources/OpenClawChatUI/CompanionCharacterView.swift \
  scripts/generate_icon.swift -o .build-tools/render-character
.build-tools/render-character Sources/Companion/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
