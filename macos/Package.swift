// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Gloss",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Gloss", targets: ["Gloss"]),
        .library(name: "GlossKit", targets: ["GlossKit"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0")
    ],
    targets: [
        .target(
            name: "GlossKit",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Gloss",
            dependencies: ["GlossKit"],
            path: "Sources/Gloss",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GlossTests",
            dependencies: ["Gloss", "GlossKit"]
        )
    ]
)
