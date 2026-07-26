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

@MainActor
@Test func codexSessionLinkViewUpdatesItsExplicitAdaptiveForeground() {
    let view = CodexSessionLinkView(
        threadID: "thread-1",
        title: "# latest user message",
        language: .simplifiedChineseMainland,
        textAlignment: .left,
        semanticAppearance: .light
    )
    #expect(view.renderedForegroundColor == .black)

    view.setAppearance(.dark)

    #expect(view.renderedForegroundColor == .white)
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

private func wallpaperSequoiaStoreData(styleID: String) throws -> Data {
    let choiceConfiguration = try PropertyListSerialization.data(
        fromPropertyList: [:],
        format: .binary,
        options: 0
    )
    let encodedOptions = try PropertyListSerialization.data(
        fromPropertyList: [
            "values": [
                "appearance": ["picker": ["_0": ["id": "system"]]],
                "appearanceMode": ["picker": ["_0": ["id": "automatic"]]],
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
                            "Provider": "com.apple.wallpaper.choice.sequoia",
                            "Files": [],
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
    configuration: [String: Any] = [:],
    styleID: String? = nil
) throws -> Data {
    let choiceConfiguration = try PropertyListSerialization.data(
        fromPropertyList: configuration,
        format: .binary,
        options: 0
    )
    var content: [String: Any] = [
        "Choices": [[
            "Provider": provider,
            "Files": files.map(\.absoluteString),
            "Configuration": choiceConfiguration,
        ]],
    ]
    if let styleID {
        content["EncodedOptionValues"] = try PropertyListSerialization.data(
            fromPropertyList: [
                "values": [
                    "style": ["picker": ["_0": ["id": styleID]]],
                ],
            ],
            format: .binary,
            options: 0
        )
    }
    return try PropertyListSerialization.data(
        fromPropertyList: [
            "AllSpacesAndDisplays": [
                "Desktop": [
                    "Content": content,
                ],
            ],
        ],
        format: .binary,
        options: 0
    )
}

private func writeDesktopPictureDescriptor(
    at descriptorURL: URL,
    thumbnailPath: String,
    isDynamic: Bool
) throws {
    let data = try PropertyListSerialization.data(
        fromPropertyList: [
            "thumbnailPath": thumbnailPath,
            "isDynamic": isDynamic,
        ],
        format: .xml,
        options: 0
    )
    try data.write(to: descriptorURL)
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

@Test func wallpaperStoreUsesDirectDesktopFillColorForSystemColorSelection() async throws {
    let directColor = WallpaperRGB(
        red: 84.0 / 255,
        green: 85.0 / 255,
        blue: 84.0 / 255
    )
    for name in ["stone", "future-system-color"] {
        let data = try wallpaperSystemColorStoreData(name: name)
        #expect(WallpaperStoreConfiguration.solidColor(in: data) == nil)
        #expect(WallpaperStoreConfiguration.solidColor(
            in: data,
            desktopFillColor: directColor
        ) == directColor)
    }

    let stoneData = try wallpaperSystemColorStoreData(name: "stone")
    let resolver = WallpaperSourceResolver()
    #expect(resolver.resolve(
        indexData: stoneData,
        displayUUID: nil,
        workspaceURL: nil
    ) == .unavailable)
    let source = resolver.resolve(
        indexData: stoneData,
        displayUUID: nil,
        workspaceURL: nil,
        workspaceFillColor: directColor
    )
    #expect(source == .solid(directColor))

    let appearances = await WallpaperAppearanceSampler().appearances(
        for: WallpaperAppearanceRequest(
            source: source,
            screenSize: CGSize(width: 1_920, height: 1_080),
            scalingMode: .fill,
            fillColor: directColor,
            panelRegions: [
                WallpaperPanelRegion(
                    identifier: 0,
                    frame: CGRect(x: 0, y: 0, width: 300, height: 56),
                    previousAppearance: .light
                ),
            ]
        )
    )
    let result = try #require(appearances.first)
    #expect(result.backgroundColor == directColor)
    #expect(result.appearance == .dark)
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

@Test func wallpaperSourceResolverUsesSystemDesktopPictureSchemaAcrossLegacyDynamicWallpapers() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseDesktopPictureSchemaTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        sequoiaResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )
    for name in ["Big Sur", "Monterey Graphic", "Catalina"] {
        let descriptorURL = temporaryDirectory.appending(path: "\(name).madesktop")
        let baseURL = temporaryDirectory.appending(path: "\(name).heic")
        let lightURL = temporaryDirectory.appending(path: "\(name) Light.heic")
        let darkURL = temporaryDirectory.appending(path: "\(name) Dark.heic")
        for url in [baseURL, lightURL, darkURL] {
            try Data(name.utf8).write(to: url)
        }
        try writeDesktopPictureDescriptor(
            at: descriptorURL,
            thumbnailPath: baseURL.path,
            isDynamic: true
        )

        let source = resolver.resolve(
            indexData: try wallpaperSourceStoreData(
                provider: "com.apple.wallpaper.choice.dynamic",
                configuration: [
                    "type": "systemDesktopPicture",
                    "url": ["relative": descriptorURL.absoluteString],
                ]
            ),
            displayUUID: nil,
            workspaceURL: nil
        )
        #expect(source == .phaseUnknown([
            WallpaperSourceCandidate(url: darkURL),
            WallpaperSourceCandidate(url: lightURL),
            WallpaperSourceCandidate(url: baseURL),
        ]))
        #expect(!source.candidates.contains { $0.url == descriptorURL })
    }
}

@Test func wallpaperSourceResolverHandlesDesktopPictureDescriptorStylesAndStaticAssets() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseDesktopPictureStyleTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        sequoiaResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )

    let dynamicDescriptor = temporaryDirectory.appending(path: "Dynamic.madesktop")
    let baseURL = temporaryDirectory.appending(path: "Dynamic.heic")
    let lightURL = temporaryDirectory.appending(path: "Dynamic Light.heic")
    let darkURL = temporaryDirectory.appending(path: "Dynamic Dark.heic")
    for url in [baseURL, lightURL, darkURL] {
        try Data("fixture".utf8).write(to: url)
    }
    try writeDesktopPictureDescriptor(
        at: dynamicDescriptor,
        thumbnailPath: "Dynamic.heic",
        isDynamic: true
    )

    func source(style: String) throws -> WallpaperSource {
        resolver.resolve(
            indexData: try wallpaperSourceStoreData(
                provider: "future.provider.with.schema",
                files: [dynamicDescriptor],
                styleID: style
            ),
            displayUUID: nil,
            workspaceURL: nil
        )
    }

    #expect(try source(style: "light") == .staticImage(WallpaperSourceCandidate(url: lightURL)))
    #expect(try source(style: "dark") == .staticImage(WallpaperSourceCandidate(url: darkURL)))

    let staticDescriptor = temporaryDirectory.appending(path: "Static.madesktop")
    let staticURL = temporaryDirectory.appending(path: "Static.jpg")
    try Data("static".utf8).write(to: staticURL)
    try writeDesktopPictureDescriptor(
        at: staticDescriptor,
        thumbnailPath: staticURL.path,
        isDynamic: false
    )
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.dynamic",
            files: [staticDescriptor]
        ),
        displayUUID: nil,
        workspaceURL: nil
    ) == .staticImage(WallpaperSourceCandidate(url: staticURL)))

    let baseOnlyDescriptor = temporaryDirectory.appending(path: "Solar Gradients.madesktop")
    let baseOnlyURL = temporaryDirectory.appending(path: "Solar Gradients.heic")
    try Data("base".utf8).write(to: baseOnlyURL)
    try writeDesktopPictureDescriptor(
        at: baseOnlyDescriptor,
        thumbnailPath: baseOnlyURL.path,
        isDynamic: true
    )
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.dynamic",
            files: [baseOnlyDescriptor]
        ),
        displayUUID: nil,
        workspaceURL: nil
    ) == .staticImage(WallpaperSourceCandidate(url: baseOnlyURL)))
}

@Test func wallpaperSourceResolverRejectsInvalidDescriptorsDirectoriesAndUnauthorizedFallbacks() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseDesktopPictureSafetyTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        sequoiaResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )
    let workspaceURL = temporaryDirectory.appending(path: "workspace.jpg")
    let explicitURL = temporaryDirectory.appending(path: "explicit.png")
    let rawImageURL = temporaryDirectory.appending(path: "camera-raw.dng")
    let mpegMovieURL = temporaryDirectory.appending(path: "legacy-video.mpeg")
    try Data("workspace".utf8).write(to: workspaceURL)
    try Data("explicit".utf8).write(to: explicitURL)
    try Data("raw".utf8).write(to: rawImageURL)
    try Data("video".utf8).write(to: mpegMovieURL)

    let malformedDescriptor = temporaryDirectory.appending(path: "Malformed.madesktop")
    try Data("not a plist".utf8).write(to: malformedDescriptor)
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image",
            files: [malformedDescriptor]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)

    let missingThumbnailDescriptor = temporaryDirectory.appending(path: "Missing Thumbnail.madesktop")
    try writeDesktopPictureDescriptor(
        at: missingThumbnailDescriptor,
        thumbnailPath: "does-not-exist.heic",
        isDynamic: true
    )
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.dynamic",
            files: [missingThumbnailDescriptor]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)

    let descriptorDirectory = temporaryDirectory.appending(
        path: "Directory.madesktop",
        directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(at: descriptorDirectory, withIntermediateDirectories: true)
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image",
            files: [descriptorDirectory]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)

    let imageFolder = temporaryDirectory.appending(path: "Wallpapers", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)
    try Data("nested".utf8).write(to: imageFolder.appending(path: "nested.jpg"))
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image-folder",
            files: [imageFolder]
        ),
        displayUUID: nil,
        workspaceURL: imageFolder
    ) == .unavailable)
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image-folder",
            files: [imageFolder]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .staticImage(WallpaperSourceCandidate(url: workspaceURL)))

    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.example.UnknownProcedural",
            files: [explicitURL]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .staticImage(WallpaperSourceCandidate(url: explicitURL)))
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "future.image.provider",
            files: [rawImageURL]
        ),
        displayUUID: nil,
        workspaceURL: nil
    ) == .staticImage(WallpaperSourceCandidate(url: rawImageURL, kind: .image)))
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "future.movie.provider",
            files: [mpegMovieURL]
        ),
        displayUUID: nil,
        workspaceURL: nil
    ) == .staticImage(WallpaperSourceCandidate(url: mpegMovieURL, kind: .video)))
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(provider: "com.example.UnknownProcedural"),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(provider: "com.example.extension.photos"),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)

    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image",
            configuration: [
                "type": "systemDesktopPicture",
                "url": ["relative": "https://example.com/remote.heic"],
            ]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)

    let remoteThumbnailDescriptor = temporaryDirectory.appending(path: "Remote Thumbnail.madesktop")
    try writeDesktopPictureDescriptor(
        at: remoteThumbnailDescriptor,
        thumbnailPath: "https://example.com/remote.heic",
        isDynamic: false
    )
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image",
            files: [remoteThumbnailDescriptor]
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .unavailable)
}

@Test func wallpaperSourceResolverPrefersExplicitFilesThenConfigurationBeforeWorkspaceFallback() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseDesktopPicturePrecedenceTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        sequoiaResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )
    let explicitURL = temporaryDirectory.appending(path: "explicit.jpg")
    let configuredURL = temporaryDirectory.appending(path: "configured.heic")
    let workspaceURL = temporaryDirectory.appending(path: "workspace.png")
    let directory = temporaryDirectory.appending(path: "directory", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    for url in [explicitURL, configuredURL, workspaceURL] {
        try Data("fixture".utf8).write(to: url)
    }
    let configuration: [String: Any] = [
        "type": "systemDesktopPicture",
        "url": ["relative": configuredURL.absoluteString],
    ]

    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "com.apple.wallpaper.choice.image",
            files: [explicitURL],
            configuration: configuration
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .staticImage(WallpaperSourceCandidate(url: explicitURL)))
    #expect(resolver.resolve(
        indexData: try wallpaperSourceStoreData(
            provider: "future.provider",
            files: [directory],
            configuration: configuration
        ),
        displayUUID: nil,
        workspaceURL: workspaceURL
    ) == .staticImage(WallpaperSourceCandidate(url: configuredURL)))
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

@Test func wallpaperSourceResolverUsesLocalSequoiaStyleCandidatesWithoutStaleFallback() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
        .appending(path: "CodexPulseSequoiaSourceTests-(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    let lightURL = temporaryDirectory.appending(path: "thumbnail light.heic")
    let darkURL = temporaryDirectory.appending(path: "thumbnail dark.heic")
    let staleURL = temporaryDirectory.appending(path: "DefaultDesktop.heic")
    for (url, contents) in [
        (lightURL, "light"),
        (darkURL, "dark"),
        (staleURL, "stale"),
    ] {
        try Data(contents.utf8).write(to: url)
    }
    let resolver = WallpaperSourceResolver(
        aerialResourcesDirectory: temporaryDirectory,
        neptuneResourcesDirectory: temporaryDirectory,
        sequoiaResourcesDirectory: temporaryDirectory,
        aerialMovieDirectories: []
    )

    let dynamic = resolver.resolve(
        indexData: try wallpaperSequoiaStoreData(styleID: "dynamic"),
        displayUUID: nil,
        workspaceURL: staleURL
    )
    #expect(dynamic == .phaseUnknown([
        WallpaperSourceCandidate(url: darkURL),
        WallpaperSourceCandidate(url: lightURL),
    ]))

    let light = resolver.resolve(
        indexData: try wallpaperSequoiaStoreData(styleID: "light"),
        displayUUID: nil,
        workspaceURL: staleURL
    )
    let dark = resolver.resolve(
        indexData: try wallpaperSequoiaStoreData(styleID: "dark"),
        displayUUID: nil,
        workspaceURL: staleURL
    )
    #expect(light == .staticImage(WallpaperSourceCandidate(url: lightURL)))
    #expect(dark == .staticImage(WallpaperSourceCandidate(url: darkURL)))
    #expect(dynamic.identity != light.identity)
    #expect(light.identity != dark.identity)

    try FileManager.default.removeItem(at: darkURL)
    let automaticWithOneCandidate = resolver.resolve(
        indexData: try wallpaperSequoiaStoreData(styleID: "automatic"),
        displayUUID: nil,
        workspaceURL: staleURL
    )
    #expect(automaticWithOneCandidate == .staticImage(WallpaperSourceCandidate(url: lightURL)))
    #expect(resolver.resolve(
        indexData: try wallpaperSequoiaStoreData(styleID: "dark"),
        displayUUID: nil,
        workspaceURL: staleURL
    ) == .unavailable)

    try FileManager.default.removeItem(at: lightURL)
    #expect(resolver.resolve(
        indexData: try wallpaperSequoiaStoreData(styleID: "dynamic"),
        displayUUID: nil,
        workspaceURL: staleURL
    ) == .unavailable)
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
