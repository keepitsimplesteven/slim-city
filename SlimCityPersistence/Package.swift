// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlimCityPersistence",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SlimCityPersistence",
            targets: ["SlimCityPersistence"]
        )
    ],
    dependencies: [
        .package(path: "../SlimCityCore")
    ],
    targets: [
        .target(
            name: "SlimCityPersistence",
            dependencies: ["SlimCityCore"]
        ),
        .testTarget(
            name: "SlimCityPersistenceTests",
            dependencies: ["SlimCityPersistence"]
        )
    ]
)
