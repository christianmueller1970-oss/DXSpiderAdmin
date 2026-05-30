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
        .library(name: "DXSpiderCore", targets: ["DXSpiderCore"]),
        // Diagnostic CLI to capture real node output as parser fixtures (live test, §10).
        .executable(name: "dxspider-capture", targets: ["dxspider-capture"])
    ],
    targets: [
        .target(
            name: "DXSpiderCore",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .executableTarget(
            name: "dxspider-capture",
            dependencies: ["DXSpiderCore"],
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
