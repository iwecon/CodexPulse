// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Codex Pulse",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "Codex Pulse", targets: ["CodexPulse"])],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.brew(["sqlite3"])]),
        .executableTarget(name: "CodexPulse", dependencies: ["CSQLite"]),
        .testTarget(name: "CodexPulseTests", dependencies: ["CodexPulse"])
    ]
)
