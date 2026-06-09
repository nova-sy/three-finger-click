// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ThreeFingerClick",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ThreeFingerClick", targets: ["ThreeFingerClick"])
    ],
    targets: [
        .executableTarget(
            name: "ThreeFingerClick",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "ThreeFingerClickTests",
            dependencies: ["ThreeFingerClick"]
        )
    ]
)
