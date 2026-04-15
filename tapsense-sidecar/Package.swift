// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapSenseSidecar",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TapSenseCore", targets: ["TapSenseCore"]),
        .executable(name: "TapSenseSidecar", targets: ["TapSenseSidecar"]),
    ],
    targets: [
        .target(
            name: "TapSenseCore",
            path: "Sources/TapSenseCore",
            resources: [.process("tap_model.mlpackage")],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .executableTarget(
            name: "TapSenseSidecar",
            dependencies: ["TapSenseCore"],
            path: "Sources/TapSenseSidecar"
        ),
        .testTarget(
            name: "TapSenseSidecarTests",
            dependencies: ["TapSenseCore"]
        )
    ]
)
