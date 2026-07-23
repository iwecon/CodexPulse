import Testing
import Foundation
@testable import CodexPulse

@Test func pricingAndJSON() {
    let u = Usage(input: 1_000_000, output: 1_000_000)
    #expect(Pricing.forModel("openai/gpt-5").cost(u) == 11.25)
    #expect(UsageScanner.object(#"{"type":"assistant"}"#[...])?["type"] as? String == "assistant")
}

@Test func compactTokenUnitsIncludeMillionsBillionsAndTrillions() {
    #expect(UsageModel.compact(1_500_000) == "1.5M")
    #expect(UsageModel.compact(2_500_000_000) == "2.5B")
    #expect(UsageModel.compact(3_500_000_000_000) == "3.5T")
}

@Test func weeklyLimitPacingUsesExactRemainingTime() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    #expect(WeeklyLimitPacing.averageDailyAvailablePercent(
        usedPercent: 25,
        resetsAt: now.addingTimeInterval(3 * 86_400),
        now: now
    ) == 25)
    #expect(WeeklyLimitPacing.averageDailyAvailablePercent(
        usedPercent: 50,
        resetsAt: now.addingTimeInterval(12 * 3_600),
        now: now
    ) == 100)
}

@Test func weeklyLimitPacingClampsQuotaAndExpiredWindows() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    #expect(WeeklyLimitPacing.averageDailyAvailablePercent(
        usedPercent: 120,
        resetsAt: now.addingTimeInterval(86_400),
        now: now
    ) == 0)
    #expect(WeeklyLimitPacing.averageDailyAvailablePercent(
        usedPercent: -20,
        resetsAt: now,
        now: now
    ) == 0)
}

@Test func weeklyLimitCountdownUsesLargestRelevantUnits() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    #expect(WeeklyLimitCountdown.format(
        reset: now.addingTimeInterval(5 * 86_400 + 16 * 3_600 + 32 * 60 + 45),
        now: now
    ) == "倒计时 5天 16小时")
    #expect(WeeklyLimitCountdown.format(
        reset: now.addingTimeInterval(16 * 3_600 + 32 * 60 + 59),
        now: now
    ) == "倒计时 16小时 32分钟")
    #expect(WeeklyLimitCountdown.format(
        reset: now.addingTimeInterval(10 * 60 + 59),
        now: now
    ) == "倒计时 10分钟")
    #expect(WeeklyLimitCountdown.format(
        reset: now.addingTimeInterval(59),
        now: now
    ) == "倒计时 小于1分钟")
    #expect(WeeklyLimitCountdown.format(
        reset: now.addingTimeInterval(-1),
        now: now
    ) == "倒计时 小于1分钟")
}

@Test func dailyUsageAlwaysCoversFourteenCalendarDays() {
    let calendar = Calendar(identifier: .gregorian)
    let now = Date(timeIntervalSince1970: 1_750_000_000)
    let today = calendar.startOfDay(for: now)
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let usage = Usage(input: 120, output: 30)
    let result = UsageScanner.last14Days(claude: [yesterday: usage], codex: [:], openCode: [:], now: now)

    #expect(result.count == 14)
    #expect(result.last?.date == today)
    #expect(result[result.count - 2].total == 150)
}

@Test func codexCumulativeUsageSeparatesCachedInputBeforeComputingDelta() {
    let first = UsageScanner.codexCumulativeUsage([
        "input_tokens": 100,
        "cached_input_tokens": 80,
        "output_tokens": 10,
    ])
    let second = UsageScanner.codexCumulativeUsage([
        "input_tokens": 150,
        "cached_input_tokens": 120,
        "output_tokens": 25,
    ])

    #expect(first.input == 20)
    #expect(first.cacheRead == 80)
    #expect(first.total == 110)

    let delta = UsageScanner.codexDelta(current: second, previous: first)
    #expect(delta.input == 10)
    #expect(delta.cacheRead == 40)
    #expect(delta.output == 15)
    #expect(delta.total == 65)
}

@Test func codexCumulativeUsageClampsCachedInputThatExceedsInput() {
    let usage = UsageScanner.codexCumulativeUsage([
        "input_tokens": 20,
        "cached_input_tokens": 30,
        "output_tokens": 5,
    ])

    #expect(usage.input == 0)
    #expect(usage.cacheRead == 30)
    #expect(usage.total == 35)
}

@Test func completedTaskRemainsVisibleForTenMinutes() {
    let start = #"{"timestamp":"2026-07-23T10:00:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":1784800800}}"#
    let completion = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"task_complete","turn_id":"turn-1","started_at":1784800800,"completed_at":1784800860}}"#
    let started = TaskMonitor.parseEvent(start[...], threadID: "thread-1", title: "构建应用")
    let completed = TaskMonitor.parseEvent(completion[...], threadID: "thread-1", title: "构建应用")

    #expect(started?.id == "turn-1")
    guard case .completed(let completedAt) = completed?.kind else {
        Issue.record("Expected a completion event")
        return
    }
    let task = TaskExecution(
        id: "turn-1",
        threadID: "thread-1",
        title: "构建应用",
        startedAt: started!.startedAt,
        completedAt: completedAt
    )
    #expect(TaskMonitor.visible([task.id: task], now: completedAt.addingTimeInterval(599)).count == 1)
    #expect(TaskMonitor.visible([task.id: task], now: completedAt.addingTimeInterval(600)).count == 1)
    #expect(TaskMonitor.visible([task.id: task], now: completedAt.addingTimeInterval(601)).isEmpty)
}

@Test func allCompletionsFromLastTenMinutesAppearOldestFirst() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let tasks = Dictionary(uniqueKeysWithValues: (0..<6).map { index in
        let id = "completed-\(index)"
        return (id, TaskExecution(
            id: id,
            threadID: "thread-\(index)",
            title: id,
            startedAt: base.addingTimeInterval(Double(index * 10)),
            completedAt: base.addingTimeInterval(Double(index * 10 + 5))
        ))
    })

    let visible = TaskMonitor.visible(tasks, now: base.addingTimeInterval(604))
    #expect(visible.map(\.id) == (0..<6).map { "completed-\($0)" })
}

@Test func runningTasksAreRetainedAndPrioritizedAfterRecentCompletions() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    var tasks: [String: TaskExecution] = [:]
    for index in 0..<6 {
        let id = "task-\(index)"
        tasks[id] = TaskExecution(
            id: id,
            threadID: "thread-\(index)",
            title: id,
            startedAt: base.addingTimeInterval(Double(index)),
            completedAt: index == 0 ? base.addingTimeInterval(0.5) : nil
        )
    }

    let visible = TaskMonitor.visible(tasks, now: base.addingTimeInterval(10))
    #expect(visible.count == 6)
    #expect(visible.map(\.id) == ["task-0", "task-1", "task-2", "task-3", "task-4", "task-5"])
}

@Test func runningTaskRemainsVisibleAfterTenMinutes() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let task = TaskExecution(
        id: "running",
        threadID: "thread",
        title: "长时间任务",
        startedAt: base,
        completedAt: nil
    )

    let visible = TaskMonitor.visible(
        [task.id: task],
        now: base.addingTimeInterval(60 * 60)
    )

    #expect(visible.map(\.id) == ["running"])
}

@Test func abortedTaskEventIsRecognized() {
    let aborted = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","completed_at":1784800860,"reason":"interrupted"}}"#
    let event = TaskMonitor.parseEvent(aborted[...], threadID: "thread-1", title: "构建应用")

    #expect(event?.id == "turn-1")
    guard case .aborted(let abortedAt) = event?.kind else {
        Issue.record("Expected an aborted event")
        return
    }
    #expect(abortedAt == Date(timeIntervalSince1970: 1_784_800_860))
}

@Test func userMessageAndProjectMetadataAreParsed() {
    let line = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"user_message","message":"第一行\n第二行"}}"#
    let event = TaskMonitor.parseEvent(
        line[...],
        threadID: "thread-1",
        title: "Session",
        projectName: "Codex Pulse"
    )

    #expect(event?.projectName == "Codex Pulse")
    guard case .userMessage(let message, _) = event?.kind else {
        Issue.record("Expected a user-message event")
        return
    }
    #expect(message == "第一行 第二行")
    #expect(TaskMonitor.projectName(from: "/Users/i/project/Codex Pulse") == "Codex Pulse")
}

@Test func overlappingTaskThatCompletesLastRemainsVisible() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let older = TaskExecution(
        id: "older",
        threadID: "thread-1",
        title: "较早开始",
        startedAt: base,
        completedAt: base.addingTimeInterval(20)
    )
    let newer = TaskExecution(
        id: "newer",
        threadID: "thread-2",
        title: "稍后开始",
        startedAt: base.addingTimeInterval(10),
        completedAt: nil
    )

    let visible = TaskMonitor.visible(
        [older.id: older, newer.id: newer],
        now: base.addingTimeInterval(30)
    )
    #expect(visible.map(\.id) == ["older", "newer"])
}

@Test func newRunningTaskAppendsToItsSessionWithoutClearingRecentTasks() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let completedInSession = TaskExecution(
        id: "completed-in-session",
        threadID: "thread-1",
        title: "Session 1",
        projectName: "Codex Pulse",
        startedAt: base,
        completedAt: base.addingTimeInterval(5)
    )
    let completedElsewhere = TaskExecution(
        id: "completed-elsewhere",
        threadID: "thread-2",
        title: "Session 2",
        projectName: "Codex Pulse",
        startedAt: base.addingTimeInterval(10),
        completedAt: base.addingTimeInterval(15)
    )
    let runningInSession = TaskExecution(
        id: "running-in-session",
        threadID: "thread-1",
        title: "Session 1",
        projectName: "Codex Pulse",
        startedAt: base.addingTimeInterval(20),
        completedAt: nil
    )

    let visible = TaskMonitor.visible(
        [
            completedInSession.id: completedInSession,
            completedElsewhere.id: completedElsewhere,
            runningInSession.id: runningInSession,
        ],
        now: base.addingTimeInterval(30)
    )
    let plan = TaskExecutionLayout.plan(for: visible)

    #expect(visible.map(\.id) == ["completed-in-session", "completed-elsewhere", "running-in-session"])
    #expect(plan.projects.first?.sessions.first(where: { $0.id == "thread-1" })?.tasks.map(\.id) == [
        "completed-in-session",
        "running-in-session",
    ])
}

@Test func codexThreadURLPercentEncodesPathComponents() {
    #expect(CodexThreadLink.url(threadID: "thread/with space")?.absoluteString == "codex://threads/thread%2Fwith%20space")
}

@Test func parsesISOAndMillisecondDates() {
    let iso = UsageScanner.date("2026-07-23T10:15:30Z")
    let fractionalISO = UsageScanner.date("2026-07-23T10:15:30.123Z")
    let milliseconds = UsageScanner.date(1_774_000_000_000 as NSNumber)

    #expect(iso != nil)
    #expect(fractionalISO != nil)
    #expect(milliseconds == Date(timeIntervalSince1970: 1_774_000_000))
}

@Test func codexRateLimitsUseNewestObservationRegardlessOfFileOrder() {
    let older: [String: Any] = [
        "primary": ["used_percent": 53, "window_minutes": 10_080, "resets_at": 1_784_668_630]
    ]
    let newer: [String: Any] = [
        "primary": ["used_percent": 14, "window_minutes": 10_080, "resets_at": 1_785_258_729]
    ]
    let olderDate = Date(timeIntervalSince1970: 1_784_500_000)
    let newerDate = Date(timeIntervalSince1970: 1_785_000_000)
    var limits: [Int: RateWindow] = [:]

    UsageScanner.mergeRateLimits(newer, observedAt: newerDate, into: &limits)
    UsageScanner.mergeRateLimits(older, observedAt: olderDate, into: &limits)

    #expect(limits[10_080]?.used == 14)
    #expect(limits[10_080]?.observedAt == newerDate)
    #expect(limits[10_080]?.resetsAt == Date(timeIntervalSince1970: 1_785_258_729))
}

@Test func JSONLineReaderStreamsAcrossSmallChunksAndSkipsOversizedLines() throws {
    let directory = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appending(path: "events.jsonl")
    try "{\"id\":1}\nthis-line-is-too-long\n{\"id\":2}".data(using: .utf8)!.write(to: file)

    var lines: [String] = []
    try UsageScanner.forEachJSONLine(in: file, chunkSize: 5, maximumLineLength: 12) {
        lines.append(String($0))
    }

    #expect(lines == [#"{"id":1}"#, #"{"id":2}"#])
}

@Test func usageScannerReusesUnchangedJSONFilesAndInvalidatesChangedFiles() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let file = projects.appending(path: "session.jsonl")
    let first = #"{"type":"assistant","timestamp":"2026-07-23T10:00:00Z","message":{"id":"message-1","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":2}}}"#
    try (first + "\n").data(using: .utf8)!.write(to: file)
    let scanner = UsageScanner(home: home, enabledTools: [.claude, .codex])

    let initial = await scanner.scan()
    let firstStatistics = await scanner.scanStatistics()
    let unchanged = await scanner.scan()
    let unchangedStatistics = await scanner.scanStatistics()
    #expect(initial.usage[.claude]?.total == 12)
    #expect(unchanged.usage[.claude]?.total == 12)
    #expect(firstStatistics.parsedJSONFiles == 1)
    #expect(unchangedStatistics.parsedJSONFiles == 1)

    let second = #"{"type":"assistant","timestamp":"2026-07-23T10:01:00Z","message":{"id":"message-1","model":"claude-sonnet","usage":{"input_tokens":20,"output_tokens":5}}}"#
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: (second + "\n").data(using: .utf8)!)
    try handle.close()

    let changed = await scanner.scan()
    let changedStatistics = await scanner.scanStatistics()
    #expect(changed.usage[.claude]?.total == 25)
    #expect(changedStatistics.parsedJSONFiles == 2)
}

@Test func usageScannerDefaultsToCodexOnly() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let claude = #"{"type":"assistant","timestamp":"2026-07-23T10:00:00Z","message":{"id":"message-1","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":2}}}"#
    try (claude + "\n").data(using: .utf8)!.write(to: projects.appending(path: "session.jsonl"))
    let codex = #"{"timestamp":"2026-07-23T10:00:00Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":5,"output_tokens":3}}}}"#
    try (codex + "\n").data(using: .utf8)!.write(to: sessions.appending(path: "session.jsonl"))

    let scanner = UsageScanner(home: home)
    let snapshot = await scanner.scan()
    let statistics = await scanner.scanStatistics()

    #expect(snapshot.usage[.codex]?.total == 23)
    #expect(snapshot.usage[.claude] == nil)
    #expect(snapshot.usage[.opencode] == nil)
    #expect(snapshot.errors[.claude] == nil)
    #expect(snapshot.errors[.opencode] == nil)
    #expect(snapshot.dailyUsage.allSatisfy { Set($0.usage.keys) == [.codex] })
    #expect(statistics.parsedJSONFiles == 1)
}
