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
    targets: [
        .target(
            name: "Nativebrik",
            path: "ios/Nativebrik/Nativebrik",
            exclude: ["PrivacyInfo.xcprivacy"],
            resources: [
                .copy("PrivacyInfo.xcprivacy")
            ]
        ),
        .binaryTarget(
            name: "Yoga",
            url: "https://cdn.nativebrik.com/sdk/spm/yoga/2.0.0/yoga.xcframework.zip",
            checksum: "19b4ab4cdf3ec7c5d9809b3f3230d33dccbc4917033c712c9e7175e835eca695"
        ),
        .binaryTarget(
            name: "YogaKit",
            url: "https://cdn.nativebrik.com/sdk/spm/YogaKit/2.0.0/YogaKit.xcframework.zip",
            checksum: "10567c44d05e2a7cfaffc14b52b4a499921e48fdf0d78aa7f5c1537c1e365460"
        ),
    ]
)
