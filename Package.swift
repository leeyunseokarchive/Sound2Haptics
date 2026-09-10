// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sound2Haptics",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Sound2HapticsCore",
            targets: ["Sound2HapticsCore"]
        ),
        .executable(
            name: "Sound2Haptics",
            targets: ["Sound2Haptics"]
        )
    ],
    targets: [
        .target(
            name: "Sound2HapticsCore",
            dependencies: []
        ),
        .executableTarget(
            name: "Sound2Haptics",
            dependencies: ["Sound2HapticsCore"]
        ),
        .testTarget(
            name: "Sound2HapticsCoreTests",
            dependencies: ["Sound2HapticsCore"]
        )
    ]
)
