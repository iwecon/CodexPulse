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

    var today: String {
        switch self {
        case .simplifiedChineseMainland: "今日"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "今日"
        case .japanese: "本日"
        case .korean: "오늘"
        case .english: "Today"
        }
    }

    var tomorrow: String {
        switch self {
        case .simplifiedChineseMainland: "明日"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "明日"
        case .japanese: "明日"
        case .korean: "내일"
        case .english: "Tomorrow"
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

    var hideWeeklyQuota: String {
        switch self {
        case .simplifiedChineseMainland: "隐藏周额度信息"
        case .traditionalChineseHongKong: "隱藏每週額度資訊"
        case .traditionalChineseTaiwan: "隱藏週額度資訊"
        case .japanese: "週間割り当て情報を非表示"
        case .korean: "주간 할당량 정보 숨기기"
        case .english: "Hide weekly quota info"
        }
    }

    var showWeeklyQuota: String {
        switch self {
        case .simplifiedChineseMainland: "显示周额度信息"
        case .traditionalChineseHongKong: "顯示每週額度資訊"
        case .traditionalChineseTaiwan: "顯示週額度資訊"
        case .japanese: "週間割り当て情報を表示"
        case .korean: "주간 할당량 정보 표시"
        case .english: "Show weekly quota info"
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

    var taskLoading: String {
        switch self {
        case .simplifiedChineseMainland: "加载中…"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "載入中…"
        case .japanese: "読み込み中…"
        case .korean: "불러오는 중…"
        case .english: "Loading…"
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

    var managePermissions: String {
        switch self {
        case .simplifiedChineseMainland: "权限管理"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "權限管理"
        case .japanese: "権限の管理"
        case .korean: "권한 관리"
        case .english: "Manage permissions"
        }
    }

    var customizeBarColors: String {
        switch self {
        case .simplifiedChineseMainland: "自定义用量配色"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "自訂用量配色"
        case .japanese: "使用量の配色をカスタマイズ"
        case .korean: "사용량 색상 사용자 지정"
        case .english: "Customize usage colors"
        }
    }

    var barColorSettingsTitle: String {
        switch self {
        case .simplifiedChineseMainland: "用量配色"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "用量配色"
        case .japanese: "使用量の配色"
        case .korean: "사용량 색상"
        case .english: "Usage Colors"
        }
    }

    var barColorSettingsExplanation: String {
        switch self {
        case .simplifiedChineseMainland: "为每个产品选择用量趋势与图例使用的颜色。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "為每個產品選擇用量趨勢與圖例使用的顏色。"
        case .japanese: "各プロダクトの使用量トレンドと凡例の色を選択します。"
        case .korean: "각 제품의 사용량 추이와 범례에 사용할 색상을 선택합니다."
        case .english: "Choose the color used by each product's usage trend and legend."
        }
    }

    var resetColor: String {
        switch self {
        case .simplifiedChineseMainland: "恢复默认"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "還原預設"
        case .japanese: "デフォルトに戻す"
        case .korean: "기본값 복원"
        case .english: "Reset"
        }
    }

    var resetAllColors: String {
        switch self {
        case .simplifiedChineseMainland: "全部恢复默认"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "全部還原預設"
        case .japanese: "すべてデフォルトに戻す"
        case .korean: "모두 기본값 복원"
        case .english: "Reset All"
        }
    }

    var photoPermissionTitle: String {
        switch self {
        case .simplifiedChineseMainland: "照片图库权限"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "照片圖庫權限"
        case .japanese: "写真ライブラリの権限"
        case .korean: "사진 보관함 권한"
        case .english: "Photo Library Permission"
        }
    }

    var photoPermissionExplanation: String {
        switch self {
        case .simplifiedChineseMainland:
            "当壁纸来自照片图库时，Codex Pulse 需要读取这张照片来计算面板文字颜色。不会上传或存储任何内容。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            "當壁紙來自照片圖庫時，Codex Pulse 需要讀取這張照片來計算面板文字顏色。不會上傳或儲存任何內容。"
        case .japanese:
            "壁紙が写真ライブラリの写真の場合、Codex Pulse はパネルの文字色を計算するためにその写真を読み取ります。アップロードや保存は行いません。"
        case .korean:
            "배경화면이 사진 보관함의 사진일 때 Codex Pulse는 패널 글자 색상을 계산하기 위해 해당 사진을 읽습니다. 업로드하거나 저장하지 않습니다."
        case .english:
            "When the wallpaper comes from your photo library, Codex Pulse reads that picture to compute the panel text color. Nothing is uploaded or stored."
        }
    }

    var photoPermissionNeededNow: String {
        switch self {
        case .simplifiedChineseMainland: "当前壁纸来自照片图库，授权后文字颜色才能自适应。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "目前壁紙來自照片圖庫，授權後文字顏色才能自動適應。"
        case .japanese: "現在の壁紙は写真ライブラリの写真です。許可すると文字色が自動的に適応します。"
        case .korean: "현재 배경화면이 사진 보관함의 사진입니다. 허용해야 글자 색상이 자동으로 적응합니다."
        case .english: "The current wallpaper is a photo-library picture; grant access so the text color can adapt."
        }
    }

    var photoPermissionNotNeededNow: String {
        switch self {
        case .simplifiedChineseMainland: "当前壁纸不是照片图库壁纸，可以暂不授权。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "目前壁紙並非照片圖庫壁紙，可以暫不授權。"
        case .japanese: "現在の壁紙は写真ライブラリの写真ではないため、今は許可しなくてもかまいません。"
        case .korean: "현재 배경화면은 사진 보관함 사진이 아니므로 지금은 허용하지 않아도 됩니다."
        case .english: "The current wallpaper does not come from the photo library, so access is not needed right now."
        }
    }

    var photoPermissionGranted: String {
        switch self {
        case .simplifiedChineseMainland: "已授权照片图库访问。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "已授權照片圖庫存取。"
        case .japanese: "写真ライブラリへのアクセスは許可済みです。"
        case .korean: "사진 보관함 접근이 이미 허용되어 있습니다."
        case .english: "Photo library access is already granted."
        }
    }

    var photoPermissionDenied: String {
        switch self {
        case .simplifiedChineseMainland: "此前已拒绝授权，请在系统设置中开启。"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "先前已拒絕授權，請在系統設定中開啟。"
        case .japanese: "以前に拒否されています。システム設定で許可してください。"
        case .korean: "이전에 거부되었습니다. 시스템 설정에서 허용해 주세요."
        case .english: "Access was previously declined; enable it in System Settings."
        }
    }

    var authorize: String {
        switch self {
        case .simplifiedChineseMainland: "授权"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "授權"
        case .japanese: "許可"
        case .korean: "허용"
        case .english: "Grant Access"
        }
    }

    var openSystemSettings: String {
        switch self {
        case .simplifiedChineseMainland: "打开系统设置"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "開啟系統設定"
        case .japanese: "システム設定を開く"
        case .korean: "시스템 설정 열기"
        case .english: "Open System Settings"
        }
    }

    var notNow: String {
        switch self {
        case .simplifiedChineseMainland: "暂不"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "暫不"
        case .japanese: "今はしない"
        case .korean: "나중에"
        case .english: "Not Now"
        }
    }

    var okButton: String {
        switch self {
        case .simplifiedChineseMainland: "好"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "好"
        case .japanese: "OK"
        case .korean: "확인"
        case .english: "OK"
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

    var pausedTask: String {
        switch self {
        case .simplifiedChineseMainland: "任务已暂停"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "任務已暫停"
        case .japanese: "タスク一時停止"
        case .korean: "작업 일시 정지됨"
        case .english: "Task paused"
        }
    }

    var terminatedTask: String {
        switch self {
        case .simplifiedChineseMainland: "任务已终止"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "任務已終止"
        case .japanese: "タスク終了"
        case .korean: "작업 종료됨"
        case .english: "Task terminated"
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

    func resetText(
        _ date: Date,
        relativeTo now: Date = .now,
        calendar: Calendar = .autoupdatingCurrent,
        includesTime: Bool = true
    ) -> String {
        let style = Date.FormatStyle(
            locale: locale,
            calendar: calendar,
            timeZone: calendar.timeZone
        )
        let day: String
        if calendar.isDate(date, inSameDayAs: now) {
            day = today
        } else if let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: now),
                  calendar.isDate(date, inSameDayAs: tomorrowDate) {
            day = tomorrow
        } else {
            day = date.formatted(style.month().day())
        }
        let value = if includesTime {
            "\(day) \(date.formatted(style.hour().minute()))"
        } else {
            day
        }
        return switch self {
        case .simplifiedChineseMainland: "重置 \(value)"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "重設 \(value)"
        case .japanese: "リセット \(value)"
        case .korean: "재설정 \(value)"
        case .english: "Resets \(value)"
        }
    }

    func remainingAvailable(_ value: Double) -> String {
        switch self {
        case .simplifiedChineseMainland: String(format: "剩余可用 %.1f%%", locale: locale, value)
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            String(format: "剩餘可用 %.1f%%", locale: locale, value)
        case .japanese: String(format: "利用可能残量 %.1f%%", locale: locale, value)
        case .korean: String(format: "남은 사용 가능량 %.1f%%", locale: locale, value)
        case .english: String(format: "Remaining available %.1f%%", locale: locale, value)
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

    var loadingUsage: String {
        switch self {
        case .simplifiedChineseMainland: "用量信息加载中，请稍后"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "用量資訊載入中，請稍候"
        case .japanese: "使用量を読み込み中です。お待ちください"
        case .korean: "사용량 불러오는 중입니다. 잠시만 기다려 주세요"
        case .english: "Loading usage, please wait…"
        }
    }

    func weeklyWindowConsumedTokens(_ value: String) -> String {
        switch self {
        case .simplifiedChineseMainland: "本周期消耗 \(value)"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan: "本週期消耗 \(value)"
        case .japanese: "今サイクル消費 \(value)"
        case .korean: "이번 주기 사용 \(value)"
        case .english: "This cycle \(value)"
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

    /// Narrow-panel variant of `countdown`: same units, no leading label.
    func countdownCompact(days: Int, hours: Int, minutes: Int) -> String {
        switch self {
        case .simplifiedChineseMainland:
            if days > 0 { return "\(days)天 \(hours)小时" }
            if hours > 0 { return "\(hours)小时 \(minutes)分钟" }
            if minutes > 0 { return "\(minutes)分钟" }
            return "<1分钟"
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            if days > 0 { return "\(days)日 \(hours)小時" }
            if hours > 0 { return "\(hours)小時 \(minutes)分鐘" }
            if minutes > 0 { return "\(minutes)分鐘" }
            return "<1分鐘"
        case .japanese:
            if days > 0 { return "\(days)日 \(hours)時間" }
            if hours > 0 { return "\(hours)時間 \(minutes)分" }
            if minutes > 0 { return "\(minutes)分" }
            return "1分未満"
        case .korean:
            if days > 0 { return "\(days)일 \(hours)시간" }
            if hours > 0 { return "\(hours)시간 \(minutes)분" }
            if minutes > 0 { return "\(minutes)분" }
            return "1분 미만"
        case .english:
            if days > 0 { return "\(days)d \(hours)h" }
            if hours > 0 { return "\(hours)h \(minutes)m" }
            if minutes > 0 { return "\(minutes)m" }
            return "<1m"
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

    func alignTaskActivityText(to alignment: TaskActivityTextAlignment) -> String {
        switch self {
        case .simplifiedChineseMainland:
            switch alignment {
            case .auto: "自动对齐任务活动面板文字"
            case .left: "左对齐任务活动面板文字"
            case .right: "右对齐任务活动面板文字"
            }
        case .traditionalChineseHongKong, .traditionalChineseTaiwan:
            switch alignment {
            case .auto: "自動對齊任務活動面板文字"
            case .left: "將任務活動面板文字靠左對齊"
            case .right: "將任務活動面板文字靠右對齊"
            }
        case .japanese:
            switch alignment {
            case .auto: "タスクアクティビティパネルの文字を自動配置する"
            case .left: "タスクアクティビティパネルの文字を左揃えにする"
            case .right: "タスクアクティビティパネルの文字を右揃えにする"
            }
        case .korean:
            switch alignment {
            case .auto: "작업 활동 패널 텍스트 자동 정렬"
            case .left: "작업 활동 패널 텍스트 왼쪽 정렬"
            case .right: "작업 활동 패널 텍스트 오른쪽 정렬"
            }
        case .english:
            switch alignment {
            case .auto: "Automatically align Task Activity Panel text"
            case .left: "Left-align Task Activity Panel text"
            case .right: "Right-align Task Activity Panel text"
            }
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
