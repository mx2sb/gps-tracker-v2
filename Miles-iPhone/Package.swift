// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "MilesCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "MilesCore", targets: ["MilesCore"])],
    targets: [
        .target(name: "MilesCore", path: "Miles", exclude: ["MilesApp.swift", "Recorder.swift", "Info.plist"], sources: ["Core.swift"]),
        .testTarget(name: "MilesCoreTests", dependencies: ["MilesCore"], path: "Tests")
    ]
)
