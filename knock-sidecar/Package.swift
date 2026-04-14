// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KnockSidecar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KnockSidecar",
            path: "Sources/KnockSidecar",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        )
    ]
)
