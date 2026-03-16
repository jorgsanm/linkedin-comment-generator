// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LinkedInCommentAssistant",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LinkedInCommentAssistantCore",
            targets: ["LinkedInCommentAssistantCore"]
        ),
        .executable(
            name: "LinkedInCommentAssistant",
            targets: ["LinkedInCommentAssistant"]
        )
    ],
    targets: [
        .target(
            name: "LinkedInCommentAssistantCore"
        ),
        .executableTarget(
            name: "LinkedInCommentAssistant",
            dependencies: ["LinkedInCommentAssistantCore"]
        ),
        .testTarget(
            name: "LinkedInCommentAssistantTests",
            dependencies: ["LinkedInCommentAssistantCore"]
        )
    ]
)
