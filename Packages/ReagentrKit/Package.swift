// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ReagentrKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "ReagentrKit", targets: ["ReagentrKit"])],
    targets: [
        .target(name: "ReagentrKit"),
        .testTarget(name: "ReagentrKitTests", dependencies: ["ReagentrKit"]),
    ]
)
