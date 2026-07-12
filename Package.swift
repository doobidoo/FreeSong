// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FreeSong",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .macCatalyst(.v16)
    ],
    products: [
        .library(name: "FreeSongCore", targets: ["FreeSongCore"]),
        .library(name: "FreeSongStorage", targets: ["FreeSongStorage"]),
        .library(name: "FreeSongImport", targets: ["FreeSongImport"]),
        .library(name: "FreeSongSync", targets: ["FreeSongSync"]),
        .library(name: "FreeSongApp", targets: ["FreeSongApp"]),
        .executable(name: "FreeSong", targets: ["FreeSong"]),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.0"),
    ],
    targets: [
        // Core Domain - Pure Swift, no platform dependencies
        .target(
            name: "FreeSongCore",
            dependencies: [],
            path: "Sources/FreeSongCore"
        ),
        .testTarget(
            name: "FreeSongCoreTests",
            dependencies: ["FreeSongCore"],
            path: "Tests/FreeSongCoreTests"
        ),

        // Storage Layer
        .target(
            name: "FreeSongStorage",
            dependencies: ["FreeSongCore"],
            path: "Sources/FreeSongStorage",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "FreeSongStorageTests",
            dependencies: ["FreeSongStorage", "FreeSongCore"],
            path: "Tests/FreeSongStorageTests"
        ),
        // OnSong Import
        .target(
            name: "FreeSongImport",
            dependencies: ["FreeSongCore", "FreeSongStorage", "ZIPFoundation", .product(name: "SQLite", package: "SQLite.swift")],
            path: "Sources/FreeSongImport"
        ),
        .testTarget(
            name: "FreeSongImportTests",
            dependencies: ["FreeSongImport", "FreeSongCore", "FreeSongStorage"],
            path: "Tests/FreeSongImportTests"
        ),

        // GitHub Sync
        .target(
            name: "FreeSongSync",
            dependencies: ["FreeSongCore", "FreeSongStorage"],
            path: "Sources/FreeSongSync"
        ),
        .testTarget(
            name: "FreeSongSyncTests",
            dependencies: ["FreeSongSync", "FreeSongCore", "FreeSongStorage"],
            path: "Tests/FreeSongSyncTests"
        ),

        // SwiftUI App
        .target(
            name: "FreeSongApp",
            dependencies: ["FreeSongCore", "FreeSongStorage", "FreeSongImport", "FreeSongSync"],
            path: "Sources/FreeSongApp",
            resources: [.process("Resources")]
        ),

        // iOS App Host
        .executableTarget(
            name: "FreeSong",
            dependencies: ["FreeSongApp"],
            path: "Sources/FreeSong"
        ),
    ]
)
