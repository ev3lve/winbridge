// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WinBridge",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "WinBridge",
            path: "Sources/WinBridge"
        ),
        .testTarget(
            name: "WinBridgeTests",
            dependencies: ["WinBridge"],
            path: "Tests/WinBridgeTests"
        )
    ]
)
