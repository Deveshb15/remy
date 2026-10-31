// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RemyKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "RemyKit", targets: ["RemyKit"])],
    targets: [
        .target(name: "RemyKit"),
        .testTarget(name: "RemyKitTests", dependencies: ["RemyKit"]),
    ]
)
