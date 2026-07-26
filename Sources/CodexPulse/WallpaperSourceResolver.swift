import Foundation

enum WallpaperAssetKind: Sendable, Equatable, Hashable {
    case image
    case video
}

struct WallpaperSourceCandidate: Sendable, Equatable, Hashable {
    let url: URL
    let modificationDate: Date?
    let fileSize: Int?
    let kind: WallpaperAssetKind

    init(url: URL, kind: WallpaperAssetKind? = nil) {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        self.url = url
        modificationDate = values?.contentModificationDate
        fileSize = values?.fileSize
        self.kind = kind ?? Self.kind(for: url)
    }

    private static func kind(for url: URL) -> WallpaperAssetKind {
        switch url.pathExtension.lowercased() {
        case "mov", "mp4", "m4v": .video
        default: .image
        }
    }
}

enum WallpaperSource: Sendable, Equatable {
    enum Identity: Sendable, Equatable {
        case solid(WallpaperRGB)
        case staticImage(WallpaperSourceCandidate)
        case phaseUnknown([WallpaperSourceCandidate])
        case unavailable
    }

    case solid(WallpaperRGB)
    case staticImage(WallpaperSourceCandidate)
    case phaseUnknown([WallpaperSourceCandidate])
    case unavailable

    var identity: Identity {
        switch self {
        case let .solid(color): .solid(color)
        case let .staticImage(candidate): .staticImage(candidate)
        case let .phaseUnknown(candidates): .phaseUnknown(candidates)
        case .unavailable: .unavailable
        }
    }

    var candidates: [WallpaperSourceCandidate] {
        switch self {
        case let .staticImage(candidate): [candidate]
        case let .phaseUnknown(candidates): candidates
        case .solid, .unavailable: []
        }
    }
}

struct WallpaperSourceResolver: Sendable {
    static let defaultAerialResourcesDirectory = WallpaperStoreConfiguration.defaultAerialResourcesDirectory
    static let defaultNeptuneResourcesDirectory = WallpaperStoreConfiguration.defaultNeptuneResourcesDirectory

    let aerialResourcesDirectory: URL
    let neptuneResourcesDirectory: URL
    let aerialMovieDirectories: [URL]

    init(
        aerialResourcesDirectory: URL = Self.defaultAerialResourcesDirectory,
        neptuneResourcesDirectory: URL = Self.defaultNeptuneResourcesDirectory,
        aerialMovieDirectories: [URL] = [
            FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Library/Application Support/com.apple.wallpaper/aerials/videos"),
            URL(filePath: "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR240FPS"),
            URL(filePath: "/Library/Application Support/com.apple.idleassetsd/Customer/4KHDR240FPS"),
            URL(filePath: "/Library/Application Support/com.apple.idleassetsd/Customer/4KSDR120FPS"),
            URL(filePath: "/Library/Application Support/com.apple.idleassetsd/Customer/1080p240FPS"),
        ]
    ) {
        self.aerialResourcesDirectory = aerialResourcesDirectory
        self.neptuneResourcesDirectory = neptuneResourcesDirectory
        self.aerialMovieDirectories = aerialMovieDirectories
    }

    func resolve(
        indexData: Data?,
        displayUUID: String?,
        workspaceURL: URL?
    ) -> WallpaperSource {
        guard let indexData,
              let root = try? PropertyListSerialization.propertyList(
                from: indexData,
                options: [],
                format: nil
              ) as? [String: Any],
              let selection = selectedConfiguration(in: root, displayUUID: displayUUID),
              let content = desktopContent(in: selection),
              let choices = content["Choices"] as? [[String: Any]],
              !choices.isEmpty else {
            return workspaceURL.map { .staticImage(WallpaperSourceCandidate(url: $0)) } ?? .unavailable
        }

        if let color = WallpaperStoreConfiguration.solidColor(
            in: indexData,
            displayUUID: displayUUID
        ) {
            return .solid(color)
        }

        let providers = choices.compactMap { $0["Provider"] as? String }
        let lowercasedProviders = providers.map { $0.lowercased() }
        let files = choices.flatMap(fileURLs(in:))
        if lowercasedProviders.contains(where: Self.isFileBackedProvider) {
            if let file = files.first(where: Self.isReadableFile) {
                return .staticImage(WallpaperSourceCandidate(url: file))
            }
            return workspaceURL.map { .staticImage(WallpaperSourceCandidate(url: $0)) } ?? .unavailable
        }

        if lowercasedProviders.contains(where: { $0.contains("neptuneoneextension") }) {
            return neptuneSource(content: content)
        }

        if let assetID = choices.lazy.compactMap(assetID(in:)).first {
            var candidates: [WallpaperSourceCandidate] = []
            let preview = aerialResourcesDirectory.appending(path: "\(assetID).png")
            if Self.isReadableFile(preview) {
                candidates.append(WallpaperSourceCandidate(url: preview, kind: .image))
            }
            if let movie = aerialMovieURL(assetID: assetID) {
                candidates.append(WallpaperSourceCandidate(url: movie, kind: .video))
            }
            return source(for: candidates)
        }

        // A Store-backed extension/procedural selection is authoritative even when its
        // private renderer cannot be sampled. Never substitute NSWorkspace's stale URL.
        if lowercasedProviders.contains(where: Self.isStoreBackedDynamicProvider) {
            return .unavailable
        }
        return .unavailable
    }

    private func neptuneSource(content: [String: Any]) -> WallpaperSource {
        guard let options = decodedDictionary(content["EncodedOptionValues"]),
              let style = styleID(in: options)?.lowercased() else {
            return .unavailable
        }
        let light = neptuneResourcesDirectory.appending(path: "TahoeLight.heic")
        let dark = neptuneResourcesDirectory.appending(path: "TahoeDark.heic")
        if style.contains("light") {
            return Self.isReadableFile(light)
                ? .staticImage(WallpaperSourceCandidate(url: light))
                : .unavailable
        }
        if style.contains("dark") {
            return Self.isReadableFile(dark)
                ? .staticImage(WallpaperSourceCandidate(url: dark))
                : .unavailable
        }
        guard style == "dynamic" else { return .unavailable }
        return source(for: [light, dark]
            .filter(Self.isReadableFile)
            .map { WallpaperSourceCandidate(url: $0) })
    }

    private func source(for candidates: [WallpaperSourceCandidate]) -> WallpaperSource {
        let unique = Dictionary(grouping: candidates, by: \.url)
            .compactMap { $0.value.first }
            .sorted { $0.url.path < $1.url.path }
        switch unique.count {
        case 0: return .unavailable
        case 1: return .staticImage(unique[0])
        default: return .phaseUnknown(unique)
        }
    }

    private func aerialMovieURL(assetID: String) -> URL? {
        let extensions = ["mov", "mp4", "m4v"]
        for directory in aerialMovieDirectories {
            for ext in extensions {
                let direct = directory.appending(path: "\(assetID).\(ext)")
                if Self.isReadableFile(direct) { return direct }
            }
        }
        return nil
    }

    private func fileURLs(in choice: [String: Any]) -> [URL] {
        guard let files = choice["Files"] as? [Any] else { return [] }
        return files.compactMap(Self.fileURL)
    }

    private static func fileURL(_ value: Any) -> URL? {
        if let url = value as? URL { return url }
        if let string = value as? String {
            return URL(string: string).flatMap { $0.isFileURL ? $0 : nil }
                ?? URL(filePath: string)
        }
        if let dictionary = value as? [String: Any] {
            for key in ["URL", "url", "Path", "path", "relative"] {
                if let value = dictionary[key], let url = fileURL(value) { return url }
            }
        }
        return nil
    }

    private func assetID(in choice: [String: Any]) -> String? {
        decodedDictionary(choice["Configuration"])?["assetID"] as? String
    }

    private func decodedDictionary(_ value: Any?) -> [String: Any]? {
        guard let data = value as? Data else { return value as? [String: Any] }
        return try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
    }

    private func styleID(in options: [String: Any]) -> String? {
        if let flattened = options["style.picker._0.id"] as? String { return flattened }
        guard let values = options["values"] as? [String: Any],
              let style = values["style"] as? [String: Any],
              let picker = style["picker"] as? [String: Any],
              let zero = picker["_0"] as? [String: Any] else {
            return nil
        }
        return zero["id"] as? String
    }

    private func selectedConfiguration(
        in root: [String: Any],
        displayUUID: String?
    ) -> [String: Any]? {
        if let displayUUID,
           let displays = root["Displays"] as? [String: Any],
           let display = displays[displayUUID] as? [String: Any] {
            return display
        }
        for key in ["AllSpacesAndDisplays", "SystemDefault"] {
            if let selection = root[key] as? [String: Any] { return selection }
        }
        return nil
    }

    private func desktopContent(in selection: [String: Any]) -> [String: Any]? {
        guard let desktop = selection["Desktop"] as? [String: Any] else { return nil }
        return desktop["Content"] as? [String: Any]
    }

    private static func isFileBackedProvider(_ provider: String) -> Bool {
        ["picture", "photo", "movie", "choice.image"].contains { provider.contains($0) }
    }

    private static func isStoreBackedDynamicProvider(_ provider: String) -> Bool {
        provider.contains("extension")
            || provider.contains("aerial")
            || provider.contains("dynamic")
            || provider.contains("procedural")
    }

    private static func isReadableFile(_ url: URL) -> Bool {
        FileManager.default.isReadableFile(atPath: url.path)
    }

    #if DEBUG
    func debugDescription(
        indexData: Data?,
        displayUUID: String?,
        source: WallpaperSource
    ) -> String {
        let providers = debugProviders(in: indexData, displayUUID: displayUUID)
        let type = debugType(for: source, providers: providers)
        let paths = source.candidates.map(\.url.path)
        let pathDescription = paths.isEmpty ? "none" : paths.joined(separator: " | ")
        let providerDescription = providers.isEmpty ? "none" : providers.joined(separator: " | ")
        let colorDescription: String
        if case let .solid(color) = source {
            colorDescription = " color=\(color.debugRGBDescription)"
        } else {
            colorDescription = ""
        }
        return "source type=\(type) provider=\(providerDescription) paths=\(pathDescription)\(colorDescription)"
    }

    private func debugProviders(in indexData: Data?, displayUUID: String?) -> [String] {
        guard let indexData,
              let root = try? PropertyListSerialization.propertyList(
                from: indexData,
                options: [],
                format: nil
              ) as? [String: Any],
              let selection = selectedConfiguration(in: root, displayUUID: displayUUID),
              let content = desktopContent(in: selection),
              let choices = content["Choices"] as? [[String: Any]] else {
            return []
        }
        return choices.compactMap { $0["Provider"] as? String }
    }

    private func debugType(for source: WallpaperSource, providers: [String]) -> String {
        let normalized = providers.map { $0.lowercased() }
        if case .solid = source { return "Colors" }
        if normalized.contains(where: { $0.contains("photo") }) { return "Photos" }
        if normalized.contains(where: { $0.contains("movie") }) { return "Movies" }
        if normalized.contains(where: {
            $0.contains("aerial")
                || $0.contains("dynamic")
                || $0.contains("extension")
                || $0.contains("macintosh")
                || $0.contains("procedural")
        }) {
            return "Dynamic Wallpapers"
        }
        if normalized.contains(where: { $0.contains("picture") || $0.contains("choice.image") }) {
            if source.candidates.contains(where: { $0.kind == .video }) {
                return "Movies"
            }
            return "Pictures"
        }
        if source.candidates.contains(where: { $0.kind == .video }) { return "Movies" }
        if case .unavailable = source { return "Unavailable" }
        return "Pictures"
    }
    #endif
}
