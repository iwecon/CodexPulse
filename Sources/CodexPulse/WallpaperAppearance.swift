import AppKit
import AVFoundation
import CoreGraphics
import Darwin
import Dispatch
import ImageIO

enum PanelSemanticAppearance: Sendable, Equatable {
    case light
    case dark

    init(appKitAppearance: NSAppearance) {
        self = appKitAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? .dark
            : .light
    }

    var foregroundColor: NSColor {
        self == .dark ? .white : .black
    }

    var shadowColor: NSColor {
        self == .dark ? .black : .white
    }
}

enum WallpaperScalingMode: Sendable, Equatable {
    case fit
    case fill
    case stretch
    case center

    static func desktopImageMode(scaling: NSImageScaling, allowClipping: Bool) -> Self {
        switch scaling {
        case .scaleAxesIndependently:
            .stretch
        case .scaleNone:
            .center
        case .scaleProportionallyDown, .scaleProportionallyUpOrDown:
            allowClipping ? .fill : .fit
        @unknown default:
            allowClipping ? .fill : .fit
        }
    }
}

struct WallpaperRGB: Sendable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var relativeLuminance: Double {
        0.2126 * Self.linear(red) + 0.7152 * Self.linear(green) + 0.0722 * Self.linear(blue)
    }

    private static func linear(_ component: Double) -> Double {
        let bounded = min(max(component, 0), 1)
        return bounded <= 0.04045
            ? bounded / 12.92
            : pow((bounded + 0.055) / 1.055, 2.4)
    }
}

#if DEBUG
extension WallpaperRGB {
    var debugRGBDescription: String {
        let redByte = Int((min(max(red, 0), 1) * 255).rounded())
        let greenByte = Int((min(max(green, 0), 1) * 255).rounded())
        let blueByte = Int((min(max(blue, 0), 1) * 255).rounded())
        return String(
            format: "rgb(%.4f,%.4f,%.4f) #%02X%02X%02X",
            red,
            green,
            blue,
            redByte,
            greenByte,
            blueByte
        )
    }
}
#endif

struct WallpaperStateSignature: Sendable, Equatable {
    struct ImageIdentity: Sendable, Equatable {
        let url: URL
        let modificationDate: Date?
        let fileSize: Int?
    }

    let image: ImageIdentity?
    let solidColor: WallpaperRGB?
    let sourceIdentity: WallpaperSource.Identity?
    let imageScalingRawValue: UInt
    let allowClipping: Bool
    let fillColor: WallpaperRGB?

    init(
        image: ImageIdentity?,
        solidColor: WallpaperRGB? = nil,
        sourceIdentity: WallpaperSource.Identity? = nil,
        imageScalingRawValue: UInt,
        allowClipping: Bool,
        fillColor: WallpaperRGB?
    ) {
        self.image = image
        self.solidColor = solidColor
        self.sourceIdentity = sourceIdentity
        self.imageScalingRawValue = imageScalingRawValue
        self.allowClipping = allowClipping
        self.fillColor = fillColor
    }
}

struct WallpaperRefreshState: Sendable, Equatable {
    struct PanelRegion: Sendable, Equatable {
        let identifier: Int
        let frame: CGRect
    }

    let signature: WallpaperStateSignature
    let screenIdentifier: UInt32?
    let screenSize: CGSize
    let panelRegions: [PanelRegion]
}

enum WallpaperRefreshTransition: Sendable, Equatable {
    case unchanged
    case resample(invalidateDecodedWallpaper: Bool)
    case removed
}

enum WallpaperRefreshReason: Sendable, Equatable {
    case stateCheck
    case wallpaperStoreChanged
}

struct WallpaperRefreshTracker: Sendable {
    private(set) var state: WallpaperRefreshState?

    mutating func transition(
        to newState: WallpaperRefreshState?,
        reason: WallpaperRefreshReason = .stateCheck
    ) -> WallpaperRefreshTransition {
        if state == newState {
            guard reason == .wallpaperStoreChanged, newState != nil else { return .unchanged }
            return .resample(invalidateDecodedWallpaper: true)
        }
        let previousState = state
        state = newState
        guard let newState else { return .removed }
        return .resample(
            invalidateDecodedWallpaper: reason == .wallpaperStoreChanged || previousState.map {
                $0.signature.image != newState.signature.image
                    || $0.signature.sourceIdentity != newState.signature.sourceIdentity
            } ?? false
        )
    }
}

enum WallpaperStoreConfiguration {
    static let defaultStoreDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/com.apple.wallpaper/Store", directoryHint: .isDirectory)
    static let defaultAerialResourcesDirectory = URL(
        filePath: "/System/Library/ExtensionKit/Extensions/WallpaperAerialsExtension.appex/Contents/Resources",
        directoryHint: .isDirectory
    )
    static let defaultNeptuneResourcesDirectory = URL(
        filePath: "/System/Library/ExtensionKit/Extensions/NeptuneOneWallpaper.appex/Contents/Resources",
        directoryHint: .isDirectory
    )

    static func solidColor(
        at indexURL: URL,
        displayUUID: String?,
        desktopFillColor: WallpaperRGB? = nil
    ) -> WallpaperRGB? {
        guard let data = try? Data(contentsOf: indexURL, options: .mappedIfSafe) else { return nil }
        return solidColor(
            in: data,
            displayUUID: displayUUID,
            desktopFillColor: desktopFillColor
        )
    }

    static func solidColor(
        in indexData: Data,
        displayUUID: String? = nil,
        desktopFillColor: WallpaperRGB? = nil
    ) -> WallpaperRGB? {
        guard let root = try? PropertyListSerialization.propertyList(
            from: indexData,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return nil
        }

        guard let configuration = selectedConfiguration(in: root, displayUUID: displayUUID) else {
            return nil
        }
        return solidColor(in: configuration, desktopFillColor: desktopFillColor)
    }

    static func previewImageURL(
        at indexURL: URL,
        displayUUID: String?,
        resourcesDirectory: URL = defaultAerialResourcesDirectory,
        neptuneResourcesDirectory: URL = defaultNeptuneResourcesDirectory,
        systemAppearance: PanelSemanticAppearance = .light
    ) -> URL? {
        guard let data = try? Data(contentsOf: indexURL, options: .mappedIfSafe) else { return nil }
        return previewImageURL(
            in: data,
            displayUUID: displayUUID,
            resourcesDirectory: resourcesDirectory,
            neptuneResourcesDirectory: neptuneResourcesDirectory,
            systemAppearance: systemAppearance
        )
    }

    static func previewImageURL(
        in indexData: Data,
        displayUUID: String? = nil,
        resourcesDirectory: URL = defaultAerialResourcesDirectory,
        neptuneResourcesDirectory: URL = defaultNeptuneResourcesDirectory,
        systemAppearance: PanelSemanticAppearance = .light
    ) -> URL? {
        guard let root = try? PropertyListSerialization.propertyList(
            from: indexData,
            options: [],
            format: nil
        ) as? [String: Any],
              let configuration = selectedConfiguration(in: root, displayUUID: displayUUID) else {
            return nil
        }
        let url: URL
        if let assetID = assetID(in: configuration) {
            url = resourcesDirectory.appending(path: "\(assetID).png")
        } else if let variant = neptuneVariant(
            in: configuration,
            systemAppearance: systemAppearance
        ) {
            let filename = variant == .dark ? "TahoeDark.heic" : "TahoeLight.heic"
            url = neptuneResourcesDirectory.appending(path: filename)
        } else {
            return nil
        }
        return FileManager.default.isReadableFile(atPath: url.path) ? url : nil
    }

    private static func selectedConfiguration(
        in root: [String: Any],
        displayUUID: String?
    ) -> [String: Any]? {
        if let displayUUID,
           let displays = root["Displays"] as? [String: Any],
           let display = displays[displayUUID] as? [String: Any] {
            return display
        }
        for key in ["AllSpacesAndDisplays", "SystemDefault"] {
            if let configuration = root[key] as? [String: Any] {
                return configuration
            }
        }
        return nil
    }

    private static func assetID(in configuration: [String: Any]) -> String? {
        guard let desktop = configuration["Desktop"] as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]] else {
            return nil
        }
        for choice in choices {
            guard let data = choice["Configuration"] as? Data,
                  let decoded = try? PropertyListSerialization.propertyList(
                      from: data,
                      options: [],
                      format: nil
                  ) as? [String: Any],
                  let assetID = decoded["assetID"] as? String else {
                continue
            }
            return assetID
        }
        return nil
    }

    private static func neptuneVariant(
        in configuration: [String: Any],
        systemAppearance: PanelSemanticAppearance
    ) -> PanelSemanticAppearance? {
        guard let desktop = configuration["Desktop"] as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]],
              choices.contains(where: {
                ($0["Provider"] as? String) == "com.apple.NeptuneOneExtension"
              }),
              let encodedOptions = content["EncodedOptionValues"] as? Data,
              let options = try? PropertyListSerialization.propertyList(
                from: encodedOptions,
                options: [],
                format: nil
              ) as? [String: Any],
              let styleID = neptuneStyleID(in: options)?.lowercased() else {
            return nil
        }
        if styleID.contains("dark") { return .dark }
        if styleID.contains("light") { return .light }
        return styleID == "dynamic" ? systemAppearance : nil
    }

    private static func neptuneStyleID(in options: [String: Any]) -> String? {
        if let flattened = options["style.picker._0.id"] as? String {
            return flattened
        }
        guard let values = options["values"] as? [String: Any],
              let style = values["style"] as? [String: Any],
              let picker = style["picker"] as? [String: Any],
              let zero = picker["_0"] as? [String: Any] else {
            return nil
        }
        return zero["id"] as? String
    }

    private static func solidColor(
        in configuration: [String: Any],
        desktopFillColor: WallpaperRGB?
    ) -> WallpaperRGB? {
        guard let desktop = configuration["Desktop"] as? [String: Any],
              let content = desktop["Content"] as? [String: Any],
              let choices = content["Choices"] as? [[String: Any]] else {
            return nil
        }
        if choices.contains(where: isSystemColorSelection) {
            return desktopFillColor
        }
        guard choices.contains(where: {
            ($0["Provider"] as? String) == "com.apple.wallpaper.choice.color"
        }) else {
            return nil
        }
        if let desktopFillColor {
            return desktopFillColor
        }
        guard let encodedOptions = content["EncodedOptionValues"] as? Data,
              let options = try? PropertyListSerialization.propertyList(
                from: encodedOptions,
                options: [],
                format: nil
              ) as? [String: Any],
              let values = options["values"] as? [String: Any],
              let customColor = values["customColor"] as? [String: Any],
              let colorContainer = customColor["color"] as? [String: Any],
              let zero = colorContainer["_0"] as? [String: Any],
              let color = zero["color"] as? [String: Any],
              let components = color["components"] as? [NSNumber],
              components.count >= 3 else {
            return nil
        }
        return WallpaperRGB(
            red: bounded(components[0].doubleValue),
            green: bounded(components[1].doubleValue),
            blue: bounded(components[2].doubleValue),
            alpha: components.count > 3 ? bounded(components[3].doubleValue) : 1
        )
    }

    private static func isSystemColorSelection(_ choice: [String: Any]) -> Bool {
        guard let data = choice["Configuration"] as? Data,
              let configuration = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
              ) as? [String: Any] else {
            return false
        }
        return (configuration["type"] as? String)?.lowercased() == "systemcolor"
    }

    private static func bounded(_ component: Double) -> Double {
        min(max(component, 0), 1)
    }
}

@MainActor
final class WallpaperStoreMonitor {
    private let source: DispatchSourceFileSystemObject
    private let onChange: @MainActor @Sendable () -> Void
    private var debounceTask: Task<Void, Never>?

    init?(directoryURL: URL, onChange: @escaping @MainActor @Sendable () -> Void) {
        let fileDescriptor = open(directoryURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return nil }

        self.onChange = onChange
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .delete, .rename, .extend, .attrib, .link, .revoke],
            queue: .main
        )
        source.setCancelHandler {
            close(fileDescriptor)
        }
        source.setEventHandler { [weak self] in
            self?.scheduleDebouncedChange()
        }
        source.resume()
    }

    deinit {
        debounceTask?.cancel()
        source.cancel()
    }

    private func scheduleDebouncedChange() {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }
            onChange()
        }
    }
}

enum WallpaperSamplingGeometry {
    static func imageRect(
        imageSize: CGSize,
        screenSize: CGSize,
        mode: WallpaperScalingMode
    ) -> CGRect? {
        guard imageSize.width > 0, imageSize.height > 0,
              screenSize.width > 0, screenSize.height > 0 else {
            return nil
        }

        let size: CGSize
        switch mode {
        case .stretch:
            size = screenSize
        case .center:
            size = imageSize
        case .fit:
            let scale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
            size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        case .fill:
            let scale = max(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
            size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        }

        return CGRect(
            x: (screenSize.width - size.width) / 2,
            y: (screenSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// Maps a bottom-left AppKit screen point to a top-left image pixel coordinate.
    static func imagePixel(
        forScreenPoint point: CGPoint,
        imageSize: CGSize,
        screenSize: CGSize,
        mode: WallpaperScalingMode
    ) -> CGPoint? {
        guard let imageRect = imageRect(imageSize: imageSize, screenSize: screenSize, mode: mode),
              imageRect.contains(point) else {
            return nil
        }
        let normalizedX = (point.x - imageRect.minX) / imageRect.width
        let normalizedYFromTop = (imageRect.maxY - point.y) / imageRect.height
        return CGPoint(
            x: min(max(normalizedX * imageSize.width, 0), imageSize.width.nextDown),
            y: min(max(normalizedYFromTop * imageSize.height, 0), imageSize.height.nextDown)
        )
    }
}

enum WallpaperAppearanceSelection {
    static let switchToDarkThreshold = 0.14
    static let switchToLightThreshold = 0.23

    static func contrastRatio(
        foregroundLuminance: Double,
        backgroundLuminance: Double
    ) -> Double {
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    static func preferredAppearance(forRelativeLuminance luminance: Double) -> PanelSemanticAppearance {
        let blackContrast = contrastRatio(foregroundLuminance: 0, backgroundLuminance: luminance)
        let whiteContrast = contrastRatio(foregroundLuminance: 1, backgroundLuminance: luminance)
        return blackContrast >= whiteContrast ? .light : .dark
    }

    static func appearance(
        forRelativeLuminance luminance: Double,
        previous: PanelSemanticAppearance?
    ) -> PanelSemanticAppearance {
        switch previous {
        case .dark:
            luminance >= switchToLightThreshold ? .light : .dark
        case .light:
            luminance <= switchToDarkThreshold ? .dark : .light
        case nil:
            preferredAppearance(forRelativeLuminance: luminance)
        }
    }

    static func appearance(
        forCandidateColors colors: [WallpaperRGB],
        previous: PanelSemanticAppearance?
    ) -> PanelSemanticAppearance? {
        guard !colors.isEmpty else { return nil }
        guard colors.count > 1 else {
            return appearance(
                forRelativeLuminance: colors[0].relativeLuminance,
                previous: previous
            )
        }
        let luminances = colors.map(\.relativeLuminance)
        let blackMinimum = luminances.map {
            contrastRatio(foregroundLuminance: 0, backgroundLuminance: $0)
        }.min() ?? 0
        let whiteMinimum = luminances.map {
            contrastRatio(foregroundLuminance: 1, backgroundLuminance: $0)
        }.min() ?? 0
        if abs(blackMinimum - whiteMinimum) <= 0.15, let previous {
            return previous
        }
        return blackMinimum >= whiteMinimum ? .light : .dark
    }
}

struct WallpaperPanelRegion: Sendable {
    let identifier: Int
    let frame: CGRect
    let previousAppearance: PanelSemanticAppearance?
}

struct WallpaperAppearanceRequest: Sendable {
    let source: WallpaperSource
    let screenSize: CGSize
    let scalingMode: WallpaperScalingMode
    let fillColor: WallpaperRGB?
    let panelRegions: [WallpaperPanelRegion]

    init(
        source: WallpaperSource,
        screenSize: CGSize,
        scalingMode: WallpaperScalingMode,
        fillColor: WallpaperRGB?,
        panelRegions: [WallpaperPanelRegion]
    ) {
        self.source = source
        self.screenSize = screenSize
        self.scalingMode = scalingMode
        self.fillColor = fillColor
        self.panelRegions = panelRegions
    }

    init(
        url: URL?,
        solidColor: WallpaperRGB? = nil,
        screenSize: CGSize,
        scalingMode: WallpaperScalingMode,
        fillColor: WallpaperRGB?,
        panelRegions: [WallpaperPanelRegion]
    ) {
        if let solidColor {
            source = .solid(solidColor)
        } else if let url {
            source = .staticImage(WallpaperSourceCandidate(url: url))
        } else {
            source = .unavailable
        }
        self.screenSize = screenSize
        self.scalingMode = scalingMode
        self.fillColor = fillColor
        self.panelRegions = panelRegions
    }
}

struct WallpaperPanelAppearance: Sendable, Equatable {
    let identifier: Int
    let backgroundColor: WallpaperRGB
    let appearance: PanelSemanticAppearance
}

actor WallpaperAppearanceSampler {
    private struct DecodedWallpaper: Sendable {
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let pixels: [UInt8]
        let displaySize: CGSize

        var size: CGSize { CGSize(width: width, height: height) }

        func color(at point: CGPoint, compositedOver fill: WallpaperRGB?) -> WallpaperRGB? {
            let x = min(max(Int(point.x), 0), width - 1)
            let y = min(max(Int(point.y), 0), height - 1)
            let offset = y * bytesPerRow + x * 4
            let alpha = Double(pixels[offset + 3]) / 255
            guard alpha > 0 else { return fill }

            // The bitmap is premultiplied RGBA, so restore its components before compositing.
            let red = min(Double(pixels[offset]) / 255 / alpha, 1)
            let green = min(Double(pixels[offset + 1]) / 255 / alpha, 1)
            let blue = min(Double(pixels[offset + 2]) / 255 / alpha, 1)
            guard alpha < 1 else { return WallpaperRGB(red: red, green: green, blue: blue) }
            guard let fill else { return nil }
            return WallpaperRGB(
                red: red * alpha + fill.red * (1 - alpha),
                green: green * alpha + fill.green * (1 - alpha),
                blue: blue * alpha + fill.blue * (1 - alpha)
            )
        }
    }

    private static let maximumCachedAssets = 6
    private var cachedWallpapers: [WallpaperSourceCandidate: [DecodedWallpaper]] = [:]
    private var cacheOrder: [WallpaperSourceCandidate] = []

    func invalidateCache() {
        cachedWallpapers.removeAll(keepingCapacity: true)
        cacheOrder.removeAll(keepingCapacity: true)
    }

    func appearances(for request: WallpaperAppearanceRequest) async -> [WallpaperPanelAppearance] {
        guard !Task.isCancelled else { return [] }
        let solidColor: WallpaperRGB?
        var images: [DecodedWallpaper] = []
        switch request.source {
        case let .solid(color):
            solidColor = color
        case .staticImage, .phaseUnknown:
            solidColor = nil
            for candidate in request.source.candidates {
                guard !Task.isCancelled else { return [] }
                if let decoded = try? await decodedWallpapers(for: candidate) {
                    images.append(contentsOf: decoded)
                }
            }
        case .unavailable:
            return []
        }
        guard !Task.isCancelled, !images.isEmpty || solidColor != nil else { return [] }

        return request.panelRegions.compactMap { region in
            guard !Task.isCancelled else { return nil }
            let colors: [WallpaperRGB]
            if let solidColor {
                colors = [solidColor]
            } else {
                colors = images.compactMap { image in
                    averageColor(
                    in: region.frame,
                    image: image,
                    request: request
                )
                }
            }
            guard let appearance = WallpaperAppearanceSelection.appearance(
                forCandidateColors: colors,
                previous: region.previousAppearance
            ), !colors.isEmpty else {
                return nil
            }
            let count = Double(colors.count)
            let backgroundColor = WallpaperRGB(
                red: colors.reduce(0) { $0 + $1.red } / count,
                green: colors.reduce(0) { $0 + $1.green } / count,
                blue: colors.reduce(0) { $0 + $1.blue } / count
            )
            return WallpaperPanelAppearance(
                identifier: region.identifier,
                backgroundColor: backgroundColor,
                appearance: appearance
            )
        }
    }

    private func decodedWallpapers(
        for candidate: WallpaperSourceCandidate
    ) async throws -> [DecodedWallpaper] {
        if let cached = cachedWallpapers[candidate] {
            touch(candidate)
            return cached
        }
        let decoded = try await Self.decode(candidate)
        guard !Task.isCancelled else { throw CancellationError() }
        cachedWallpapers[candidate] = decoded
        touch(candidate)
        while cacheOrder.count > Self.maximumCachedAssets {
            cachedWallpapers.removeValue(forKey: cacheOrder.removeFirst())
        }
        return decoded
    }

    private func touch(_ candidate: WallpaperSourceCandidate) {
        cacheOrder.removeAll { $0 == candidate }
        cacheOrder.append(candidate)
    }

    private nonisolated static func decode(
        _ candidate: WallpaperSourceCandidate
    ) async throws -> [DecodedWallpaper] {
        switch candidate.kind {
        case .image:
            return [try await Task.detached {
                try decodeImage(at: candidate.url)
            }.value]
        case .video:
            let asset = AVURLAsset(url: candidate.url)
            let duration = try await asset.load(.duration)
            let seconds = max(CMTimeGetSeconds(duration), 0)
            let fractions = seconds > 0 ? [0.1, 0.3, 0.6, 0.9] : [0]
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 384, height: 384)
            var decoded: [DecodedWallpaper] = []
            decoded.reserveCapacity(fractions.count)
            for fraction in fractions.prefix(5) {
                guard !Task.isCancelled else { throw CancellationError() }
                let time = CMTime(seconds: seconds * fraction, preferredTimescale: 600)
                let image = try await generator.image(at: time).image
                decoded.append(try await Task.detached {
                    try decodedWallpaper(from: image, displaySize: CGSize(
                        width: image.width,
                        height: image.height
                    ))
                }.value)
            }
            return decoded
        }
    }

    private nonisolated static func decodeImage(at url: URL) throws -> DecodedWallpaper {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let sourceWidth = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let sourceHeight = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 384,
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let sourceMaximumDimension = max(sourceWidth.doubleValue, sourceHeight.doubleValue)
        let decodedMaximumDimension = max(Double(thumbnail.width), Double(thumbnail.height))
        let displayScale = sourceMaximumDimension / decodedMaximumDimension
        return try decodedWallpaper(
            from: thumbnail,
            displaySize: CGSize(
                width: Double(thumbnail.width) * displayScale,
                height: Double(thumbnail.height) * displayScale
            )
        )
    }

    private nonisolated static func decodedWallpaper(
        from cgImage: CGImage,
        displaySize: CGSize
    ) throws -> DecodedWallpaper {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else {
                return false
            }
            // CGBitmapContext row zero receives the CGImage's visual top row.
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard rendered else { throw CocoaError(.fileReadCorruptFile) }

        let decoded = DecodedWallpaper(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            pixels: pixels,
            displaySize: displaySize
        )
        return decoded
    }

    /// Reduces the wallpaper covered by a panel to one area-weighted sRGB color.
    ///
    /// Decoded pixels are treated as rectangular color blocks in screen space, so this is
    /// equivalent to resampling the covered desktop region to a single pixel without relying
    /// on a sparse sampling grid.
    private func averageColor(
        in panelFrame: CGRect,
        image: DecodedWallpaper,
        request: WallpaperAppearanceRequest
    ) -> WallpaperRGB? {
        let screenBounds = CGRect(origin: .zero, size: request.screenSize)
        let frame = panelFrame.intersection(screenBounds)
        guard !frame.isNull, frame.width > 0, frame.height > 0 else { return nil }

        let panelArea = Double(frame.width * frame.height)
        var sampledArea = request.fillColor == nil ? 0 : panelArea
        var red = (request.fillColor?.red ?? 0) * panelArea
        var green = (request.fillColor?.green ?? 0) * panelArea
        var blue = (request.fillColor?.blue ?? 0) * panelArea

        guard let imageRect = WallpaperSamplingGeometry.imageRect(
            imageSize: image.displaySize,
            screenSize: request.screenSize,
            mode: request.scalingMode
        ) else {
            return request.fillColor
        }
        let coveredFrame = frame.intersection(imageRect)
        guard !coveredFrame.isNull, coveredFrame.width > 0, coveredFrame.height > 0 else {
            return request.fillColor
        }

        let pixelWidth = imageRect.width / CGFloat(image.width)
        let pixelHeight = imageRect.height / CGFloat(image.height)
        let firstColumn = max(Int(floor((coveredFrame.minX - imageRect.minX) / pixelWidth)), 0)
        let lastColumn = min(Int(ceil((coveredFrame.maxX - imageRect.minX) / pixelWidth)), image.width)
        let firstRow = max(Int(floor((imageRect.maxY - coveredFrame.maxY) / pixelHeight)), 0)
        let lastRow = min(Int(ceil((imageRect.maxY - coveredFrame.minY) / pixelHeight)), image.height)

        for row in firstRow..<lastRow {
            guard !Task.isCancelled else { return nil }
            let pixelMaxY = imageRect.maxY - CGFloat(row) * pixelHeight
            let pixelMinY = pixelMaxY - pixelHeight
            let overlapHeight = max(
                min(pixelMaxY, coveredFrame.maxY) - max(pixelMinY, coveredFrame.minY),
                0
            )
            guard overlapHeight > 0 else { continue }

            for column in firstColumn..<lastColumn {
                let pixelMinX = imageRect.minX + CGFloat(column) * pixelWidth
                let pixelMaxX = pixelMinX + pixelWidth
                let overlapWidth = max(
                    min(pixelMaxX, coveredFrame.maxX) - max(pixelMinX, coveredFrame.minX),
                    0
                )
                let area = Double(overlapWidth * overlapHeight)
                guard area > 0,
                      let color = image.color(
                        at: CGPoint(x: column, y: row),
                        compositedOver: request.fillColor
                      ) else {
                    continue
                }

                if let fill = request.fillColor {
                    red += (color.red - fill.red) * area
                    green += (color.green - fill.green) * area
                    blue += (color.blue - fill.blue) * area
                } else {
                    sampledArea += area
                    red += color.red * area
                    green += color.green * area
                    blue += color.blue * area
                }
            }
        }
        guard sampledArea > 0 else { return nil }
        return WallpaperRGB(
            red: red / sampledArea,
            green: green / sampledArea,
            blue: blue / sampledArea
        )
    }
}
