extension AppLanguage {
    func weeklyTokenEstimate(used: String, total: String) -> String {
        switch self {
        case .simplifiedChineseMainland: "已用 \(used) / 估算 \(total)"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "已用 \(used) / 估算 \(total)"
        case .japanese: "使用済み \(used) / 推定 \(total)"
        case .korean: "사용 \(used) / 추정 \(total)"
        case .english: "Used \(used) / Est. \(total)"
        }
    }

    var weeklyTokenEstimateHelp: String {
        switch self {
        case .simplifiedChineseMainland:
            "本周已用 token / 估算周总量。按当前使用结构推算，非固定官方额度；其他设备或云端用量可能未计入本地统计。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            "本週已用 token / 估算週總量。按目前使用結構推算，並非固定官方額度；其他裝置或雲端用量可能未計入本機統計。"
        case .japanese:
            "今週の使用済みトークン / 週間合計の推定値。現在の利用傾向に基づく推定で、公式の固定上限ではありません。他の端末やクラウドでの使用量はローカル集計に含まれない場合があります。"
        case .korean:
            "이번 주 사용 토큰 / 추정 주간 총량. 현재 사용 패턴에 따른 추정치이며 공식 고정 한도가 아닙니다. 다른 기기나 클라우드 사용량은 로컬 집계에서 제외될 수 있습니다."
        case .english:
            "Tokens used this week / estimated weekly total. Projected from the current usage mix, not a fixed official allowance. Local totals may exclude other devices or cloud usage."
        }
    }
}
