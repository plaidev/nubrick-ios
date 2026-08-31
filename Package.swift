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
    ],
    dependencies: [
        .package(url: "https://github.com/facebook/yoga.git", .upToNextMinor(from: "3.2.1")),
    ],
    targets: [
        // Production: Remote binary downloaded by SPM consumers
        .binaryTarget(
            name: "Nubrick",
            url: "https://github.com/plaidev/nubrick-ios/releases/download/v0.19.12/Nubrick.xcframework.zip",
            checksum: "d19edd48b11179f085b451649f6beaae8e66ceec8266e7630142ce8ebb5ecb7a"
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
    ],
    cxxLanguageStandard: CXXLanguageStandard(rawValue: "c++20")
)
