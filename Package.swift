// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "Cossistant",
  platforms: [
    .iOS(.v17),
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "Cossistant",
      targets: ["Cossistant"]
    ),
  ],
  targets: [
    .target(
      name: "Cossistant"
    ),
  ]
)
