// swift-tools-version:5.9
import PackageDescription
let package = Package(
  name: "SKSpike",
  platforms: [.iOS(.v17)],
  products: [.library(name: "SKSpike", targets: ["SKSpike"])],
  targets: [
    .target(name: "SKSpike"),
    .testTarget(name: "SKSpikeTests", dependencies: ["SKSpike"], resources: [.copy("Restock.storekit")])
  ])
