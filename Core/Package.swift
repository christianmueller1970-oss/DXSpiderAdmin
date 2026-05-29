// swift-tools-version: 6.0
import PackageDescription

// DXSpiderCore: pure, UI-free logic for the DXSpiderAdmin macOS app.
// Kept testable without a running DXSpider node.
let package = Package(
    name: "DXSpiderCore",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "DXSpiderCore", targets: ["DXSpiderCore"])
    ],
    targets: [
        .target(
            name: "DXSpiderCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "DXSpiderCoreTests",
            dependencies: ["DXSpiderCore"]
        )
    ]
)
