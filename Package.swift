// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "unpkg",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(name: "unpkg", targets: ["unpkg"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "unpkg",
            dependencies: [],
            path: ".",
            exclude: [
                "Info.plist",
                "Makefile",
                "README.md",
                "COPYING",
                "End-user Read Me.rtf",
                "unpkg.app",
                "unpkg-notarize.zip"
            ],
            sources: [
                "unpkg.swift"
            ],
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)