// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PackagePolice",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "PackagePolice", targets: ["PackagePolice"]),
        .library(name: "PackagePoliceCore", targets: ["PackagePoliceCore"]),
    ],
    targets: [
        .target(
            name: "PackagePoliceCore",
            resources: [
                .process("Resources"),
            ]),
        .executableTarget(
            name: "PackagePolice",
            dependencies: ["PackagePoliceCore"]),
        .testTarget(
            name: "PackagePoliceCoreTests",
            dependencies: ["PackagePoliceCore"],
            path: "Tests/PackagePoliceCoreTests"),
    ])
