// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BibleMemorizeKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "BibleMemorizeKit",
            targets: ["BibleMemorizeKit"]
        )
    ],
    targets: [
        .target(
            name: "BibleMemorizeKit",
            path: "Sources/BibleMemorizeKit"
        )
    ]
)
