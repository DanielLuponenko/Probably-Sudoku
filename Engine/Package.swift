// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProbablySudokuEngine",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ProbablySudokuEngine", targets: ["ProbablySudokuEngine"]),
    ],
    targets: [
        .target(name: "ProbablySudokuEngine", path: "Sources/NumberClubEngine"),
        .testTarget(name: "ProbablySudokuEngineTests", dependencies: ["ProbablySudokuEngine"],
                    path: "Tests/NumberClubEngineTests"),
        .executableTarget(name: "genbench", dependencies: ["ProbablySudokuEngine"]),
        .executableTarget(name: "simulate", dependencies: ["ProbablySudokuEngine"]),
    ]
)
