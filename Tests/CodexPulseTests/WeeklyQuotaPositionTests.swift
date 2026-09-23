import AppKit
import SwiftUI
import Testing
@testable import CodexPulse

@Test func weeklyQuotaPositionDefaultsAndPersistenceAreIndependentOfPanelSide() throws {
    let suite = "CodexPulseTests.WeeklyQuotaPosition.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    #expect(DockPanelPreferences(defaults: defaults).weeklyQuotaPosition == .right)
    for side in PanelSide.allCases {
        for position in WeeklyQuotaPosition.allCases {
            let preferences = DockPanelPreferences(
                arrangement: PanelArrangement(usageSide: side),
                hidesWeeklyLimit: true,
                weeklyQuotaPosition: position
            )
            preferences.save(to: defaults)
            #expect(DockPanelPreferences(defaults: defaults) == preferences)
        }
    }
    defaults.set("invalid", forKey: "dockPanels.usageOverview.weeklyQuotaPosition")
    #expect(DockPanelPreferences(defaults: defaults).weeklyQuotaPosition == .right)
}

@Test @MainActor func weeklyQuotaPositionCyclesWithLocalizedControlLabels() {
    var position = WeeklyQuotaPosition.right
    for expected in [WeeklyQuotaPosition.above, .below, .left, .right] {
        for language in AppLanguage.allCases {
            let control = position.controlPresentation(language: language)
            #expect(control.label == language.moveWeeklyQuota(to: expected))
            #expect(!control.label.isEmpty)
            #expect(NSImage(systemSymbolName: control.systemImageName, accessibilityDescription: nil) != nil)
        }
        position = position.next
        #expect(position == expected)
    }
    #expect(AppLanguage.simplifiedChineseMainland.moveWeeklyQuota(to: .above) == "将周额度移到用量上方")
}

@Test func weeklyQuotaVerticalHeightCollapsesWhenQuotaIsHiddenOrUnavailable() {
    for position in WeeklyQuotaPosition.allCases {
        #expect(position.panelHeight(showsQuota: false) == 56)
        #expect(position.panelHeight(showsQuota: true) == (position == .above || position == .below ? 112 : 56))
    }
}

@Test @MainActor func weeklyQuotaLayoutRendersAllFourPositionsAndRemovesHiddenQuota() throws {
    for position in WeeklyQuotaPosition.allCases {
        for showsQuota in [true, false] {
            let view = WeeklyQuotaLayoutView(position: position, showsQuota: showsQuota) {
                Color(.sRGB, red: 1, green: 0, blue: 0).frame(width: 40, height: 24)
            } quota: {
                Color(.sRGB, red: 0, green: 0, blue: 1).frame(width: 60, height: 32)
            }
            .frame(width: 200, height: 140)
            .background(.black)
            let image = try #require(ImageRenderer(content: view).cgImage)
            let bitmap = NSBitmapImageRep(cgImage: image)
            var usagePixels: [CGPoint] = []
            var quotaPixels: [CGPoint] = []
            for y in 0..<bitmap.pixelsHigh {
                for x in 0..<bitmap.pixelsWide {
                    guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                    if color.redComponent > 0.8 && color.blueComponent < 0.2 {
                        usagePixels.append(CGPoint(x: x, y: y))
                    } else if color.blueComponent > 0.8 && color.redComponent < 0.2 {
                        quotaPixels.append(CGPoint(x: x, y: y))
                    }
                }
            }
            try #require(!usagePixels.isEmpty)
            #expect(usagePixels.count >= 39 * 23)
            if showsQuota {
                try #require(!quotaPixels.isEmpty)
                #expect(quotaPixels.count >= 59 * 31)
                switch position {
                case .right: #expect(quotaPixels.map(\.x).min()! > usagePixels.map(\.x).max()!)
                case .left: #expect(quotaPixels.map(\.x).max()! < usagePixels.map(\.x).min()!)
                case .above: #expect(quotaPixels.map(\.y).max()! < usagePixels.map(\.y).min()!)
                case .below: #expect(quotaPixels.map(\.y).min()! > usagePixels.map(\.y).max()!)
                }
            } else {
                #expect(quotaPixels.isEmpty)
            }
        }
    }
}
