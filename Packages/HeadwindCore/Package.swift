// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HeadwindCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HeadwindCore", targets: ["HeadwindCore"]),
    ],
    targets: [
        .target(
            name: "HeadwindCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "HeadwindCoreTests",
            dependencies: ["HeadwindCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
