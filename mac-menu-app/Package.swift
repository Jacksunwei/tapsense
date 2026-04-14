// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KnockMenuApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KnockMenuApp", targets: ["KnockMenuApp"]),
    ],
    targets: [
        .executableTarget(
            name: "KnockMenuApp",
            path: "Sources/KnockMenuApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
            ]
        )
    ]
)
