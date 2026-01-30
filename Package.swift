// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VideoAnalyzer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VideoAnalyzer", targets: ["VideoAnalyzer"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0")
    ],
    targets: [
        .executableTarget(
            name: "VideoAnalyzer",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "VideoAnalyzer",
            exclude: ["Scripts"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
