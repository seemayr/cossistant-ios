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
  dependencies: [
    .package(url: "https://github.com/SFSafeSymbols/SFSafeSymbols.git", "5.3.0"..<"7.0.0"),
    .package(url: "https://github.com/yaslab/ULID.swift.git", from: "1.3.0"),
  ],
  targets: [
    .target(
      name: "Cossistant",
      dependencies: [
        "SFSafeSymbols",
        .product(name: "ULID", package: "ulid.swift"),
      ],
      resources: [.process("Resources")]
    ),
    .testTarget(
      name: "CossistantTests",
      dependencies: ["Cossistant"]
    ),
  ]
)
