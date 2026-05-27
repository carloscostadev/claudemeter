// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Thoth",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Thoth",
            path: "Sources/Thoth"
        ),
        .testTarget(
            name: "ThothTests",
            dependencies: ["Thoth"],
            path: "Tests/ThothTests"
        )
    ]
)
