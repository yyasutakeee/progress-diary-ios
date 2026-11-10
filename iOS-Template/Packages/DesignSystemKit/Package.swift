// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DesignSystemKit",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "DesignSystemKit", targets: ["DesignSystemKit"])
    ],
    targets: [
        .target(name: "DesignSystemKit", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
