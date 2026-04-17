// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "tapsense-cli",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "tapsense-cli", targets: ["tapsense-cli"]),
    ],
    dependencies: [
        .package(name: "TapSenseCore", path: "../tapsense-core"),
    ],
    targets: [
        .executableTarget(
            name: "tapsense-cli",
            dependencies: [
                .product(name: "TapSenseCore", package: "TapSenseCore"),
            ],
            path: "Sources/tapsense-cli"
        ),
    ]
)
