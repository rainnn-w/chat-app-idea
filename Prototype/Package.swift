// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ChatMemoryPrototype",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "ChatMemoryDomain", targets: ["ChatMemoryDomain"]),
        .library(name: "ChatMemoryUI", targets: ["ChatMemoryUI"])
    ],
    targets: [
        .target(
            name: "ChatMemoryDomain",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "DomainSmokeTests",
            dependencies: ["ChatMemoryDomain"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .target(
            name: "ChatMemoryUI",
            dependencies: ["ChatMemoryDomain"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "ChatMemoryPrototypeApp",
            dependencies: ["ChatMemoryUI"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ChatMemoryUITests",
            dependencies: ["ChatMemoryDomain"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)

