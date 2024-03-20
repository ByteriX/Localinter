// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Localinter",
    platforms: [.iOS(.v12), .macOS(.v13)],
    products: [
        .library(
            name: "Localinter",
            targets: ["Localinter"]
        ),
        .plugin(
            name: "LocalinterPlugin",
            targets: ["LocalinterPlugin"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Localinter",
            dependencies: []
        ),
        .executableTarget(
            name: "LocalinterExec",
            dependencies: [
            ]
        ),
        .plugin(name: "LocalinterPlugin", capability: .buildTool(), dependencies: ["LocalinterExec"])
    ]
)
