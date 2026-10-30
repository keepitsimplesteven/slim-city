// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlimCityCore",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SlimCityCore",
            targets: ["SlimCityCore"]
        )
    ],
    targets: [
        .target(
            name: "SlimCityCore"
        ),
        .testTarget(
            name: "SlimCityCoreTests",
            dependencies: ["SlimCityCore"]
        )
    ]
)
