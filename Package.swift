// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "StardewModManager",
    defaultLocalization: "en",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StardewModManager",
            path: "StardewModManager",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "StardewModManagerTests",
            dependencies: ["StardewModManager"],
            path: "Tests/StardewModManagerTests"
        )
    ]
)
