// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Nubrick",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Nubrick", targets: ["Nubrick"]),
    ],
    targets: [
        .binaryTarget(
            name: "Nubrick",
            url: "https://github.com/plaidev/nubrick-ios/releases/download/v0.20.0/Nubrick.xcframework.zip",
            checksum: "9da2f79b794c502deff71282faf72ea2bbb74a9cf0782f6c0196a8b0ef2fe069"
        ),
    ]
)
