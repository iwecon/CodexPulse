import Foundation
import Testing
@testable import CodexPulse

private func weeklyEstimateSnapshot(tokens: Int?, percent: Double) -> Snapshot {
    var snapshot = Snapshot()
    snapshot.codexTokensInWeeklyWindow = tokens
    snapshot.limits = [RateWindow(
        name: "codex", used: percent, minutes: 10_080,
        resetsAt: Date(timeIntervalSince1970: 1_800_000_000),
        observedAt: Date(timeIntervalSince1970: 1_799_900_000)
    )]
    return snapshot
}

@Test func weeklyTokenEstimateUsesRawPercentageAndOnlyWeeklyCodexTokens() {
    var snapshot = weeklyEstimateSnapshot(tokens: 20_000_000, percent: 25)
    snapshot.usage = [.codex: Usage(input: 90_000_000), .claude: Usage(input: 50_000_000)]
    #expect(snapshot.estimatedCodexWeeklyTokenTotal == 80_000_000)
    snapshot = weeklyEstimateSnapshot(tokens: 20_000_000, percent: 12.5)
    #expect(snapshot.estimatedCodexWeeklyTokenTotal == 160_000_000)
    snapshot = weeklyEstimateSnapshot(tokens: 20_000_000, percent: 100)
    #expect(snapshot.estimatedCodexWeeklyTokenTotal == 20_000_000)
}

@Test func weeklyTokenEstimateRejectsMissingInvalidAndOverflowingInputs() {
    for percent in [0.0, -1, 101, .nan, .infinity, -.infinity, .leastNonzeroMagnitude] {
        #expect(weeklyEstimateSnapshot(tokens: 20_000_000, percent: percent)
            .estimatedCodexWeeklyTokenTotal == nil)
    }
    for tokens: Int? in [nil, 0, -1, Int.max] {
        #expect(weeklyEstimateSnapshot(tokens: tokens, percent: 25)
            .estimatedCodexWeeklyTokenTotal == nil)
    }
    var snapshot = weeklyEstimateSnapshot(tokens: 20_000_000, percent: 25)
    snapshot.limits.removeAll()
    #expect(snapshot.estimatedCodexWeeklyTokenTotal == nil)
}

@Test func weeklyTokenEstimateCopyIncludesBothValuesInEveryLanguage() {
    for language in AppLanguage.allCases {
        let text = language.weeklyTokenEstimate(used: "20M", total: "80M")
        #expect(text.contains("20M"))
        #expect(text.contains("80M"))
        #expect(!language.weeklyTokenEstimateHelp.isEmpty)
    }
    #expect(AppLanguage.simplifiedChineseMainland.weeklyTokenEstimate(used: "20M", total: "80M")
        == "已用 20M / 估算 80M")
}
