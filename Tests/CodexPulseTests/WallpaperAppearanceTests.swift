import AppKit
import ImageIO
import Testing
import UniformTypeIdentifiers

private func wallpaperStoreData(
    rootKey: String,
    provider: String = "com.apple.wallpaper.choice.color",
    components: [Double]
) throws -> Data {
    let encodedOptions = try PropertyListSerialization.data(
        fromPropertyList: [
            "values": [
                "customColor": [
                    "color": [
                        "_0": [
                            "color": [
                                "components": components,
                            ],
                        ],
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
    return try PropertyListSerialization.data(
        fromPropertyList: [
            rootKey: [
                "Desktop": [
                    "Content": [
                        "Choices": [["Provider": provider]],
                        "EncodedOptionValues": encodedOptions,
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
}
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
    #expect(WallpaperAppearanceSelection.contrastRatio(
        foregroundLuminance: 0,
        backgroundLuminance: 1
    ) == 21)
    #expect(WallpaperAppearanceSelection.contrastRatio(
        foregroundLuminance: 1,
        backgroundLuminance: 0
    ) == 21)
    #expect(WallpaperAppearanceSelection.preferredAppearance(
        forRelativeLuminance: 0.1
    ) == .dark)
    #expect(WallpaperAppearanceSelection.preferredAppearance(
        forRelativeLuminance: 0.9
    ) == .light)
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

@Test func wallpaperRefreshTrackerRecognizesSolidColorsAndExternalStoreChanges() {
    func state(color: WallpaperRGB) -> WallpaperRefreshState {
        WallpaperRefreshState(
            signature: WallpaperStateSignature(
                image: nil,
                solidColor: color,
                imageScalingRawValue: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                allowClipping: false,
                fillColor: nil
            ),
            screenIdentifier: 1,
            screenSize: CGSize(width: 1_920, height: 1_080),
            panelRegions: [.init(identifier: 0, frame: CGRect(x: 0, y: 0, width: 300, height: 56))]
        )
    }

    let white = state(color: WallpaperRGB(red: 1, green: 1, blue: 1))
    let black = state(color: WallpaperRGB(red: 0, green: 0, blue: 0))
    var tracker = WallpaperRefreshTracker()
    #expect(tracker.transition(to: white) == .resample(invalidateDecodedWallpaper: false))
    #expect(tracker.transition(to: white) == .unchanged)
    #expect(tracker.transition(to: black) == .resample(invalidateDecodedWallpaper: false))
    #expect(
        tracker.transition(to: black, reason: .wallpaperStoreChanged)
            == .resample(invalidateDecodedWallpaper: true)
    )
}

private func wallpaperSystemColorStoreData(name: String) throws -> Data {
    let choiceConfiguration = try PropertyListSerialization.data(
        fromPropertyList: [
            "type": "systemColor",
            "systemColor": [name: [:] as [String: Any]],
        ],
        format: .binary,
        options: 0
    )
    return try PropertyListSerialization.data(
        fromPropertyList: [
            "AllSpacesAndDisplays": [
                "Desktop": [
                    "Content": [
                        "Choices": [[
                            "Provider": "com.apple.wallpaper.choice.aerials",
                            "Configuration": choiceConfiguration,
                        ]],
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
}

private func wallpaperDynamicStoreData(assetID: String) throws -> Data {
    let choiceConfiguration = try PropertyListSerialization.data(
        fromPropertyList: ["assetID": assetID],
        format: .binary,
        options: 0
    )
    return try PropertyListSerialization.data(
        fromPropertyList: [
            "AllSpacesAndDisplays": [
                "Desktop": [
                    "Content": [
                        "Choices": [[
                            "Provider": "com.apple.wallpaper.choice.aerials",
                            "Configuration": choiceConfiguration,
                        ]],
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
}

private func wallpaperNeptuneStoreData(styleID: String) throws -> Data {
    let choiceConfiguration = try PropertyListSerialization.data(
        fromPropertyList: [:],
        format: .binary,
        options: 0
    )
    let encodedOptions = try PropertyListSerialization.data(
        fromPropertyList: [
            "values": [
                "style": [
                    "picker": [
                        "_0": ["id": styleID],
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
    return try PropertyListSerialization.data(
        fromPropertyList: [
            "AllSpacesAndDisplays": [
                "Desktop": [
                    "Content": [
                        "Choices": [[
                            "Provider": "com.apple.NeptuneOneExtension",
                            "Configuration": choiceConfiguration,
                        ]],
                        "EncodedOptionValues": encodedOptions,
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
}

private func wallpaperSourceStoreData(
    provider: String,
    files: [URL] = [],
    configuration: [String: Any] = [:]
) throws -> Data {
    let choiceConfiguration = try PropertyListSerialization.data(
        fromPropertyList: configuration,
        format: .binary,
        options: 0
    )
    return try PropertyListSerialization.data(
        fromPropertyList: [
            "AllSpacesAndDisplays": [
                "Desktop": [
                    "Content": [
                        "Choices": [[
                            "Provider": provider,
                            "Files": files.map(\.absoluteString),
                            "Configuration": choiceConfiguration,
                        ]],
                    ],
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
}

@Test func wallpaperStoreParsesAllDisplaysAndSystemDefaultSolidColors() throws {
    let whiteData = try wallpaperStoreData(
        rootKey: "AllSpacesAndDisplays",
        components: [1, 1, 1, 1]
    )
    #expect(WallpaperStoreConfiguration.solidColor(in: whiteData) == WallpaperRGB(
        red: 1,
        green: 1,
        blue: 1,
        alpha: 1
    ))

    let darkData = try wallpaperStoreData(
        rootKey: "SystemDefault",
        components: [0.1, 0.2, 0.3, 0.8]
    )
    #expect(WallpaperStoreConfiguration.solidColor(in: darkData) == WallpaperRGB(
        red: 0.1,
        green: 0.2,
        blue: 0.3,
        alpha: 0.8
    ))
}

@Test func wallpaperStoreIgnoresCustomColorForImageProvider() throws {
    let data = try wallpaperStoreData(
        rootKey: "AllSpacesAndDisplays",
        provider: "com.apple.wallpaper.choice.image",
        components: [1, 1, 1, 1]
    )
    #expect(WallpaperStoreConfiguration.solidColor(in: data) == nil)
}

@Test func wallpaperStoreParsesColorsSystemColorConfigurationRegardlessOfProviderName() throws {
    let blackData = try wallpaperSystemColorStoreData(name: "black")
    #expect(WallpaperStoreConfiguration.solidColor(in: blackData) == WallpaperRGB(
        red: 0,
        green: 0,
        blue: 0,
        alpha: 1
    ))

    let whiteData = try wallpaperSystemColorStoreData(name: "white")
    #expect(WallpaperStoreConfiguration.solidColor(in: whiteData) == WallpaperRGB(
        red: 1,
        green: 1,
        blue: 1,
        alpha: 1
    ))
}

@Test func wallpaperStoreResolvesDynamicAssetPreviewWithoutUsingNetwork() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseWallpaperPreviewTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let assetID = "17647EAB-8357-48B0-BCD6-B892194267C5"
    let previewURL = temporaryDirectory.appending(path: "\(assetID).png")
    try Data("preview".utf8).write(to: previewURL)
    let storeData = try wallpaperDynamicStoreData(assetID: assetID)

    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: storeData,
        resourcesDirectory: temporaryDirectory
    ) == previewURL)
    try FileManager.default.removeItem(at: previewURL)
    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: storeData,
        resourcesDirectory: temporaryDirectory
    ) == nil)
}

@Test func wallpaperStoreResolvesNeptuneVariantFromStyleAndSystemAppearance() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseNeptuneWallpaperTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let lightURL = temporaryDirectory.appending(path: "TahoeLight.heic")
    let darkURL = temporaryDirectory.appending(path: "TahoeDark.heic")
    try Data("light".utf8).write(to: lightURL)
    try Data("dark".utf8).write(to: darkURL)

    let dynamicData = try wallpaperNeptuneStoreData(styleID: "dynamic")
    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: dynamicData,
        neptuneResourcesDirectory: temporaryDirectory,
        systemAppearance: .light
    ) == lightURL)
    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: dynamicData,
        neptuneResourcesDirectory: temporaryDirectory,
        systemAppearance: .dark
    ) == darkURL)

    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: try wallpaperNeptuneStoreData(styleID: "light"),
        neptuneResourcesDirectory: temporaryDirectory,
        systemAppearance: .dark
    ) == lightURL)
    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: try wallpaperNeptuneStoreData(styleID: "dark"),
        neptuneResourcesDirectory: temporaryDirectory,
        systemAppearance: .light
    ) == darkURL)

    try FileManager.default.removeItem(at: darkURL)
    #expect(WallpaperStoreConfiguration.previewImageURL(
        in: dynamicData,
        neptuneResourcesDirectory: temporaryDirectory,
        systemAppearance: .dark
    ) == nil)
}

@Test func wallpaperSourceResolverClassifiesSolidPicturesPhotosAndMovies() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseWallpaperSourceTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let pictureURL = temporaryDirectory.appending(path: "picture.jpg")
    let movieURL = temporaryDirectory.appending(path: "movie.mov")
    let workspaceURL = temporaryDirectory.appending(path: "workspace.jpg")
    for url in [pictureURL, movieURL, workspaceURL] {
        try Data("fixture".utf8).write(to: url)
    }
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )

    let solidData = try wallpaperStoreData(
        rootKey: "AllSpacesAndDisplays",
        components: [0.2, 0.3, 0.4, 1]
    )
    #expect(resolver.resolve(
        indexData: solidData,
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .solid(WallpaperRGB(red: 0.2, green: 0.3, blue: 0.4)))

    let picture = resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image",
            files: [pictureURL]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    )
    #expect(picture == .staticImage(WallpaperSourceCandidate(url: pictureURL, kind: .image)))

    let photoFallback = resolver.resolve(
        indexData: try wallpaperSourceStoreData(provider: "com.apple.wallpaper.choice.photos"),
        displayUUID: nil,
        workspaceURL: workspaceURL
    )
    #expect(photoFallback == .staticImage(WallpaperSourceCandidate(url: workspaceURL, kind: .image)))

    let movie = resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.movie",
            files: [movieURL]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    )
    #expect(movie == .staticImage(WallpaperSourceCandidate(url: movieURL, kind: .video)))
}

@Test func wallpaperSourceResolverFindsAerialCandidatesAndRejectsStaleProceduralFallback() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseAerialSourceTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let assetID = "AERIAL-ASSET"
    let previewURL = temporaryDirectory.appending(path: "\(assetID).png")
    let movieURL = temporaryDirectory.appending(path: "\(assetID).mov")
    let staleURL = temporaryDirectory.appending(path: "DefaultDesktop.heic")
    for url in [previewURL, movieURL, staleURL] {
        try Data("fixture".utf8).write(to: url)
    }
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: [temporaryDirectory]
    )
    let aerial = resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.aerials",
            configuration: ["assetID": assetID]
        ),
        displayUUID: nil,
        workspaceURL: staleURL
    )
    #expect(aerial == .phaseUnknown([
        WallpaperSourceCandidate(url: movieURL, kind: .video),
        WallpaperSourceCandidate(url: previewURL, kind: .image),
    ]))

    let procedural = resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.example.ProceduralWallpaperExtension"
        ),
        displayUUID: nil,
        workspaceURL: staleURL
    )
    #expect(procedural == .unavailable)
}

@Test func wallpaperSourceResolverUsesAllNeptuneDynamicPhasesAndMaximinContrast() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseNeptuneSourceTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let lightURL = temporaryDirectory.appending(path: "TahoeLight.heic")
    let darkURL = temporaryDirectory.appending(path: "TahoeDark.heic")
    try Data("light".utf8).write(to: lightURL)
    try Data("dark".utf8).write(to: darkURL)
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )

    let source = resolver.resolve(
        indexData: try wallpaperNeptuneStoreData(styleID: "dynamic"),
        displayUUID: nil,
        workspaceURL: nil
    )
    #expect(source == .phaseUnknown([
        WallpaperSourceCandidate(url: darkURL),
        WallpaperSourceCandidate(url: lightURL),
    ]))
    #expect(WallpaperAppearanceSelection.appearance(
        forCandidateColors: [
            WallpaperRGB(red: 0, green: 0, blue: 0),
            WallpaperRGB(red: 1, green: 1, blue: 1),
        ],
        previous: .dark
    ) == .dark)
    #expect(WallpaperAppearanceSelection.appearance(
        forCandidateColors: [
            WallpaperRGB(red: 0, green: 0, blue: 0),
            WallpaperRGB(red: 1, green: 1, blue: 1),
        ],
        previous: .light
    ) == .light)
}

@Test func wallpaperStoreMonitorDeliversChangesOnMainActor() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseWallpaperMonitorTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    try await confirmation("Wallpaper Store change delivered") { changeDelivered in
        let monitor = await MainActor.run {
            WallpaperStoreMonitor(directoryURL: temporaryDirectory) {
                MainActor.assertIsolated()
                changeDelivered()
            }
        }
        #expect(monitor != nil)

        try Data("changed".utf8).write(
            to: temporaryDirectory.appending(path: "Index.plist")
        )
        try await Task.sleep(for: .seconds(1))
        withExtendedLifetime(monitor) {}
    }
}

@Test func wallpaperSamplerFallsBackToSolidColorWithoutImage() async throws {
    let color = WallpaperRGB(red: 1, green: 1, blue: 1)
    let appearances = await WallpaperAppearanceSampler().appearances(
        for: WallpaperAppearanceRequest(
            url: nil,
            solidColor: color,
            screenSize: CGSize(width: 1_920, height: 1_080),
            scalingMode: .fill,
            fillColor: nil,
            panelRegions: [
                WallpaperPanelRegion(
                    identifier: 0,
                    frame: CGRect(x: 0, y: 0, width: 300, height: 56),
                    previousAppearance: .dark
                ),
            ]
        )
    )
    let result = try #require(appearances.first)
    #expect(result.backgroundColor == color)
    #expect(result.appearance == .light)
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
    #expect(appearances.first { $0.identifier == 0 }?.backgroundColor == WallpaperRGB(
        red: 1,
        green: 1,
        blue: 1
    ))
    #expect(appearances.first { $0.identifier == 1 }?.backgroundColor == WallpaperRGB(
        red: 0,
        green: 0,
        blue: 0
    ))
}

@Test func wallpaperSamplerComputesAreaWeightedAverageColor() async throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseWallpaperAverageTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let imageURL = temporaryDirectory.appending(path: "red-blue.png")

    let width = 100
    let height = 20
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
    context.setFillColor(NSColor.red.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 25, height: height))
    context.setFillColor(NSColor.blue.cgColor)
    context.fill(CGRect(x: 25, y: 0, width: 75, height: height))
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
                frame: CGRect(x: 0, y: 0, width: width, height: height),
                previousAppearance: nil
            ),
        ]
    ))
    let average = try #require(appearances.first?.backgroundColor)
    #expect(abs(average.red - 0.25) < 0.01)
    #expect(abs(average.green) < 0.01)
    #expect(abs(average.blue - 0.75) < 0.01)

    let solidColor = WallpaperRGB(red: 1, green: 1, blue: 1)
    let solidAppearances = await WallpaperAppearanceSampler().appearances(
        for: WallpaperAppearanceRequest(
            url: imageURL,
            solidColor: solidColor,
            screenSize: CGSize(width: width, height: height),
            scalingMode: .stretch,
            fillColor: nil,
            panelRegions: [
                WallpaperPanelRegion(
                    identifier: 0,
                    frame: CGRect(x: 0, y: 0, width: width, height: height),
                    previousAppearance: .dark
                ),
            ]
        )
    )
    #expect(solidAppearances.first?.backgroundColor == solidColor)
    #expect(solidAppearances.first?.appearance == .light)

    let fitAppearances = await WallpaperAppearanceSampler().appearances(for: WallpaperAppearanceRequest(
        url: imageURL,
        screenSize: CGSize(width: width, height: height * 2),
        scalingMode: .fit,
        fillColor: WallpaperRGB(red: 1, green: 1, blue: 1),
        panelRegions: [
            WallpaperPanelRegion(
                identifier: 0,
                frame: CGRect(x: 0, y: 0, width: width, height: height * 2),
                previousAppearance: nil
            ),
        ]
    ))
    let fitAverage = try #require(fitAppearances.first?.backgroundColor)
    #expect(abs(fitAverage.red - 0.625) < 0.01)
    #expect(abs(fitAverage.green - 0.5) < 0.01)
    #expect(abs(fitAverage.blue - 0.875) < 0.01)
}
