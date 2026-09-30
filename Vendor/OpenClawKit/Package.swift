// swift-tools-version: 6.3

import PackageDescription

// Xcode's Apple compiler loads cross-import overlays automatically.
#if os(Linux)
let compatibilitySettings: [SwiftSetting] = [.unsafeFlags(["-Xfrontend", "-enable-cross-import-overlays"])]
#else
let compatibilitySettings: [SwiftSetting] = []
#endif

let package = Package(
    name: "OpenClawKit",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "OpenClawProtocol", targets: ["OpenClawProtocol"]),
        .library(name: "OpenClawNativeState", targets: ["OpenClawNativeState"]),
        .library(name: "OpenClawKit", targets: ["OpenClawKit"]),
        .library(name: "OpenClawChatUI", targets: ["OpenClawChatUI"]),
    ],
    traits: [
        .trait(name: "Talk", description: "ElevenLabs cloud TTS / talk support"),
        .default(enabledTraits: []),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", exact: "7.11.1"),
        .package(url: "https://github.com/mgriebling/SwiftMath", exact: "1.7.3"),
        .package(url: "https://github.com/swiftlang/swift-markdown", exact: "0.8.0"),
    ],
    targets: [
        .target(
            name: "OpenClawProtocol",
            path: "Sources/OpenClawProtocol",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ] + compatibilitySettings),
        .target(
            name: "OpenClawNativeState",
            path: "Sources/OpenClawNativeState",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ] + compatibilitySettings),
        .target(
            name: "OpenClawKit",
            dependencies: [
                "OpenClawNativeState",
                "OpenClawProtocol",
            ],
            path: "Sources/OpenClawKit",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ] + compatibilitySettings),
        .target(
            name: "OpenClawChatUI",
            dependencies: [
                "OpenClawKit",
                "OpenClawProtocol",
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "SwiftMath", package: "SwiftMath"),
            ],
            path: "Sources/OpenClawChatUI",
            resources: [
                .copy("Resources/Mermaid"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ] + compatibilitySettings),
        .testTarget(
            name: "OpenClawKitTests",
            dependencies: [
                "OpenClawKit",
                "OpenClawChatUI",
                "OpenClawProtocol",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Tests/OpenClawKitTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ] + compatibilitySettings),
        .testTarget(
            name: "OpenClawNativeStateTests",
            dependencies: ["OpenClawNativeState"],
            path: "Tests/OpenClawNativeStateTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
                .enableExperimentalFeature("SwiftTesting"),
            ] + compatibilitySettings),
    ])
