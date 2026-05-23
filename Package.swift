// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftJSON",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SwiftJSON", targets: ["SwiftJSON"]),
        .executable(name: "SwiftJSONBenchmark", targets: ["SwiftJSONBenchmark"]),
    ],
    targets: [
        .target(name: "SwiftJSON"),
        .executableTarget(name: "SwiftJSONBenchmark", dependencies: ["SwiftJSON"]),
        .testTarget(name: "SwiftJSONTests", dependencies: ["SwiftJSON"]),
    ]
)
