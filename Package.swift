// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "CastingADream",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "CastingADream", path: "Sources/CastingADream")
    ]
)
