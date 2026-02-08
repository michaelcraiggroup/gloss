// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Gloss",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Gloss", targets: ["Gloss"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.5.0")
    ],
    targets: [
        .executableTarget(
            name: "Gloss",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown")
            ],
            path: "Sources/Gloss",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "GlossTests",
            dependencies: ["Gloss"]
        )
    ]
)
