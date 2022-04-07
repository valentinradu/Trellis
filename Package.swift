// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Trellis",
    platforms: [
        .iOS(.v14), .macOS(.v11), .tvOS(.v14),
        .macCatalyst(.v14), .watchOS(.v7), .driverKit(.v20),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "Trellis",
            targets: ["Trellis"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/wickwirew/Runtime.git",
                 from: .init(2, 2, 4))
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "Trellis",
            dependencies: ["Runtime"]
        ),
        .testTarget(
            name: "TrellisTests",
            dependencies: ["Trellis"]
        ),
    ]
)
