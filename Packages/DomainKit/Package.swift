// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DomainKit",
    platforms: [.iOS(.v18)],
    products: [.library(name: "DomainKit", targets: ["DomainKit"])],
    targets: [.target(name: "DomainKit")]
)
