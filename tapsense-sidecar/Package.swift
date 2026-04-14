// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapSenseSidecar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TapSenseSidecar",
            path: "Sources/TapSenseSidecar",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
        .testTarget(
            name: "TapSenseSidecarTests",
            dependencies: ["TapSenseSidecar"]
        )
    ]
)
