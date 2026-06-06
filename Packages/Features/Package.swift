// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [.iOS(.v18)],
    products: [.library(name: "Features", targets: ["Features"])],
    dependencies: [
        .package(path: "../DomainKit"),
        .package(path: "../DesignSystem"),
        .package(path: "../DataKit"),
        .package(path: "../Platform")
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: [
                "DomainKit",
                "DesignSystem",
                "DataKit",
                "Platform"
            ]
        )
    ]
)
