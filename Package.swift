// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "rental",
  platforms: [
    .iOS(.v16)
  ],
  products: [
    // xtool builds this product into the app
    .library(name: "rental", targets: ["rental"])
  ],
  targets: [
    .target(
      name: "rental"
    )
  ]
)
