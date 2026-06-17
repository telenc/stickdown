// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Stickdown",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Stickdown",
            path: "Sources/Stickdown"
        )
    ],
    swiftLanguageModes: [.v5]
)
