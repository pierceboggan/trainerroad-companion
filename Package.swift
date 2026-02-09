// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TrainerRoadMenuBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TrainerRoadMenuBar",
            path: "Sources"
        )
    ]
)
