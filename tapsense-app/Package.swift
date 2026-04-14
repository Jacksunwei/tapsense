// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TapSenseApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "TapSenseApp", targets: ["TapSenseApp"]),
    ],
    targets: [
        .executableTarget(
            name: "TapSenseApp",
            path: "Sources/TapSenseApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        )
    ]
)
