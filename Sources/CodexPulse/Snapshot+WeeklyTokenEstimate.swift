import Foundation

extension Snapshot {
    /// A projection at the current usage mix, not a fixed account token allowance.
    var estimatedCodexWeeklyTokenTotal: Int? {
        guard let tokens = codexTokensInWeeklyWindow, tokens > 0,
              let percent = weeklyLimitWindow?.used,
              percent.isFinite, percent > 0, percent <= 100 else { return nil }
        let estimate = (Double(tokens) / (percent / 100)).rounded()
        guard estimate.isFinite, estimate >= 0, estimate < Double(Int.max) else { return nil }
        return Int(estimate)
    }
}
