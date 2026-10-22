// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Periodical",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PeriodicalCore"),
        .executableTarget(name: "Periodical", dependencies: ["PeriodicalCore"]),
        .testTarget(name: "PeriodicalCoreTests", dependencies: ["PeriodicalCore"]),
    ]
)
