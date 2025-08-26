// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "nativebrik_bridge",
    platforms: [
        .iOS("13.4")
    ],
    products: [
        .library(name: "nativebrik-bridge", targets: ["nativebrik_bridge"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/plaidev/nativebrik-sdk.git",
            exact: "0.11.1"
        )
    ],
    targets: [
        .target(
            name: "nativebrik_bridge",
            dependencies: [
                .product(name: "Nativebrik", package: "nativebrik-sdk")
            ]
        )
    ]
)
