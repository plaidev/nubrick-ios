// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nubrick",
    platforms: [
        .iOS("13.4"),
    ],
    products: [
        .library(
            name: "Nubrick",
            targets: ["Nubrick"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", exact: "0.10.3"),
        .package(url: "https://github.com/facebook/yoga.git", .upToNextMinor(from: "3.2.1")),
    ],
    targets: [
        // Production: Remote binary downloaded by SPM consumers
        .binaryTarget(
            name: "Nubrick",
            url: "https://github.com/plaidev/nubrick-ios/releases/download/v0.15.1/Nubrick.xcframework.zip",
            checksum: "6065f86f3881c006ee3899b8e56e6115a74aa56174734ca87030d968abef6087"
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
            dependencies: ["NubrickLocal", .product(name: "ViewInspector", package: "ViewInspector")]
        ),
    ],
    cxxLanguageStandard: CXXLanguageStandard(rawValue: "c++20")
)
