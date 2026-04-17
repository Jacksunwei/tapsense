// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapSenseDaemon",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TapSenseDaemon", targets: ["TapSenseDaemon"]),
    ],
    dependencies: [
        .package(name: "TapSenseCore", path: "../tapsense-core"),
    ],
    targets: [
        .executableTarget(
            name: "TapSenseDaemon",
            dependencies: [.product(name: "TapSenseCore", package: "TapSenseCore")],
            path: "Sources/TapSenseDaemon"
        ),
        .testTarget(
            name: "TapSenseDaemonTests",
            dependencies: [.product(name: "TapSenseCore", package: "TapSenseCore")]
        )
    ]
)
