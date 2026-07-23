import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChineseMainland = "zh-Hans-CN"
    case traditionalChineseHongKong = "zh-Hant-HK"
    case traditionalChineseTaiwan = "zh-Hant-TW"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case english = "en"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var displayName: String {
        switch self {
        case .simplifiedChineseMainland: "简体中文（中国大陆）"
        case .traditionalChineseHongKong: "繁體中文（香港）"
        case .traditionalChineseTaiwan: "繁體中文（台灣）"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .english: "English"
        }
    }

    var recentFourteenDays: String {
        switch self {
        case .simplifiedChineseMainland: "近 14 天"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "近 14 天"
        case .japanese: "過去14日"
        case .korean: "최근 14일"
        case .english: "Last 14 days"
        }
    }

    var weeklyLimit: String {
        switch self {
        case .simplifiedChineseMainland: "周限额"
        case .traditionalChineseHongKong: "每週限額"
        case .traditionalChineseTaiwan: "週限額"
        case .japanese: "週間上限"
        case .korean: "주간 한도"
        case .english: "Weekly limit"
        }
    }

    var weeklyQuota: String {
        switch self {
        case .simplifiedChineseMainland: "周额度"
        case .traditionalChineseHongKong: "每週額度"
        case .traditionalChineseTaiwan: "週額度"
        case .japanese: "週間割り当て"
        case .korean: "주간 할당량"
        case .english: "Weekly quota"
        }
    }

    var noData: String {
        switch self {
        case .simplifiedChineseMainland: "暂无数据"
        case .traditionalChineseHongKong: "暫無資料"
        case .traditionalChineseTaiwan: "暫無資料"
        case .japanese: "データなし"
        case .korean: "데이터 없음"
        case .english: "No data"
        }
    }

    var noRecentTasks: String {
        switch self {
        case .simplifiedChineseMainland: "近10分钟没有活动任务"
        case .traditionalChineseHongKong: "近10分鐘沒有活動任務"
        case .traditionalChineseTaiwan: "近10分鐘沒有進行中的任務"
        case .japanese: "過去10分間にアクティブなタスクはありません"
        case .korean: "최근 10분간 활성 작업 없음"
        case .english: "No active tasks in the last 10 minutes"
        }
    }

    var changeLanguage: String {
        switch self {
        case .simplifiedChineseMainland: "切换语言"
        case .traditionalChineseHongKong: "切換語言"
        case .traditionalChineseTaiwan: "切換語言"
        case .japanese: "言語を切り替える"
        case .korean: "언어 전환"
        case .english: "Switch language"
        }
    }

    var languagePickerLabel: String {
        switch self {
        case .simplifiedChineseMainland: "语言选择器"
        case .traditionalChineseHongKong: "語言選擇器"
        case .traditionalChineseTaiwan: "語言選擇器"
        case .japanese: "言語選択"
        case .korean: "언어 선택"
        case .english: "Language picker"
        }
    }

    var runningTask: String {
        switch self {
        case .simplifiedChineseMainland: "任务执行中"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "任務執行中"
        case .japanese: "タスク実行中"
        case .korean: "작업 실행 중"
        case .english: "Task running"
        }
    }

    var completedTask: String {
        switch self {
        case .simplifiedChineseMainland: "任务已完成"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "任務已完成"
        case .japanese: "タスク完了"
        case .korean: "작업 완료"
        case .english: "Task completed"
        }
    }

    func usedPercent(_ value: Int) -> String {
        switch self {
        case .simplifiedChineseMainland: "已用 \(value)%"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "已用 \(value)%"
        case .japanese: "使用済み \(value)%"
        case .korean: "사용 \(value)%"
        case .english: "Used \(value)%"
        }
    }

    func remainingPercent(_ value: Int) -> String {
        switch self {
        case .simplifiedChineseMainland: "剩余 \(value)%"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "剩餘 \(value)%"
        case .japanese: "残り \(value)%"
        case .korean: "남음 \(value)%"
        case .english: "Remaining \(value)%"
        }
    }

    func resetText(_ date: Date) -> String {
        let value = date.formatted(Date.FormatStyle.dateTime.locale(locale).month().day().hour().minute())
        return switch self {
        case .simplifiedChineseMainland: "重置 \(value)"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "重設 \(value)"
        case .japanese: "リセット \(value)"
        case .korean: "재설정 \(value)"
        case .english: "Resets \(value)"
        }
    }

    func averageDailyAvailable(_ value: Double) -> String {
        switch self {
        case .simplifiedChineseMainland: String(format: "日均可用 %.1f%%", locale: locale, value)
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: String(format: "每日平均可用 %.1f%%", locale: locale, value)
        case .japanese: String(format: "1日平均 %.1f%%", locale: locale, value)
        case .korean: String(format: "일평균 사용 가능 %.1f%%", locale: locale, value)
        case .english: String(format: "Daily avg %.1f%%", locale: locale, value)
        }
    }

    func countdown(days: Int, hours: Int, minutes: Int) -> String {
        switch self {
        case .simplifiedChineseMainland:
            if days > 0 { return "倒计时 \(days)天 \(hours)小时" }
            if hours > 0 { return "倒计时 \(hours)小时 \(minutes)分钟" }
            if minutes > 0 { return "倒计时 \(minutes)分钟" }
            return "倒计时 小于1分钟"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            if days > 0 { return "倒數 \(days)日 \(hours)小時" }
            if hours > 0 { return "倒數 \(hours)小時 \(minutes)分鐘" }
            if minutes > 0 { return "倒數 \(minutes)分鐘" }
            return "倒數 少於1分鐘"
        case .japanese:
            if days > 0 { return "残り \(days)日 \(hours)時間" }
            if hours > 0 { return "残り \(hours)時間 \(minutes)分" }
            if minutes > 0 { return "残り \(minutes)分" }
            return "残り1分未満"
        case .korean:
            if days > 0 { return "남은 시간 \(days)일 \(hours)시간" }
            if hours > 0 { return "남은 시간 \(hours)시간 \(minutes)분" }
            if minutes > 0 { return "남은 시간 \(minutes)분" }
            return "남은 시간 1분 미만"
        case .english:
            if days > 0 { return "Remaining \(days)d \(hours)h" }
            if hours > 0 { return "Remaining \(hours)h \(minutes)m" }
            if minutes > 0 { return "Remaining \(minutes)m" }
            return "Less than 1m remaining"
        }
    }

    func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle.dateTime.locale(locale).month().day())
    }

    func accessibilityDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle.dateTime.locale(locale).year().month().day())
    }

    func tokenCount(_ value: Int) -> String {
        switch self {
        case .simplifiedChineseMainland: "\(value) 个 Token"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "\(value) 個 Token"
        case .japanese: "\(value)トークン"
        case .korean: "\(value) 토큰"
        case .english: "\(value) tokens"
        }
    }

    func movePanel(_ panel: DockPanelIdentity, to target: PanelSide) -> String {
        let panelName: String
        let direction: String
        switch self {
        case .simplifiedChineseMainland:
            panelName = panel == .usageOverview ? "用量概览面板" : "任务活动面板"
            direction = target == .left ? "左侧" : "右侧"
            return "将\(panelName)移到\(direction)"
        case .traditionalChineseHongKong:
            panelName = panel == .usageOverview ? "用量概覽面板" : "任務活動面板"
            direction = target == .left ? "左側" : "右側"
            return "將\(panelName)移到\(direction)"
        case .traditionalChineseTaiwan:
            panelName = panel == .usageOverview ? "用量概覽面板" : "任務活動面板"
            direction = target == .left ? "左側" : "右側"
            return "將\(panelName)移至\(direction)"
        case .japanese:
            panelName = panel == .usageOverview ? "使用量概要パネル" : "タスクアクティビティパネル"
            direction = target == .left ? "左側" : "右側"
            return "\(panelName)を\(direction)へ移動"
        case .korean:
            panelName = panel == .usageOverview ? "사용량 개요 패널" : "작업 활동 패널"
            direction = target == .left ? "왼쪽" : "오른쪽"
            return "\(panelName)을 \(direction)으로 이동"
        case .english:
            panelName = panel == .usageOverview ? "Usage Overview Panel" : "Task Activity Panel"
            direction = target == .left ? "left" : "right"
            return "Move \(panelName) to the \(direction)"
        }
    }

    func swapPanelOrder(_ panel: DockPanelIdentity) -> String {
        switch self {
        case .simplifiedChineseMainland: panel == .usageOverview ? "交换用量概览面板的上下位置" : "交换任务活动面板的上下位置"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: panel == .usageOverview ? "交換用量概覽面板的上下位置" : "交換任務活動面板的上下位置"
        case .japanese: panel == .usageOverview ? "使用量概要パネルの上下位置を入れ替える" : "タスクアクティビティパネルの上下位置を入れ替える"
        case .korean: panel == .usageOverview ? "사용량 개요 패널의 위아래 위치 전환" : "작업 활동 패널의 위아래 위치 전환"
        case .english: panel == .usageOverview ? "Swap the Usage Overview Panel vertically" : "Swap the Task Activity Panel vertically"
        }
    }

    func resizeLabel(_ panel: DockPanelIdentity, tooltip: Bool) -> String {
        switch self {
        case .simplifiedChineseMainland:
            return tooltip
                ? (panel == .usageOverview ? "拖动以调整用量概览面板宽度" : "拖动以调整任务活动面板宽度")
                : (panel == .usageOverview ? "调整用量概览面板宽度" : "调整任务活动面板宽度")
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            return tooltip
                ? (panel == .usageOverview ? "拖動以調整用量概覽面板寬度" : "拖動以調整任務活動面板寬度")
                : (panel == .usageOverview ? "調整用量概覽面板寬度" : "調整任務活動面板寬度")
        case .japanese:
            let name = panel == .usageOverview ? "使用量概要パネル" : "タスクアクティビティパネル"
            return tooltip ? "ドラッグして\(name)の幅を調整" : "\(name)の幅を調整"
        case .korean:
            let name = panel == .usageOverview ? "사용량 개요 패널" : "작업 활동 패널"
            return tooltip ? "드래그하여 \(name) 너비 조절" : "\(name) 너비 조절"
        case .english:
            let name = panel == .usageOverview ? "Usage Overview Panel" : "Task Activity Panel"
            return tooltip ? "Drag to resize \(name)" : "Resize \(name)"
        }
    }

    func openSession(_ title: String) -> String {
        switch self {
        case .simplifiedChineseMainland: "在 ChatGPT 中打开会话：\(title)"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "在 ChatGPT 中開啟會話：\(title)"
        case .japanese: "ChatGPTでセッションを開く：\(title)"
        case .korean: "ChatGPT에서 세션 열기: \(title)"
        case .english: "Open session in ChatGPT: \(title)"
        }
    }
}

struct AppLanguagePreference: Equatable {
    static let defaultsKey = "app.language"
    var language: AppLanguage = .simplifiedChineseMainland

    init(language: AppLanguage = .simplifiedChineseMainland) {
        self.language = language
    }

    init(defaults: UserDefaults) {
        language = defaults.string(forKey: Self.defaultsKey)
            .flatMap(AppLanguage.init(rawValue:))
            ?? .simplifiedChineseMainland
    }

    func save(to defaults: UserDefaults) {
        defaults.set(language.rawValue, forKey: Self.defaultsKey)
    }
}

@MainActor @Observable
final class AppLanguageSettings {
    private let defaults: UserDefaults
    var language: AppLanguage {
        didSet {
            guard oldValue != language else { return }
            AppLanguagePreference(language: language).save(to: defaults)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        language = AppLanguagePreference(defaults: defaults).language
    }
}
