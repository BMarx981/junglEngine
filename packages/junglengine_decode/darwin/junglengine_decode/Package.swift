// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "junglengine_decode",
  platforms: [
    .iOS("15.0"),
    .macOS("10.14"),
  ],
  products: [
    .library(name: "junglengine-decode", targets: ["junglengine_decode"])
  ],
  dependencies: [
    .package(name: "FlutterFramework", path: "../FlutterFramework")
  ],
  targets: [
    .target(
      name: "junglengine_decode",
      dependencies: [
        .product(name: "FlutterFramework", package: "FlutterFramework")
      ]
    )
  ]
)
