// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "StardewModManager",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "StardewModManager",
            path: "StardewModManager"
        )
    ]
)
