// swift-tools-version: 5.8
import PackageDescription

let package = Package(
    name: "CPAMonitorBar",
    platforms: [.macOS("26.5")],
    products: [
        .executable(name: "CPAMonitorBar", targets: ["CPAMonitorBar"]),
    ],
    targets: [
        .target(name: "CPAModels"),
        .target(name: "CPAClient", dependencies: ["CPAModels"]),
        .executableTarget(
            name: "CPAMonitorBar",
            dependencies: ["CPAModels", "CPAClient"]
        ),
        .testTarget(
            name: "CPAClientTests",
            dependencies: ["CPAModels", "CPAClient", "CPAMonitorBar"],
            resources: [.process("Fixtures")]
        ),
    ]
)
