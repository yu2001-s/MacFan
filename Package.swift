// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MacFan",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MacFanCore", targets: ["MacFanCore"]),
        .executable(name: "MacFan", targets: ["MacFan"]),
        .executable(name: "macfanctl", targets: ["macfanctl"])
    ],
    targets: [
        .target(
            name: "MacFanCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "MacFan",
            dependencies: ["MacFanCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "macfanctl",
            dependencies: ["MacFanCore"]
        )
    ]
)
