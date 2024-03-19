// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Strings",
    defaultLocalization: "en",
    platforms: [.iOS("13.0")],
    products: [
        .library(
            name: "Strings",
            targets: ["Strings"]
        ),
    ],
    dependencies: [
        .package(path: "../../../../..")
    ],
    targets: [
        .target(
            name: "Strings",
            dependencies: [
            ],
            plugins: [
                .plugin(name: "LocalinterPlugin", package: "Localinter"),
            ]
        )
    ]
)
