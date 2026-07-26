// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Codex Pulse",
    platforms: [.macOS(.v26)],
    products: [.executable(name: "Codex Pulse", targets: ["CodexPulse"])],
    targets: [
        .systemLibrary(name: "CSQLite"),
        .executableTarget(
            name: "CodexPulse",
            dependencies: ["CSQLite"],
            linkerSettings: [
                // Embed an Info.plist so privacy usage descriptions (PhotoKit)
                // are present even when the bare executable runs unbundled,
                // e.g. during Xcode debug runs.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Resources/EmbeddedInfo.plist",
                ]),
            ]
        ),
        .testTarget(name: "CodexPulseTests", dependencies: ["CodexPulse"])
    ]
)
