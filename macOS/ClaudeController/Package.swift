// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ClaudeController",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "ClaudeController", targets: ["ClaudeController"])
    ],
    targets: [
        .executableTarget(
            name: "ClaudeController",
            path: "Sources"
        )
    ]
)
