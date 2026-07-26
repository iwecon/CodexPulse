import Foundation
import Testing
@testable import CodexPulse

@Test func completedTaskDimsOnlyAfterThreeMinutes() {
    let completedAt = Date(timeIntervalSince1970: 1_780_000_000)
    let task = TaskExecution(
        id: "completed",
        threadID: "thread",
        title: "任务",
        startedAt: completedAt.addingTimeInterval(-30),
        completedAt: completedAt
    )

    #expect(!task.shouldDimMessage(at: completedAt.addingTimeInterval(179)))
    #expect(!task.shouldDimMessage(at: completedAt.addingTimeInterval(180)))
    #expect(task.shouldDimMessage(at: completedAt.addingTimeInterval(181)))
}

@Test func runningTaskNeverDimsAsCompleted() {
    let startedAt = Date(timeIntervalSince1970: 1_780_000_000)
    let task = TaskExecution(
        id: "running",
        threadID: "thread",
        title: "任务",
        startedAt: startedAt,
        completedAt: nil
    )

    #expect(!task.shouldDimMessage(at: startedAt.addingTimeInterval(600)))
}

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

@Test func usageSourcePolicyScansEverySource() {
    #expect(UsageSourcePolicy.enabledTools == Set(Tool.allCases))
}

@Test func toolBarColorsFollowPanelPolarityAndStayDistinct() {
    for tool in Tool.allCases {
        let light = AdaptiveTextColor.barColor(hueDegrees: tool.barHueDegrees, appearance: .dark)
        let dark = AdaptiveTextColor.barColor(hueDegrees: tool.barHueDegrees, appearance: .light)
        #expect(light.relativeLuminance > dark.relativeLuminance)
    }
    for appearance in [PanelSemanticAppearance.dark, .light] {
        let colors = Tool.allCases.map {
            AdaptiveTextColor.barColor(hueDegrees: $0.barHueDegrees, appearance: appearance)
        }
        #expect(Set(colors.map(\.debugRGBDescription)).count == Tool.allCases.count)
    }
}
