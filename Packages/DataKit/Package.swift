// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DataKit",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "DataKit", targets: ["DataKit"])
    ],
    dependencies: [
        .package(path: "../DomainKit")
    ],
    targets: [
        .target(
            name: "DataKit",
            dependencies: ["DomainKit"]
        )
    ]
)
