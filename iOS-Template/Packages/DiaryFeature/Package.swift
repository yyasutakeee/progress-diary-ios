// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DiaryFeature",
    platforms: [.iOS(.v26)],
    products: [
        .library(name: "DiaryFeature", targets: ["DiaryFeature"])
    ],
    targets: [
        .target(name: "DiaryFeature", swiftSettings: [.swiftLanguageMode(.v5)])
    ]
)
