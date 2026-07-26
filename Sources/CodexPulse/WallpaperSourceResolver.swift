import Foundation
import UniformTypeIdentifiers

private func wallpaperContentType(for url: URL) -> UTType? {
    if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
       let contentType = values.contentType {
        return contentType
    }
    guard !url.pathExtension.isEmpty else { return nil }
    return UTType(filenameExtension: url.pathExtension)
}

private func isWallpaperVideoType(_ type: UTType) -> Bool {
    type.conforms(to: .movie) || type.conforms(to: .video)
}

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
        guard let type = wallpaperContentType(for: url),
              isWallpaperVideoType(type) else {
            return .image
        }
        return .video
    }
}

/// A wallpaper backed by a Photos-library asset. The pixels are only
/// reachable through PhotoKit, so the source carries the asset identifier and
/// the placement geometry parsed from the wallpaper Store.
struct WallpaperPhotoAsset: Sendable, Equatable, Hashable {
    let identifier: String
    let scaling: WallpaperScalingMode
}

enum WallpaperSource: Sendable, Equatable {
    enum Identity: Sendable, Equatable {
        case solid(WallpaperRGB)
        case solidImage(WallpaperSourceCandidate)
        case staticImage(WallpaperSourceCandidate)
        case phaseUnknown([WallpaperSourceCandidate])
        case photoAsset(WallpaperPhotoAsset)
        case unavailable
    }

    case solid(WallpaperRGB)
    /// A uniform-color asset whose sampled color fills the whole screen,
    /// independent of the desktop image scaling geometry.
    case solidImage(WallpaperSourceCandidate)
    case staticImage(WallpaperSourceCandidate)
    case phaseUnknown([WallpaperSourceCandidate])
    case photoAsset(WallpaperPhotoAsset)
    case unavailable

    var identity: Identity {
        switch self {
        case let .solid(color): .solid(color)
        case let .solidImage(candidate): .solidImage(candidate)
        case let .staticImage(candidate): .staticImage(candidate)
        case let .phaseUnknown(candidates): .phaseUnknown(candidates)
        case let .photoAsset(asset): .photoAsset(asset)
        case .unavailable: .unavailable
        }
    }

    var candidates: [WallpaperSourceCandidate] {
        switch self {
        case let .solidImage(candidate): [candidate]
        case let .staticImage(candidate): [candidate]
        case let .phaseUnknown(candidates): candidates
        case .solid, .photoAsset, .unavailable: []
        }
    }

    /// Scaling geometry dictated by the source itself, overriding the
    /// `NSWorkspace` desktop image options (which are stale for photo assets).
    var preferredScalingMode: WallpaperScalingMode? {
        if case let .photoAsset(asset) = self { return asset.scaling }
        return nil
    }
}

struct WallpaperSourceResolver: Sendable {
    static let defaultAerialResourcesDirectory = WallpaperStoreConfiguration.defaultAerialResourcesDirectory
    static let defaultNeptuneResourcesDirectory = WallpaperStoreConfiguration.defaultNeptuneResourcesDirectory
    static let defaultSystemSolidColorsDirectory = URL(
        filePath: "/System/Library/Desktop Pictures/Solid Colors",
        directoryHint: .isDirectory
    )
    static let defaultSequoiaResourcesDirectory = URL(
        filePath: "/System/Library/ExtensionKit/Extensions/WallpaperSequoiaExtension.appex/Contents/Resources",
        directoryHint: .isDirectory
    )

    let aerialResourcesDirectory: URL
    let neptuneResourcesDirectory: URL
    let systemSolidColorsDirectory: URL
    let sequoiaResourcesDirectory: URL
    let aerialMovieDirectories: [URL]

    init(
        aerialResourcesDirectory: URL = Self.defaultAerialResourcesDirectory,
        neptuneResourcesDirectory: URL = Self.defaultNeptuneResourcesDirectory,
        systemSolidColorsDirectory: URL = Self.defaultSystemSolidColorsDirectory,
        sequoiaResourcesDirectory: URL = Self.defaultSequoiaResourcesDirectory,
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
        self.systemSolidColorsDirectory = systemSolidColorsDirectory
        self.sequoiaResourcesDirectory = sequoiaResourcesDirectory
        self.aerialMovieDirectories = aerialMovieDirectories
    }

    func resolve(
        indexData: Data?,
        displayUUID: String?,
        workspaceURL: URL?,
        workspaceFillColor: WallpaperRGB? = nil,
        systemAppearance: PanelSemanticAppearance? = nil
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
            return .unavailable
        }

        if let color = WallpaperStoreConfiguration.solidColor(
            in: indexData,
            displayUUID: displayUUID,
            desktopFillColor: workspaceFillColor
        ) {
            return .solid(color)
        }

        if choices.contains(where: isSystemColorSelection) {
            guard let name = choices.lazy.compactMap(systemColorName(in:)).first,
                  let url = systemColorImageURL(named: name) else {
                return .unavailable
            }
            return .solidImage(WallpaperSourceCandidate(url: url, kind: .image))
        }

        if let photoAsset = photoAssetSource(choices: choices, content: content) {
            return photoAsset
        }

        let style = decodedDictionary(content["EncodedOptionValues"])
            .flatMap(styleID(in:))?
            .lowercased()
        var containsInvalidAuthoritativeSource = false
        for choice in choices {
            for file in fileURLs(in: choice) {
                if file.pathExtension.lowercased() == "madesktop" {
                    guard Self.isRegularReadableFile(file) else {
                        containsInvalidAuthoritativeSource = true
                        continue
                    }
                    if let source = desktopPictureSource(
                        descriptorURL: file,
                        style: style,
                        systemAppearance: systemAppearance
                    ) {
                        return source
                    }
                    containsInvalidAuthoritativeSource = true
                } else if Self.isSupportedMediaFile(file) {
                    return .staticImage(WallpaperSourceCandidate(url: file))
                }
            }
        }

        for choice in choices {
            guard let configuration = decodedDictionary(choice["Configuration"]),
                  configurationType(in: configuration)?.lowercased() == "systemdesktoppicture" else {
                continue
            }
            guard let url = configurationURL(in: configuration) else {
                containsInvalidAuthoritativeSource = true
                continue
            }
            if url.pathExtension.lowercased() == "madesktop" {
                if let source = desktopPictureSource(
                    descriptorURL: url,
                    style: style,
                    systemAppearance: systemAppearance
                ) {
                    return source
                }
                containsInvalidAuthoritativeSource = true
            } else if Self.isSupportedMediaFile(url) {
                return .staticImage(WallpaperSourceCandidate(url: url))
            } else {
                containsInvalidAuthoritativeSource = true
            }
        }

        let providers = choices.compactMap { $0["Provider"] as? String }
        let lowercasedProviders = providers.map { $0.lowercased() }

        if lowercasedProviders.contains("com.apple.neptuneoneextension") {
            return neptuneSource(content: content, systemAppearance: systemAppearance)
        }

        if lowercasedProviders.contains("com.apple.wallpaper.choice.sequoia") {
            return sequoiaSource(content: content, systemAppearance: systemAppearance)
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

        if !containsInvalidAuthoritativeSource,
           lowercasedProviders.contains(where: Self.allowsWorkspaceFallback),
           let workspaceURL,
           Self.isSupportedMediaFile(workspaceURL) {
            return .staticImage(WallpaperSourceCandidate(url: workspaceURL))
        }
        return .unavailable
    }

    private func desktopPictureSource(
        descriptorURL: URL,
        style: String?,
        systemAppearance: PanelSemanticAppearance? = nil
    ) -> WallpaperSource? {
        guard Self.isRegularReadableFile(descriptorURL),
              let data = try? Data(contentsOf: descriptorURL),
              let descriptor = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ) as? [String: Any],
              let thumbnailPath = descriptor["thumbnailPath"] as? String,
              let isDynamic = Self.boolValue(descriptor["isDynamic"]),
              let baseURL = Self.descriptorAssetURL(
                thumbnailPath,
                relativeTo: descriptorURL.deletingLastPathComponent()
              ),
              Self.isSupportedMediaFile(baseURL) else {
            return nil
        }

        guard isDynamic else {
            return .staticImage(WallpaperSourceCandidate(url: baseURL))
        }

        let stem = baseURL.deletingPathExtension().lastPathComponent
        let ext = baseURL.pathExtension
        let directory = baseURL.deletingLastPathComponent()
        let light = directory.appending(path: "\(stem) Light.\(ext)")
        let dark = directory.appending(path: "\(stem) Dark.\(ext)")

        if style?.contains("light") == true {
            let selected = Self.isSupportedMediaFile(light) ? light : baseURL
            return .staticImage(WallpaperSourceCandidate(url: selected))
        }
        if style?.contains("dark") == true {
            let selected = Self.isSupportedMediaFile(dark) ? dark : baseURL
            return .staticImage(WallpaperSourceCandidate(url: selected))
        }

        // Non-solar dynamic wallpapers switch phases with the system
        // appearance, so the current phase is known and its variant applies
        // directly instead of a cross-phase evaluation.
        if let systemAppearance, Self.boolValue(descriptor["isSolar"]) == false {
            let preferred = systemAppearance == .dark ? dark : light
            if Self.isSupportedMediaFile(preferred) {
                return .staticImage(WallpaperSourceCandidate(url: preferred))
            }
            return .staticImage(WallpaperSourceCandidate(url: baseURL))
        }

        return source(for: [baseURL, light, dark]
            .filter(Self.isSupportedMediaFile)
            .map { WallpaperSourceCandidate(url: $0) })
    }

    private func neptuneSource(
        content: [String: Any],
        systemAppearance: PanelSemanticAppearance? = nil
    ) -> WallpaperSource {
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
        return appearanceDrivenSource(
            light: light,
            dark: dark,
            systemAppearance: systemAppearance
        )
    }

    private func sequoiaSource(
        content: [String: Any],
        systemAppearance: PanelSemanticAppearance? = nil
    ) -> WallpaperSource {
        guard let options = decodedDictionary(content["EncodedOptionValues"]),
              let style = styleID(in: options)?.lowercased() else {
            return .unavailable
        }
        let light = sequoiaResourcesDirectory.appending(path: "thumbnail light.heic")
        let dark = sequoiaResourcesDirectory.appending(path: "thumbnail dark.heic")
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
        guard style == "dynamic" || style == "automatic" else { return .unavailable }
        return appearanceDrivenSource(
            light: light,
            dark: dark,
            systemAppearance: systemAppearance
        )
    }

    /// Dynamic styles switch with the system appearance; with a known
    /// appearance the matching variant applies directly, otherwise every
    /// readable phase is evaluated together.
    private func appearanceDrivenSource(
        light: URL,
        dark: URL,
        systemAppearance: PanelSemanticAppearance?
    ) -> WallpaperSource {
        if let systemAppearance {
            let preferred = systemAppearance == .dark ? dark : light
            if Self.isReadableFile(preferred) {
                return .staticImage(WallpaperSourceCandidate(url: preferred))
            }
        }
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
        if let url = value as? URL { return url.isFileURL ? url : nil }
        if let string = value as? String {
            if let url = URL(string: string), url.scheme != nil {
                return url.isFileURL ? url : nil
            }
            return URL(filePath: string)
        }
        if let dictionary = value as? [String: Any] {
            for key in ["URL", "url", "Path", "path", "relative"] {
                if let value = dictionary[key], let url = fileURL(value) { return url }
            }
        }
        return nil
    }

    private func configurationType(in configuration: [String: Any]) -> String? {
        if let type = configuration["type"] as? String { return type }
        for key in ["value", "configuration", "relative"] {
            if let nested = configuration[key] as? [String: Any],
               let type = configurationType(in: nested) {
                return type
            }
        }
        return nil
    }

    private func configurationURL(in configuration: [String: Any]) -> URL? {
        for key in ["url", "URL"] {
            if let value = configuration[key], let url = Self.fileURL(value) {
                return url.isFileURL ? url : nil
            }
        }
        for value in configuration.values {
            if let nested = value as? [String: Any],
               let url = configurationURL(in: nested) {
                return url
            }
        }
        return nil
    }

    private func assetID(in choice: [String: Any]) -> String? {
        decodedDictionary(choice["Configuration"])?["assetID"] as? String
    }

    /// Recognizes Photos-library wallpapers (`com.apple.wallpaper.extension.photos`
    /// with an `asset` configuration). The Store carries only the PhotoKit
    /// asset identifier plus the placement option — no local file path.
    private func photoAssetSource(
        choices: [[String: Any]],
        content: [String: Any]
    ) -> WallpaperSource? {
        for choice in choices {
            guard let provider = (choice["Provider"] as? String)?.lowercased(),
                  provider.contains("wallpaper.extension.photos"),
                  let configuration = decodedDictionary(choice["Configuration"]),
                  configurationType(in: configuration)?.lowercased() == "asset",
                  let identifier = configuration["identifier"] as? String,
                  !identifier.isEmpty else {
                continue
            }
            let placement = decodedDictionary(content["EncodedOptionValues"])
                .flatMap(placementID(in:))?
                .lowercased()
            return .photoAsset(WallpaperPhotoAsset(
                identifier: identifier,
                scaling: Self.scalingMode(forPlacement: placement)
            ))
        }
        return nil
    }

    private func placementID(in options: [String: Any]) -> String? {
        if let flattened = options["placement.picker._0.id"] as? String { return flattened }
        guard let values = options["values"] as? [String: Any],
              let placement = values["placement"] as? [String: Any],
              let picker = placement["picker"] as? [String: Any],
              let zero = picker["_0"] as? [String: Any] else {
            return nil
        }
        return zero["id"] as? String
    }

    private static func scalingMode(forPlacement placement: String?) -> WallpaperScalingMode {
        switch placement {
        case "fit": .fit
        case "stretch": .stretch
        case "center": .center
        // Photos wallpapers default to cropping the picture to fill the screen.
        default: .fill
        }
    }

    private func isSystemColorSelection(_ choice: [String: Any]) -> Bool {
        guard let configuration = decodedDictionary(choice["Configuration"]) else {
            return false
        }
        return configurationType(in: configuration)?.lowercased() == "systemcolor"
    }

    private func systemColorName(in choice: [String: Any]) -> String? {
        guard let configuration = decodedDictionary(choice["Configuration"]) else {
            return nil
        }
        if let name = configuration["systemColor"] as? String, !name.isEmpty {
            return name
        }
        guard let colors = configuration["systemColor"] as? [String: Any] else {
            return nil
        }
        return colors.keys.sorted().first
    }

    private func systemColorImageURL(named name: String) -> URL? {
        let normalizedName = Self.normalizedSystemColorName(name)
        guard !normalizedName.isEmpty,
              let urls = try? FileManager.default.contentsOfDirectory(
                  at: systemSolidColorsDirectory,
                  includingPropertiesForKeys: [.isRegularFileKey, .contentTypeKey],
                  options: [.skipsHiddenFiles]
              ) else {
            return nil
        }
        return urls.sorted { $0.path < $1.path }.first {
            $0.pathExtension.caseInsensitiveCompare("png") == .orderedSame
                && Self.normalizedSystemColorName(
                    $0.deletingPathExtension().lastPathComponent
                ) == normalizedName
                && Self.isSupportedMediaFile($0)
        }
    }

    private static func normalizedSystemColorName(_ value: String) -> String {
        value
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
            .lowercased()
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

    private static func allowsWorkspaceFallback(_ provider: String) -> Bool {
        [
            "com.apple.wallpaper.choice.image",
            "com.apple.wallpaper.choice.image-folder",
            "com.apple.wallpaper.choice.photos",
            "com.apple.wallpaper.choice.movie",
        ].contains(provider)
    }

    private static func descriptorAssetURL(_ path: String, relativeTo directory: URL) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url.isFileURL ? url : nil
        }
        guard !path.isEmpty else { return nil }
        return path.hasPrefix("/")
            ? URL(filePath: path)
            : directory.appending(path: path)
    }

    private static func boolValue(_ value: Any?) -> Bool? {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return nil
    }

    private static func isSupportedMediaFile(_ url: URL) -> Bool {
        guard isRegularReadableFile(url),
              let type = wallpaperContentType(for: url) else {
            return false
        }
        return type.conforms(to: .image) || isWallpaperVideoType(type)
    }

    private static func isRegularReadableFile(_ url: URL) -> Bool {
        guard url.isFileURL,
              FileManager.default.isReadableFile(atPath: url.path),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey]) else {
            return false
        }
        return values.isRegularFile == true
    }

    private static func isReadableFile(_ url: URL) -> Bool {
        isRegularReadableFile(url)
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
        } else if case let .photoAsset(asset) = source {
            colorDescription = " asset=\(asset.identifier) scaling=\(asset.scaling)"
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
        if case .solidImage = source { return "Colors" }
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
