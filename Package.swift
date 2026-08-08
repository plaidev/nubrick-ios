// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nubrick",
    platforms: [
        .iOS("15.0"),
    ],
    products: [
        .library(
            name: "Nubrick",
            targets: ["Nubrick"]
        ),
        .plugin(
            name: "NubrickDevTool",
            targets: ["NubrickDevTool"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/yoga.git", .upToNextMinor(from: "3.2.1")),
    ],
    targets: [
        // Production: Remote binary downloaded by SPM consumers
        .binaryTarget(
            name: "Nubrick",
            url: "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.7/Nubrick.xcframework.zip",
            checksum: "d54bb69bb9d5f406d2cab8c1e6e736fce5ab480cbabf9d65a92de95eab1e9af6"
        ),

        // Development: Source target for unit tests (supports @testable import)
        .target(
            name: "NubrickLocal",
            dependencies: ["YogaKit"],
            path: "Sources/Nubrick",
            exclude: ["PrivacyInfo.xcprivacy"],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "YogaKit",
            dependencies: ["yoga"],
            path: "Sources/YogaKit",
            publicHeadersPath: "include/YogaKit"
        ),

        // Unit tests use source target for @testable import
        .testTarget(
            name: "NubrickTests",
            dependencies: ["NubrickLocal"]
        ),

        // Build tool plugin for extracting embedding IDs at compile time
        .plugin(
            name: "NubrickDevTool",
            capability: .buildTool(),
            dependencies: ["NubrickDevToolRunner"]
        ),
        .executableTarget(
            name: "NubrickDevToolRunner",
            path: "Plugins/NubrickDevToolRunner"
        ),
    ],
    cxxLanguageStandard: CXXLanguageStandard(rawValue: "c++20")
)
