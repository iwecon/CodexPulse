import Foundation
import Testing
@testable import CodexPulse

@Test func appLanguageEnumerationContainsExactlyTheSupportedLocales() {
    #expect(AppLanguage.allCases.map(\.rawValue) == [
        "zh-Hans-CN",
        "zh-Hant-HK",
        "zh-Hant-TW",
        "ja-JP",
        "ko-KR",
        "en",
    ])
    #expect(Set(AppLanguage.allCases.map(\.displayName)).count == 6)
}

@Test func appLanguagePreferenceDefaultsPersistsAndRejectsUnknownValues() throws {
    let suiteName = "AppLanguageTests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    #expect(AppLanguagePreference(defaults: defaults).language == .simplifiedChineseMainland)

    AppLanguagePreference(language: .traditionalChineseTaiwan).save(to: defaults)
    #expect(AppLanguagePreference(defaults: defaults).language == .traditionalChineseTaiwan)

    defaults.set("unsupported", forKey: AppLanguagePreference.defaultsKey)
    #expect(AppLanguagePreference(defaults: defaults).language == .simplifiedChineseMainland)
}

@Test func everyLanguageProvidesLocalizedPanelAndControlCopy() {
    for language in AppLanguage.allCases {
        #expect(!language.recentFourteenDays.isEmpty)
        #expect(!language.weeklyLimit.isEmpty)
        #expect(!language.noRecentTasks.isEmpty)
        #expect(!language.changeLanguage.isEmpty)
        #expect(!language.languagePickerLabel.isEmpty)
        #expect(!language.runningTask.isEmpty)
        #expect(!language.completedTask.isEmpty)
        #expect(language.usedPercent(42).contains("42%"))
        #expect(language.remainingPercent(58).contains("58%"))
        #expect(language.tokenCount(123).contains("123"))
        #expect(!language.movePanel(.usageOverview, to: .right).isEmpty)
        #expect(!language.swapPanelOrder(.taskActivity).isEmpty)
        for alignment in TaskActivityTextAlignment.allCases {
            #expect(!language.alignTaskActivityText(to: alignment).isEmpty)
        }
        #expect(!language.resizeLabel(.usageOverview, tooltip: true).isEmpty)
        #expect(!language.openSession("Session").isEmpty)
    }

    #expect(AppLanguage.simplifiedChineseMainland.noData == "暂无数据")
    #expect(AppLanguage.traditionalChineseHongKong.noData == "暫無資料")
    #expect(AppLanguage.japanese.noData == "データなし")
    #expect(AppLanguage.korean.noData == "데이터 없음")
    #expect(AppLanguage.english.noData == "No data")
}

@Test func countdownAndDatesUseTheSelectedLanguage() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reset = now.addingTimeInterval(3_661)

    #expect(WeeklyLimitCountdown.format(reset: reset, now: now) == "倒计时 1小时 1分钟")
    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, language: .english) == "Remaining 1h 1m")
    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, language: .japanese) == "残り 1時間 1分")
    #expect(AppLanguage.english.shortDate(now) != AppLanguage.japanese.shortDate(now))
}
