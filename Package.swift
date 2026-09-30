// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacMusicPlayer",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "MacMusicPlayer",
            path: "MacMusicPlayer",
            exclude: ["Info.plist", "Assets.xcassets", "Resources"]
        )
    ]
)
