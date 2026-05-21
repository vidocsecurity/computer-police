// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ComputerPolice",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ComputerPolice", targets: ["ComputerPolice"]),
        .library(name: "ComputerPoliceCore", targets: ["ComputerPoliceCore"]),
    ],
    targets: [
        .target(
            name: "ComputerPoliceCore",
            resources: [
                .process("Resources"),
            ]),
        .executableTarget(
            name: "ComputerPolice",
            dependencies: ["ComputerPoliceCore"]),
        .testTarget(
            name: "ComputerPoliceCoreTests",
            dependencies: ["ComputerPoliceCore"],
            path: "Tests/ComputerPoliceCoreTests"),
    ])
