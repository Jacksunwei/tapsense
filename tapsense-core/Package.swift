// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapSenseCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TapSenseCore", targets: ["TapSenseCore"]),
    ],
    targets: [
        .target(
            name: "TapSenseCore",
            path: "Sources/TapSenseCore",
            resources: [.copy("tap_model.mlmodelc")],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .testTarget(
            name: "TapSenseCoreTests",
            dependencies: ["TapSenseCore"]
        )
    ]
)
