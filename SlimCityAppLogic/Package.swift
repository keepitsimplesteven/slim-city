// swift-tools-version: 5.9
import PackageDescription

// Headless verification harness for the framework-FREE app-layer logic.
//
// The iOS/watchOS app targets (SceneKit, HealthKit, WatchConnectivity, SwiftUI)
// can only be compiled by Xcode against a simulator SDK, and xcodebuild cannot
// resolve the local SwiftPM packages under the Kiro nested sandbox. This package
// exists so the PURE pieces of the app layer — the grid↔world mapper, the city
// view-model intents, the daily-claim coordinator, the WatchConnectivity payload
// codec, and the ledger reconciler — can still be unit-tested with
// `swift test --disable-sandbox` (see scripts/test.sh). It compiles the SAME
// source files via symlinks, so there is no duplicate to drift. It is NOT part
// of the shipping app and is not referenced by SlimCity.xcodeproj.
let package = Package(
    name: "SlimCityAppLogic",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
        .macOS(.v14)
    ],
    products: [
        .library(name: "SlimCityAppLogic", targets: ["SlimCityAppLogic"])
    ],
    dependencies: [
        .package(path: "../SlimCityCore")
    ],
    targets: [
        .target(
            name: "SlimCityAppLogic",
            dependencies: ["SlimCityCore"]
        ),
        .testTarget(
            name: "SlimCityAppLogicTests",
            dependencies: ["SlimCityAppLogic", "SlimCityCore"]
        )
    ]
)
