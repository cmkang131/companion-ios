// swift-tools-version: 6.3
import PackageDescription
import Foundation
let coreOnly = ProcessInfo.processInfo.environment["COMPANION_CORE_ONLY"] == "1"
var targets: [Target] = [
    .target(name: "CompanionCore"),
    .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"])
]
var dependencies: [Package.Dependency] = []
if !coreOnly {
    dependencies.append(.package(path: "Vendor/OpenClawKit", traits: []))
    targets.append(.target(name: "Companion", dependencies: [
        "CompanionCore", .product(name: "OpenClawChatUI", package: "OpenClawKit"),
        .product(name: "OpenClawKit", package: "OpenClawKit")
    ], resources: [.process("Resources")]))
}
let package = Package(name: "Companion", platforms: [.iOS(.v26)], products: [
    .library(name: coreOnly ? "CompanionCore" : "Companion", targets: [coreOnly ? "CompanionCore" : "Companion"])
], dependencies: dependencies, targets: targets)
