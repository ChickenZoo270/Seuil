// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "IntentionCore",
    products: [.library(name: "IntentionCore", targets: ["IntentionCore"])],
    targets: [
        .target(name: "IntentionCore", path: "Core"),
        .testTarget(name: "IntentionCoreTests", dependencies: ["IntentionCore"], path: "Tests")
    ]
)
