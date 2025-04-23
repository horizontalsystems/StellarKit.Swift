// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "StellarKit",
    platforms: [
        .iOS(.v15),
    ],
    products: [
        .library(
            name: "StellarKit",
            targets: ["StellarKit"]
        ),
    ],
    dependencies: [
        .package(url: "git@github.com:Soneso/stellar-ios-mac-sdk.git", .upToNextMajor(from: "3.0.7")),
        .package(url: "https://github.com/groue/GRDB.swift.git", .upToNextMajor(from: "6.0.0")),
        .package(url: "https://github.com/horizontalsystems/HsToolKit.Swift.git", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/horizontalsystems/HsExtensions.Swift.git", .upToNextMajor(from: "1.0.6")),
    ],
    targets: [
        .target(
            name: "StellarKit",
            dependencies: [
                .product(name: "stellarsdk", package: "stellar-ios-mac-sdk"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "HsToolKit", package: "HsToolKit.Swift"),
                .product(name: "HsExtensions", package: "HsExtensions.Swift"),
            ]
        ),
    ]
)
