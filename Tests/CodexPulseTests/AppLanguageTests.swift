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
        #expect(!language.tomorrow.isEmpty)
        #expect(!language.weeklyLimit.isEmpty)
        #expect(!language.noRecentTasks.isEmpty)
        #expect(!language.changeLanguage.isEmpty)
        #expect(!language.languagePickerLabel.isEmpty)
        #expect(!language.runningTask.isEmpty)
        #expect(!language.completedTask.isEmpty)
        #expect(!language.pausedTask.isEmpty)
        #expect(!language.terminatedTask.isEmpty)
        #expect(language.usedPercent(42).contains("42%"))
        #expect(language.remainingPercent(58).contains("58%"))
        #expect(language.remainingAvailable(58).contains("58"))
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
    #expect(AppLanguage.simplifiedChineseMainland.remainingAvailable(58) == "剩余可用 58.0%")
}

@Test func countdownAndDatesUseTheSelectedLanguage() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reset = now.addingTimeInterval(3_661)

    #expect(WeeklyLimitCountdown.format(reset: reset, now: now) == "倒计时 1小时 1分钟")
    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, language: .english) == "Remaining 1h 1m")
    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, language: .japanese) == "残り 1時間 1分")
    #expect(AppLanguage.english.shortDate(now) != AppLanguage.japanese.shortDate(now))
}

@Test func compactCountdownDropsTheLeadingLabel() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reset = now.addingTimeInterval(3_661)

    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, compact: true) == "1小时 1分钟")
    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, language: .english, compact: true) == "1h 1m")
    #expect(WeeklyLimitCountdown.format(reset: reset, now: now, language: .korean, compact: true) == "1시간 1분")

    let underMinute = now.addingTimeInterval(30)
    #expect(WeeklyLimitCountdown.format(reset: underMinute, now: now, compact: true) == "<1分钟")
}

@Test func resetTextUsesRelativeDaysAndKeepsTimeOnlyAtRegularWidth() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let now = try #require(calendar.date(from: DateComponents(
        year: 2026, month: 8, day: 8, hour: 10
    )))
    let today = try #require(calendar.date(from: DateComponents(
        year: 2026, month: 8, day: 8, hour: 18, minute: 5
    )))
    let tomorrow = try #require(calendar.date(from: DateComponents(
        year: 2026, month: 8, day: 9, hour: 7, minute: 9
    )))
    let later = try #require(calendar.date(from: DateComponents(
        year: 2026, month: 8, day: 12, hour: 9, minute: 7
    )))
    let language = AppLanguage.simplifiedChineseMainland

    #expect(language.resetText(today, relativeTo: now, calendar: calendar) == "重置 今日 18:05")
    #expect(language.resetText(tomorrow, relativeTo: now, calendar: calendar) == "重置 明日 07:09")
    #expect(language.resetText(later, relativeTo: now, calendar: calendar) == "重置 8月12日 09:07")
    #expect(language.resetText(
        today, relativeTo: now, calendar: calendar, includesTime: false
    ) == "重置 今日")
    #expect(language.resetText(
        tomorrow, relativeTo: now, calendar: calendar, includesTime: false
    ) == "重置 明日")
    #expect(language.resetText(
        later, relativeTo: now, calendar: calendar, includesTime: false
    ) == "重置 8月12日")
}
