// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ontode",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),
        .package(url: "https://github.com/JohnSundell/Splash.git", from: "0.16.0"),
    ],
    targets: [
        .executableTarget(
            name: "ontode",
            dependencies: [
                .product(name: "Markdown", package: "swift-markdown"),
                .product(name: "Splash", package: "Splash"),
            ],
            path: "Sources/ontode",
            resources: [.process("Resources/AppIcon.png")]
        )
    ]
)
