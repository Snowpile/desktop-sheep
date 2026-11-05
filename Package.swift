// swift-tools-version: 6.0
import Foundation
import PackageDescription

// With only the Command Line Tools installed (no Xcode), SwiftPM does not find
// the swift-testing macro plugin on its own. Point the compiler at it when present.
let cltTestingPlugins = "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"
let testSettings: [SwiftSetting] = FileManager.default.fileExists(atPath: cltTestingPlugins)
    ? [.unsafeFlags(["-plugin-path", cltTestingPlugins])]
    : []

let package = Package(
    name: "DesktopSheep",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "DesktopSheep", targets: ["DesktopSheep"]),
    ],
    targets: [
        // Pure logic: physics, behavior state machine, pixel-art sprites. No AppKit.
        .target(name: "SheepCore"),
        // AppKit shell: windows, menu bar item, mouse dragging, rendering.
        .executableTarget(name: "DesktopSheep", dependencies: ["SheepCore"]),
        // Art experiments: renders preview sheets of candidate art styles (docs/previews).
        .executableTarget(name: "ArtLab", dependencies: ["SheepCore"]),
        .testTarget(name: "SheepCoreTests", dependencies: ["SheepCore"], swiftSettings: testSettings),
    ]
)
