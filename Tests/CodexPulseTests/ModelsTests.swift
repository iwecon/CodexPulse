import Foundation
import Testing
@testable import CodexPulse

@Test func activeToolsIncludesOnlyToolsWithUsageInWindow() {
    var snapshot = Snapshot()
    let day = Date(timeIntervalSince1970: 1_780_000_000)
    snapshot.dailyUsage = [
        DailyUsage(date: day, usage: [
            .claude: .zero,
            .codex: Usage(input: 5, requests: 1),
            .opencode: .zero,
        ]),
        DailyUsage(date: day.addingTimeInterval(86_400), usage: [
            .claude: Usage(output: 3, requests: 1),
            .codex: .zero,
            .opencode: .zero,
        ]),
    ]

    #expect(snapshot.activeTools == [.claude, .codex])
}

@Test func activeToolsIsEmptyWithoutAnyUsage() {
    var snapshot = Snapshot()
    snapshot.dailyUsage = [
        DailyUsage(
            date: Date(timeIntervalSince1970: 1_780_000_000),
            usage: [.claude: .zero, .codex: .zero, .opencode: .zero]
        )
    ]

    #expect(snapshot.activeTools.isEmpty)
}

@Test func weeklyLimitWindowPicksTheWindowClosestToSevenDays() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    func window(_ minutes: Int) -> RateWindow {
        RateWindow(name: "codex", used: 40, minutes: minutes, resetsAt: now, observedAt: now)
    }
    var snapshot = Snapshot()
    snapshot.limits = [window(300), window(7_200), window(10_080), window(20_160)]

    #expect(snapshot.weeklyLimitWindow?.minutes == 10_080)
}

@Test func weeklyLimitWindowIsNilWithoutAWeeklyRateWindow() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)
    var snapshot = Snapshot()

    #expect(snapshot.weeklyLimitWindow == nil)

    snapshot.limits = [
        RateWindow(name: "codex", used: 40, minutes: 300, resetsAt: now, observedAt: now)
    ]

    #expect(snapshot.weeklyLimitWindow == nil)
}

@Test func snapshotsWithDifferentWeeklyWindowTokensAreNotSameContent() {
    var first = Snapshot()
    first.codexTokensInWeeklyWindow = 100
    var second = Snapshot()
    second.codexTokensInWeeklyWindow = 200

    #expect(!first.hasSameContent(as: second))

    second.codexTokensInWeeklyWindow = 100
    #expect(first.hasSameContent(as: second))
}

@Test func usageSourcePolicyScansEverySource() {
    #expect(UsageSourcePolicy.enabledTools == Set(Tool.allCases))
}

@Test func toolBarColorsFollowPanelPolarityAndStayDistinct() {
    for tool in Tool.allCases where tool.fixedBarColor == nil {
        let light = AdaptiveTextColor.barColor(for: tool, appearance: .dark)
        let dark = AdaptiveTextColor.barColor(for: tool, appearance: .light)
        #expect(light.relativeLuminance > dark.relativeLuminance)
    }
    for appearance in [PanelSemanticAppearance.dark, .light] {
        let colors = Tool.allCases.map {
            AdaptiveTextColor.barColor(for: $0, appearance: appearance)
        }
        #expect(Set(colors.map(\.debugRGBDescription)).count == Tool.allCases.count)
    }
}

@Test func codexBarColorIsItsFixedBrandBlueInBothAppearances() {
    let brandBlue = WallpaperRGB(red: 65 / 255, green: 68 / 255, blue: 245 / 255)
    for appearance in [PanelSemanticAppearance.dark, .light] {
        #expect(AdaptiveTextColor.barColor(for: .codex, appearance: appearance) == brandBlue)
    }
}
