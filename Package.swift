// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Nativebrik",
    platforms: [
        .iOS("13.4"),
    ],
    products: [
        .library(
            name: "Nativebrik",
            targets: ["Nativebrik"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/nalexn/ViewInspector", exact: "0.9.11"),
        .package(url: "https://github.com/facebook/yoga.git", .upToNextMinor(from: "3.2.1")),
    ],
    targets: [
        .target(
            name: "Nativebrik",
            dependencies: ["YogaKit"],
            path: "Sources/Nativebrik",
            exclude: ["PrivacyInfo.xcprivacy"],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .target(
            name: "YogaKit",
            dependencies: ["yoga"],
            path: "Sources/YogaKit",
            publicHeadersPath: "include/YogaKit",
            cxxSettings: [
                .unsafeFlags(["-std=c++17"])
            ]
        ),
        .testTarget(
            name: "NativebrikTests",
            dependencies: ["Nativebrik", .product(name: "ViewInspector", package: "ViewInspector")]
        ),
    ]
)
