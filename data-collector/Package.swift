// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "data-collector",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../tapsense-sidecar")
    ],
    targets: [
        .executableTarget(
            name: "data-collector",
            dependencies: [
                .product(name: "TapSenseCore", package: "tapsense-sidecar")
            ],
            path: "Sources/data-collector"
        ),
    ]
)
