import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import CodexPulse

@Test func wallpaperGeometryMapsFitAndFill() throws {
    let imageSize = CGSize(width: 400, height: 200)
    let screenSize = CGSize(width: 200, height: 200)

    let fit = try #require(WallpaperSamplingGeometry.imageRect(
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .fit
    ))
    #expect(fit == CGRect(x: 0, y: 50, width: 200, height: 100))
    #expect(WallpaperSamplingGeometry.imagePixel(
        forScreenPoint: CGPoint(x: 100, y: 25),
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .fit
    ) == nil)

    let fill = try #require(WallpaperSamplingGeometry.imageRect(
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .fill
    ))
    #expect(fill == CGRect(x: -100, y: 0, width: 400, height: 200))
    #expect(WallpaperSamplingGeometry.imagePixel(
        forScreenPoint: CGPoint(x: 0, y: 100),
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .fill
    ) == CGPoint(x: 100, y: 100))
}

@Test func wallpaperGeometryMapsStretchAndAppKitYAxis() throws {
    let imageSize = CGSize(width: 400, height: 100)
    let screenSize = CGSize(width: 200, height: 200)
    let rect = try #require(WallpaperSamplingGeometry.imageRect(
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .stretch
    ))
    #expect(rect == CGRect(origin: .zero, size: screenSize))

    let nearAppKitTop = try #require(WallpaperSamplingGeometry.imagePixel(
        forScreenPoint: CGPoint(x: 50, y: 180),
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .stretch
    ))
    let nearAppKitBottom = try #require(WallpaperSamplingGeometry.imagePixel(
        forScreenPoint: CGPoint(x: 50, y: 20),
        imageSize: imageSize,
        screenSize: screenSize,
        mode: .stretch
    ))
    #expect(nearAppKitTop == CGPoint(x: 100, y: 10))
    #expect(nearAppKitBottom == CGPoint(x: 100, y: 90))
}

@Test func desktopWallpaperOptionsSelectExpectedScalingModes() {
    #expect(WallpaperScalingMode.desktopImageMode(
        scaling: .scaleProportionallyUpOrDown,
        allowClipping: false
    ) == .fit)
    #expect(WallpaperScalingMode.desktopImageMode(
        scaling: .scaleProportionallyUpOrDown,
        allowClipping: true
    ) == .fill)
    #expect(WallpaperScalingMode.desktopImageMode(
        scaling: .scaleAxesIndependently,
        allowClipping: true
    ) == .stretch)
    #expect(WallpaperScalingMode.desktopImageMode(
        scaling: .scaleNone,
        allowClipping: false
    ) == .center)
}

@Test func wallpaperAppearanceUsesRelativeLuminance() {
    #expect(WallpaperRGB(red: 1, green: 1, blue: 1).relativeLuminance == 1)
    #expect(WallpaperRGB(red: 0, green: 0, blue: 0).relativeLuminance == 0)
    #expect(WallpaperAppearanceSelection.appearance(
        forRelativeLuminance: 0.1,
        previous: nil
    ) == .dark)
    #expect(WallpaperAppearanceSelection.appearance(
        forRelativeLuminance: 0.9,
        previous: nil
    ) == .light)
}

@Test func wallpaperAppearanceHysteresisRetainsBorderlineChoice() {
    #expect(WallpaperAppearanceSelection.appearance(
        forRelativeLuminance: 0.18,
        previous: .light
    ) == .light)
    #expect(WallpaperAppearanceSelection.appearance(
        forRelativeLuminance: 0.18,
        previous: .dark
    ) == .dark)
    #expect(WallpaperAppearanceSelection.appearance(
        forRelativeLuminance: 0.13,
        previous: .light
    ) == .dark)
    #expect(WallpaperAppearanceSelection.appearance(
        forRelativeLuminance: 0.24,
        previous: .dark
    ) == .light)
}

@Test func wallpaperRepresentativeLuminanceUsesMedian() {
    #expect(WallpaperAppearanceSelection.representativeLuminance([0.1, 0.2, 0.9]) == 0.2)
    #expect(WallpaperAppearanceSelection.representativeLuminance([0.1, 0.2, 0.8, 0.9]) == 0.5)
}

@Test func wallpaperRefreshTrackerDetectsSignatureGeometryAndRemovalChanges() {
    let url = URL(fileURLWithPath: "/tmp/wallpaper.png")
    let date = Date(timeIntervalSince1970: 100)
    func state(
        url: URL = url,
        modificationDate: Date? = date,
        fileSize: Int? = 1_024,
        scaling: UInt = NSImageScaling.scaleProportionallyUpOrDown.rawValue,
        clipping: Bool = false,
        fillColor: WallpaperRGB? = nil,
        screenIdentifier: UInt32? = 1,
        panelX: CGFloat = 0
    ) -> WallpaperRefreshState {
        WallpaperRefreshState(
            signature: WallpaperStateSignature(
                image: .init(url: url, modificationDate: modificationDate, fileSize: fileSize),
                imageScalingRawValue: scaling,
                allowClipping: clipping,
                fillColor: fillColor
            ),
            screenIdentifier: screenIdentifier,
            screenSize: CGSize(width: 1_920, height: 1_080),
            panelRegions: [.init(identifier: 0, frame: CGRect(x: panelX, y: 0, width: 300, height: 56))]
        )
    }

    var tracker = WallpaperRefreshTracker()
    #expect(tracker.transition(to: state()) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: state()) == .unchanged)
    #expect(tracker.transition(to: state(panelX: 20)) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: state(scaling: NSImageScaling.scaleAxesIndependently.rawValue, panelX: 20)) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: state(clipping: true, panelX: 20)) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: state(fillColor: WallpaperRGB(red: 1, green: 1, blue: 1), panelX: 20)) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: state(screenIdentifier: 2, panelX: 20)) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: state(fileSize: 2_048, panelX: 20)) == .resample(invalidateDecodedWallpaper: true))
    #expect(tracker.transition(to: state(
        url: URL(fileURLWithPath: "/tmp/other-wallpaper.png"),
        fileSize: 2_048,
        panelX: 20
    )) == .resample(invalidateDecodedWallpaper: true))
    #expect(tracker.transition(to: state(
        url: URL(fileURLWithPath: "/tmp/other-wallpaper.png"),
        modificationDate: date.addingTimeInterval(1),
        fileSize: 2_048,
        panelX: 20
    )) == .resample(invalidateDecodedWallpaper: true))
    #expect(tracker.transition(to: nil) == .removed)
    #expect(tracker.transition(to: nil) == .unchanged)
}

@Test func wallpaperSamplerPreservesDecodedTopAndBottomOrientation() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseWallpaperTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let imageURL = temporaryDirectory.appending(path: "top-light-bottom-dark.png")

    let width = 100
    let height = 100
    let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height / 2))
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: height / 2, width: width, height: height / 2))
    let image = try #require(context.makeImage())
    let destination = try #require(CGImageDestinationCreateWithURL(
        imageURL as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ))
    CGImageDestinationAddImage(destination, image, nil)
    #expect(CGImageDestinationFinalize(destination))

    let appearances = await WallpaperAppearanceSampler().appearances(for: WallpaperAppearanceRequest(
        url: imageURL,
        screenSize: CGSize(width: width, height: height),
        scalingMode: .stretch,
        fillColor: nil,
        panelRegions: [
            WallpaperPanelRegion(
                identifier: 0,
                frame: CGRect(x: 0, y: 50, width: width, height: 50),
                previousAppearance: nil
            ),
            WallpaperPanelRegion(
                identifier: 1,
                frame: CGRect(x: 0, y: 0, width: width, height: 50),
                previousAppearance: nil
            )
        ]
    ))

    #expect(appearances.first { $0.identifier == 0 }?.appearance == .light)
    #expect(appearances.first { $0.identifier == 1 }?.appearance == .dark)
}
