// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TagClip",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "TagClip",
            path: "Sources/TagClip"
        )
    ]
)
