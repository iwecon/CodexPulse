extension AppLanguage {
    func moveWeeklyQuota(to position: WeeklyQuotaPosition) -> String {
        switch self {
        case .simplifiedChineseMainland:
            switch position {
            case .right: "将周额度移到用量右侧"
            case .above: "将周额度移到用量上方"
            case .below: "将周额度移到用量下方"
            case .left: "将周额度移到用量左侧"
            }
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            switch position {
            case .right: "將每週額度移到用量右側"
            case .above: "將每週額度移到用量上方"
            case .below: "將每週額度移到用量下方"
            case .left: "將每週額度移到用量左側"
            }
        case .japanese:
            switch position {
            case .right: "週間上限を使用量の右に移動"
            case .above: "週間上限を使用量の上に移動"
            case .below: "週間上限を使用量の下に移動"
            case .left: "週間上限を使用量の左に移動"
            }
        case .korean:
            switch position {
            case .right: "주간 한도를 사용량 오른쪽으로 이동"
            case .above: "주간 한도를 사용량 위로 이동"
            case .below: "주간 한도를 사용량 아래로 이동"
            case .left: "주간 한도를 사용량 왼쪽으로 이동"
            }
        case .english:
            switch position {
            case .right: "Move weekly quota to the right of usage"
            case .above: "Move weekly quota above usage"
            case .below: "Move weekly quota below usage"
            case .left: "Move weekly quota to the left of usage"
            }
        }
    }
}
