import AppKit
import CoreGraphics
import ImageIO

enum PanelSemanticAppearance: Sendable, Equatable {
    case light
    case dark
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
    static let initialThreshold = 0.18
    static let switchToDarkThreshold = 0.14
    static let switchToLightThreshold = 0.23

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
            luminance < initialThreshold ? .dark : .light
        }
    }

    static func representativeLuminance(_ samples: [Double]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}

struct WallpaperPanelRegion: Sendable {
    let identifier: Int
    let frame: CGRect
    let previousAppearance: PanelSemanticAppearance?
}

struct WallpaperAppearanceRequest: Sendable {
    let url: URL
    let screenSize: CGSize
    let scalingMode: WallpaperScalingMode
    let fillColor: WallpaperRGB?
    let panelRegions: [WallpaperPanelRegion]
}

struct WallpaperPanelAppearance: Sendable {
    let identifier: Int
    let appearance: PanelSemanticAppearance
}

actor WallpaperAppearanceSampler {
    private struct CacheKey: Equatable {
        let url: URL
        let modificationDate: Date?
        let fileSize: Int?
    }

    private struct DecodedWallpaper {
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

    private var cachedWallpaper: (key: CacheKey, image: DecodedWallpaper)?

    func invalidateCache() {
        cachedWallpaper = nil
    }

    func appearances(for request: WallpaperAppearanceRequest) -> [WallpaperPanelAppearance] {
        guard !Task.isCancelled else { return [] }
        let image: DecodedWallpaper
        do {
            image = try decodedWallpaper(at: request.url)
        } catch {
            return []
        }
        guard !Task.isCancelled else { return [] }

        return request.panelRegions.compactMap { region in
            guard !Task.isCancelled,
                  let luminance = representativeLuminance(
                    in: region.frame,
                    image: image,
                    request: request
                  ) else {
                return nil
            }
            return WallpaperPanelAppearance(
                identifier: region.identifier,
                appearance: WallpaperAppearanceSelection.appearance(
                    forRelativeLuminance: luminance,
                    previous: region.previousAppearance
                )
            )
        }
    }

    private func decodedWallpaper(at url: URL) throws -> DecodedWallpaper {
        let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let key = CacheKey(url: url, modificationDate: values.contentModificationDate, fileSize: values.fileSize)
        if let cachedWallpaper, cachedWallpaper.key == key {
            return cachedWallpaper.image
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let sourceWidth = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let sourceHeight = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1_024,
                kCGImageSourceShouldCache: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }
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

        let sourceMaximumDimension = max(sourceWidth.doubleValue, sourceHeight.doubleValue)
        let decodedMaximumDimension = max(Double(width), Double(height))
        let displayScale = sourceMaximumDimension / decodedMaximumDimension
        let decoded = DecodedWallpaper(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            pixels: pixels,
            displaySize: CGSize(
                width: Double(width) * displayScale,
                height: Double(height) * displayScale
            )
        )
        cachedWallpaper = (key, decoded)
        return decoded
    }

    private func representativeLuminance(
        in panelFrame: CGRect,
        image: DecodedWallpaper,
        request: WallpaperAppearanceRequest
    ) -> Double? {
        let screenBounds = CGRect(origin: .zero, size: request.screenSize)
        let frame = panelFrame.intersection(screenBounds)
        guard !frame.isNull, frame.width > 0, frame.height > 0 else { return nil }

        let columns = 9
        let rows = 7
        var samples: [Double] = []
        samples.reserveCapacity(columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                let point = CGPoint(
                    x: frame.minX + (CGFloat(column) + 0.5) * frame.width / CGFloat(columns),
                    y: frame.minY + (CGFloat(row) + 0.5) * frame.height / CGFloat(rows)
                )
                let color: WallpaperRGB?
                if let pixel = WallpaperSamplingGeometry.imagePixel(
                    forScreenPoint: point,
                    imageSize: image.displaySize,
                    screenSize: request.screenSize,
                    mode: request.scalingMode
                ) {
                    let decodedPixel = CGPoint(
                        x: pixel.x * image.size.width / image.displaySize.width,
                        y: pixel.y * image.size.height / image.displaySize.height
                    )
                    color = image.color(at: decodedPixel, compositedOver: request.fillColor)
                } else {
                    color = request.fillColor
                }
                if let color { samples.append(color.relativeLuminance) }
            }
        }
        return WallpaperAppearanceSelection.representativeLuminance(samples)
    }
}
