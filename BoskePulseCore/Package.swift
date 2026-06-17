// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BoskePulseCore",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "BoskePulseCore", targets: ["BoskePulseCore"]),
    ],
    targets: [
        .target(
            name: "BoskePulseCore",
            path: "Sources/BoskePulseCore",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "BoskePulseCoreTests",
            dependencies: ["BoskePulseCore"],
            path: "Tests/BoskePulseCoreTests"
        ),
    ]
)
