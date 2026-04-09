// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SkillReaderMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SkillReaderMac",
            path: "Sources/SkillReaderMac"
        )
    ]
)
