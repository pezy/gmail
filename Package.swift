// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Gmail",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Gmail", targets: ["Gmail"])
    ],
    dependencies: [
        .package(url: "https://github.com/openid/AppAuth-iOS.git", from: "1.7.5")
    ],
    targets: [
        .executableTarget(
            name: "Gmail",
            dependencies: [
                .product(name: "AppAuth", package: "AppAuth-iOS")
            ],
            path: "Sources/Gmail"
        ),
        .testTarget(
            name: "GmailTests",
            dependencies: ["Gmail"],
            path: "Tests/GmailTests"
        )
    ]
)
