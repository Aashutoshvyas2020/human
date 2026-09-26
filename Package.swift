// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "DuoFoldCore",
  platforms: [.macOS(.v13)],
  products: [.library(name: "DuoFoldCore", targets: ["DuoFoldCore"])],
  targets: [
    .target(name: "DuoFoldCore", path: "App/Core"),
    .testTarget(name: "DuoFoldCoreTests", dependencies: ["DuoFoldCore"], path: "Tests")
  ]
)
