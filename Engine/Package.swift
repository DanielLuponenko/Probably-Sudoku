// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NumberClubEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "NumberClubEngine", targets: ["NumberClubEngine"]),
    ],
    targets: [
        .target(name: "NumberClubEngine"),
        .testTarget(name: "NumberClubEngineTests", dependencies: ["NumberClubEngine"]),
        .executableTarget(name: "genbench", dependencies: ["NumberClubEngine"]),
        .executableTarget(name: "simulate", dependencies: ["NumberClubEngine"]),
    ]
)
