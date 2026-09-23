import SwiftUI

struct WeeklyQuotaLayoutView<Trend: View, Quota: View>: View {
    let position: WeeklyQuotaPosition
    let showsQuota: Bool
    @ViewBuilder let trend: () -> Trend
    @ViewBuilder let quota: () -> Quota

    private var layout: AnyLayout {
        position.isVertical
            ? AnyLayout(VStackLayout(spacing: 6))
            : AnyLayout(HStackLayout(spacing: 6))
    }

    var body: some View {
        layout {
            if showsQuota && position.quotaFirst {
                quota()
                separator
            }
            trend()
            if showsQuota && !position.quotaFirst {
                separator
                quota()
            }
        }
    }

    @ViewBuilder
    private var separator: some View {
        if position.isVertical {
            Divider()
        } else {
            Divider().frame(height: 24)
        }
    }
}
