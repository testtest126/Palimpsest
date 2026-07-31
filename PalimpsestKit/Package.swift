// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PalimpsestKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PalimpsestKit", targets: ["PalimpsestKit"]),
        .executable(name: "palimpsest-run", targets: ["PalimpsestRunner"]),
    ],
    targets: [
        // Vendored Go rules engine — see Sources/GoKit/VENDORED.md.
        .target(name: "GoKit", exclude: ["VENDORED.md"]),
        .target(name: "PalimpsestKit", dependencies: ["GoKit"]),
        .executableTarget(name: "PalimpsestRunner", dependencies: ["PalimpsestKit"]),
        .testTarget(name: "PalimpsestKitTests", dependencies: ["PalimpsestKit", "GoKit"]),
    ]
)
