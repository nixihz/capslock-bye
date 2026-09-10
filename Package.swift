// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CapsBye",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "CapsBye", targets: ["CapsBye"])],
    targets: [
        .target(name: "CapsCore"),
        .executableTarget(name: "CapsBye", dependencies: ["CapsCore"]),
        .testTarget(name: "CapsCoreTests", dependencies: ["CapsCore"]),
        .testTarget(name: "CapsEngineTests", dependencies: ["CapsBye", "CapsCore"])
    ],
    swiftLanguageModes: [.v5]
)
