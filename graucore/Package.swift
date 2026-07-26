// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "graucore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "graucore", targets: ["graucore"]),
    ],
    targets: [
        .target(
            name: "graucore",
            path: "Sources/graucore",
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                .enableExperimentalFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "graucoreTests",
            dependencies: ["graucore"],
            path: "Tests/graucoreTests"
        ),
    ]
)
