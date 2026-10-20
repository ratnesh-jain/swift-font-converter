// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-font-converter",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "convert-font",
            targets: ["ConvertFont"]
        ),
        .library(
            name: "FontConverterKit",
            targets: ["FontConverterKit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.17.0"),
    ],
    targets: [
        .target(
            name: "FontConverterKit"
        ),
        .executableTarget(
            name: "ConvertFont",
            dependencies: [
                "FontConverterKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "FontConverterKitTests",
            dependencies: [
                "FontConverterKit",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ]
)
