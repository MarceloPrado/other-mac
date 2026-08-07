// swift-tools-version: 6.1

import PackageDescription

let package = Package(
  name: "OtherMac",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(name: "OtherMac", targets: ["OtherMac"])
  ],
  dependencies: [
    .package(
      url: "https://github.com/sindresorhus/KeyboardShortcuts",
      exact: "3.0.1"
    ),
    .package(
      url: "https://github.com/sparkle-project/Sparkle",
      exact: "2.9.2"
    )
  ],
  targets: [
    .executableTarget(
      name: "OtherMac",
      dependencies: [
        .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
        .product(name: "Sparkle", package: "Sparkle"),
      ],
      resources: [
        .copy("Resources/m1ddc"),
        .copy("Resources/AppIcon.icns"),
        .copy("Resources/m1ddc-LICENSE.txt"),
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "-rpath",
          "-Xlinker", "@executable_path/../Frameworks",
        ])
      ]
    ),
    .testTarget(
      name: "OtherMacTests",
      dependencies: ["OtherMac"]
    ),
  ]
)
