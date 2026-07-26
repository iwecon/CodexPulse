import Foundation
import Testing
@testable import CodexPulse

@Test func wallpaperRGBHexRoundTripsAndClampsComponents() {
    let color = WallpaperRGB(red: 65 / 255, green: 68 / 255, blue: 245 / 255)
    #expect(color.hexString == "#4144F5")
    #expect(WallpaperRGB(hexString: "#4144F5") == color)
    #expect(WallpaperRGB(hexString: "4144F5") == color)

    let outOfRange = WallpaperRGB(red: -0.5, green: 1.5, blue: 0.5)
    #expect(outOfRange.hexString == "#00FF80")
}

@Test func wallpaperRGBRejectsMalformedHexStrings() {
    for invalid in ["", "#", "#12345", "#1234567", "#GGHHII", "+1234A", "#41 44F5", "0x4144F5"] {
        #expect(WallpaperRGB(hexString: invalid) == nil, "\(invalid) should not parse")
    }
}

@Test func toolBarColorPreferencePersistsAndResetsPerTool() throws {
    let suiteName = "ToolBarColorTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(ToolBarColorPreference(defaults: defaults).customColors.isEmpty)

    let claudeColor = WallpaperRGB(hexString: "#22AA66")
    var preference = ToolBarColorPreference()
    preference.customColors[.claude] = claudeColor
    preference.save(to: defaults)
    #expect(ToolBarColorPreference(defaults: defaults).customColors == [.claude: claudeColor])

    preference.customColors[.claude] = nil
    preference.save(to: defaults)
    #expect(ToolBarColorPreference(defaults: defaults).customColors.isEmpty)
    #expect(defaults.string(forKey: ToolBarColorPreference.defaultsKey(for: .claude)) == nil)
}

@Test func toolBarColorPreferenceIgnoresCorruptedStoredValues() throws {
    let suiteName = "ToolBarColorTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set("not-a-color", forKey: ToolBarColorPreference.defaultsKey(for: .codex))
    #expect(ToolBarColorPreference(defaults: defaults).customColors.isEmpty)
}

@Test func customBarColorOverridesBuiltInColorsInBothAppearances() {
    let custom = WallpaperRGB(red: 0.1, green: 0.8, blue: 0.3)
    let preference = ToolBarColorPreference(customColors: [.codex: custom])

    for appearance in [PanelSemanticAppearance.dark, .light] {
        #expect(preference.barColor(for: .codex, appearance: appearance) == custom)
        #expect(
            preference.barColor(for: .claude, appearance: appearance)
                == AdaptiveTextColor.barColor(for: .claude, appearance: appearance)
        )
    }
}

@Test func toolSettingsKeysAreStableAndDistinct() {
    #expect(Tool.allCases.map(\.settingsKey) == ["claude", "codex", "opencode"])
}

@Test func barColorSettingsWindowAnchorsAboveUsagePanelMatchingItsSide() {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let size = CGSize(width: 320, height: 260)

    let leftSide = BarColorSettingsPlacement.anchoredFrame(
        panelSize: size,
        usagePanelFrame: CGRect(x: 2, y: 2, width: 420, height: 120),
        visibleFrame: visible
    )
    #expect(leftSide == CGRect(x: 2, y: 132, width: 320, height: 260))

    let rightSide = BarColorSettingsPlacement.anchoredFrame(
        panelSize: size,
        usagePanelFrame: CGRect(x: 1018, y: 2, width: 420, height: 120),
        visibleFrame: visible
    )
    #expect(rightSide == CGRect(x: 1118, y: 132, width: 320, height: 260))
}

@Test func barColorSettingsWindowFrameIsClampedToVisibleFrame() {
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let size = CGSize(width: 320, height: 260)

    let overflowing = BarColorSettingsPlacement.anchoredFrame(
        panelSize: size,
        usagePanelFrame: CGRect(x: 1300, y: 700, width: 420, height: 120),
        visibleFrame: visible
    )
    #expect(visible.contains(overflowing))
    #expect(overflowing == CGRect(x: 1120, y: 615, width: 320, height: 260))

    let widerThanScreen = BarColorSettingsPlacement.anchoredFrame(
        panelSize: CGSize(width: 2000, height: 260),
        usagePanelFrame: CGRect(x: 2, y: 2, width: 420, height: 120),
        visibleFrame: visible
    )
    #expect(widerThanScreen.origin == CGPoint(x: 0, y: 132))
}

@Test func everyLanguageProvidesBarColorSettingsCopy() {
    for language in AppLanguage.allCases {
        #expect(!language.customizeBarColors.isEmpty)
        #expect(!language.barColorSettingsTitle.isEmpty)
        #expect(!language.barColorSettingsExplanation.isEmpty)
        #expect(!language.resetColor.isEmpty)
        #expect(!language.resetAllColors.isEmpty)
    }
}
