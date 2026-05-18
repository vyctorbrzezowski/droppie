// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "Droppie",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .executable(name: "Droppie", targets: ["Droppie"]),
    .library(name: "DroppieCore", targets: ["DroppieCore"])
  ],
  dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
  ],
  targets: [
    .target(
      name: "DroppieCore",
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("Security")
      ]
    ),
    .executableTarget(
      name: "Droppie",
      dependencies: [
        "DroppieCore",
        .product(name: "Sparkle", package: "Sparkle")
      ],
      resources: [
        .process("Resources")
      ],
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("SwiftUI")
      ]
    ),
    .testTarget(
      name: "DroppieCoreTests",
      dependencies: ["DroppieCore"]
    )
  ]
)
