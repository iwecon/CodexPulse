import Foundation

enum WeeklyQuotaPosition: String, CaseIterable {
    case right
    case above
    case below
    case left

    var next: Self {
        switch self {
        case .right: .above
        case .above: .below
        case .below: .left
        case .left: .right
        }
    }

    var isVertical: Bool { self == .above || self == .below }
    var quotaFirst: Bool { self == .above || self == .left }

    func panelHeight(showsQuota: Bool) -> CGFloat {
        showsQuota && isVertical ? 112 : 56
    }

    func controlPresentation(language: AppLanguage) -> PanelMovementPresentation {
        let symbol = switch next {
        case .right: "rectangle.righthalf.inset.filled"
        case .above: "rectangle.tophalf.inset.filled"
        case .below: "rectangle.bottomhalf.inset.filled"
        case .left: "rectangle.lefthalf.inset.filled"
        }
        return PanelMovementPresentation(
            systemImageName: symbol,
            label: language.moveWeeklyQuota(to: next)
        )
    }
}
