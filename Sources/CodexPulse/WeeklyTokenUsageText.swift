import SwiftUI

/// Keeps both token figures together, falling back to compact copy as space narrows.
struct WeeklyTokenUsageText: View {
    let used: Int
    let estimatedTotal: Int?
    let language: AppLanguage
    let compact: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if !compact {
                Text(fullText)
                    .fixedSize()
            }
            Text(compactText)
                .minimumScaleFactor(0.75)
        }
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityLabel(fullText)
        .accessibilityHint(estimatedTotal == nil ? "" : language.weeklyTokenEstimateHelp)
    }

    private var fullText: String {
        guard let estimatedTotal else {
            return language.weeklyWindowConsumedTokens(UsageModel.compact(used))
        }
        return language.weeklyTokenEstimate(
            used: UsageModel.compact(used), total: UsageModel.compact(estimatedTotal)
        )
    }

    private var compactText: String {
        guard let estimatedTotal else { return UsageModel.compact(used) }
        return "\(UsageModel.compact(used)) / ≈\(UsageModel.compact(estimatedTotal))"
    }
}
