// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HapticBeat",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "HapticBeatCore",
            targets: ["HapticBeatCore"]
        ),
        .executable(
            name: "HapticBeat",
            targets: ["HapticBeat"]
        )
    ],
    targets: [
        .target(
            name: "HapticBeatCore",
            dependencies: []
        ),
        .executableTarget(
            name: "HapticBeat",
            dependencies: ["HapticBeatCore"]
        ),
        .testTarget(
            name: "HapticBeatCoreTests",
            dependencies: ["HapticBeatCore"]
        )
    ]
)
