import Testing
import CSQLite
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

@Test func weeklyLimitPacingSwitchesToRemainingAvailabilityWithinOneDay() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    #expect(WeeklyLimitPacing.availability(
        usedPercent: 25,
        resetsAt: now.addingTimeInterval(3 * 86_400),
        now: now
    ) == .averageDaily(25))
    #expect(WeeklyLimitPacing.availability(
        usedPercent: 25,
        resetsAt: now.addingTimeInterval(86_400),
        now: now
    ) == .averageDaily(75))
    #expect(WeeklyLimitPacing.availability(
        usedPercent: 25,
        resetsAt: now.addingTimeInterval(12 * 3_600),
        now: now
    ) == .remaining(75))
}

@Test func weeklyLimitPacingClampsQuotaAndExpiredWindows() {
    let now = Date(timeIntervalSince1970: 1_780_000_000)

    #expect(WeeklyLimitPacing.availability(
        usedPercent: 120,
        resetsAt: now.addingTimeInterval(86_400),
        now: now
    ) == .averageDaily(0))
    #expect(WeeklyLimitPacing.availability(
        usedPercent: -20,
        resetsAt: now,
        now: now
    ) == .remaining(0))
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

@Test func codexTokenCountParserExtractsOnlyRequiredFieldsWithoutObjectDecoding() {
    let line = #"""
    {
        "ignored": {"nested": [true, null, {"value": "text"}]},
        "payload": {
            "rate_limits": {
                "secondary": {"used_percent": 4.25e1, "resets_at": 1785110400, "window_minutes": 10080},
                "limit_id": "codex"
            },
            "info": {
                "last_token_usage": {"output_tokens": 5, "cached_input_tokens": 10, "input_tokens": 30},
                "total_token_usage": {"output_tokens": 25, "cached_input_tokens": 50, "input_tokens": 250}
            },
            "type": "token_count"
        },
        "type": "event_msg",
        "timestamp": "2026-07-23T18:00:01.125+08:00"
    }
    """#
    let data = Data(line.utf8)
    let event = CodexTokenCountParser.parse(data[data.startIndex..<data.endIndex])

    #expect(event?.observedAt == Date(timeIntervalSince1970: 1_784_800_801.125))
    #expect(event?.cumulative?.input == 200)
    #expect(event?.cumulative?.cacheRead == 50)
    #expect(event?.cumulative?.output == 25)
    #expect(event?.last?.input == 20)
    #expect(event?.last?.cacheRead == 10)
    #expect(event?.last?.output == 5)
    #expect(event?.rateLimits?.isAccountLimit == true)
    #expect(event?.rateLimits?.secondary?.minutes == 10_080)
    #expect(event?.rateLimits?.secondary?.usedPercent == 42.5)
    #expect(event?.rateLimits?.secondary?.resetsAt == 1_785_110_400)
}

@Test func codexTokenCountParserRejectsMarkerInsideUnrelatedContent() {
    let line = #"{"timestamp":"2026-07-23T10:00:00Z","type":"response_item","payload":{"type":"message","content":{"type":"token_count"}}}"#
    let data = Data(line.utf8)

    #expect(CodexTokenCountParser.parse(data[data.startIndex..<data.endIndex]) == nil)
}

@Test func codexSubagentFirstEventCountsOnlyLastTokenUsage() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    // A subagent rollout inherits the parent thread's cumulative counter, so the
    // first total_token_usage is huge; last_token_usage holds the real increment.
    let lines = [
        #"{"timestamp":"2026-07-23T10:00:00Z","type":"session_meta","payload":{"session_id":"parent-1","id":"child-1"}}"#,
        #"{"timestamp":"2026-07-23T10:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":25000100,"cached_input_tokens":25000000,"output_tokens":500},"last_token_usage":{"input_tokens":100,"cached_input_tokens":80,"output_tokens":10}}}}"#,
        #"{"timestamp":"2026-07-23T10:00:02Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":25000400,"cached_input_tokens":25000200,"output_tokens":550},"last_token_usage":{"input_tokens":300,"cached_input_tokens":200,"output_tokens":50}}}}"#,
    ]
    try (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: sessions.appending(path: "child.jsonl"))

    let snapshot = await UsageScanner(home: home, enabledTools: [.codex]).scan(
        now: UsageScanner.date("2026-07-24T00:00:00Z")!
    )

    // First event: input 100-80=20, cacheRead 80, output 10 (not the 25M baseline).
    // Second event: cumulative delta input 100, cacheRead 200, output 50.
    #expect(snapshot.usage[.codex]?.input == 120)
    #expect(snapshot.usage[.codex]?.cacheRead == 280)
    #expect(snapshot.usage[.codex]?.output == 60)
    #expect(snapshot.usage[.codex]?.total == 460)
}

@Test func codexReplayedEventsAcrossFilesAreCountedOnceWithEarliestDate() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    let archived = home.appending(path: ".codex/archived_sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: archived, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let event = #""payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":200,"cached_input_tokens":50,"output_tokens":30},"last_token_usage":{"input_tokens":200,"cached_input_tokens":50,"output_tokens":30}}}"#
    let originalEventDate = Date.now.addingTimeInterval(-2 * 86_400)
    let parentMetaTimestamp = originalEventDate.addingTimeInterval(-1).formatted(.iso8601)
    let originalTimestamp = originalEventDate.formatted(.iso8601)
    let replayTimestamp = originalEventDate.addingTimeInterval(86_400).formatted(.iso8601)
    let parent = [
        #"{"timestamp":"\#(parentMetaTimestamp)","type":"session_meta","payload":{"session_id":"thread-1","id":"thread-1"}}"#,
        #"{"timestamp":"\#(originalTimestamp)","type":"event_msg",\#(event)}"#,
    ]
    // An archived subagent rollout replays the same event under a fresh
    // timestamp on a later day.
    let child = [
        #"{"timestamp":"\#(replayTimestamp)","type":"session_meta","payload":{"session_id":"thread-1","id":"thread-2"}}"#,
        #"{"timestamp":"\#(replayTimestamp)","type":"event_msg",\#(event)}"#,
    ]
    try (parent.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: sessions.appending(path: "parent.jsonl"))
    try (child.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: archived.appending(path: "child.jsonl"))

    let snapshot = await UsageScanner(home: home, enabledTools: [.codex]).scan()

    #expect(snapshot.usage[.codex]?.total == 230)
    #expect(snapshot.usage[.codex]?.requests == 1)
    let original = Calendar.current.startOfDay(for: originalEventDate)
    #expect(snapshot.dailyUsage.reduce(0) { $0 + $1.total } == 230)
    #expect(snapshot.dailyUsage.first(where: { $0.date == original })?.total == 230)
}

@Test func codexWeeklyWindowTokensCountOnlyRecordsInsideTheResetWindow() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    // resets_at 2026-07-27T00:00:00Z with a 10 080-minute window puts the
    // window start at 2026-07-20T00:00:00Z.
    let outside = [
        #"{"timestamp":"2026-07-19T23:00:00Z","type":"session_meta","payload":{"session_id":"old","id":"old"}}"#,
        #"{"timestamp":"2026-07-19T23:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":0},"last_token_usage":{"input_tokens":100,"cached_input_tokens":0,"output_tokens":0}}}}"#,
    ]
    let inside = [
        #"{"timestamp":"2026-07-21T10:00:00Z","type":"session_meta","payload":{"session_id":"new","id":"new"}}"#,
        #"{"timestamp":"2026-07-21T10:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":200,"cached_input_tokens":50,"output_tokens":30},"last_token_usage":{"input_tokens":200,"cached_input_tokens":50,"output_tokens":30}},"rate_limits":{"secondary":{"window_minutes":10080,"resets_at":1785110400,"used_percent":40}}}}"#,
    ]
    try (outside.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: sessions.appending(path: "outside.jsonl"))
    try (inside.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: sessions.appending(path: "inside.jsonl"))

    let snapshot = await UsageScanner(home: home, enabledTools: [.codex]).scan(
        now: UsageScanner.date("2026-07-23T00:00:00Z")!
    )

    #expect(snapshot.usage[.codex]?.total == 330)
    #expect(snapshot.codexTokensInWeeklyWindow == 230)
}

@Test func codexWeeklyWindowTokensAreNilWithoutAWeeklyRateWindow() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let lines = [
        #"{"timestamp":"2026-07-21T10:00:00Z","type":"session_meta","payload":{"session_id":"s","id":"s"}}"#,
        #"{"timestamp":"2026-07-21T10:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5},"last_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5}},"rate_limits":{"primary":{"window_minutes":300,"resets_at":1785110400,"used_percent":10}}}}"#,
    ]
    try (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: sessions.appending(path: "session.jsonl"))

    let snapshot = await UsageScanner(home: home, enabledTools: [.codex]).scan(
        now: UsageScanner.date("2026-07-23T00:00:00Z")!
    )

    #expect(snapshot.usage[.codex]?.total == 15)
    #expect(snapshot.codexTokensInWeeklyWindow == nil)
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
    let aborted = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","started_at":1784800800,"completed_at":1784800860,"reason":"interrupted"}}"#
    let event = TaskMonitor.parseEvent(aborted[...], threadID: "thread-1", title: "构建应用")

    #expect(event?.id == "turn-1")
    guard case .aborted(let abortedAt) = event?.kind else {
        Issue.record("Expected an aborted event")
        return
    }
    #expect(abortedAt == Date(timeIntervalSince1970: 1_784_800_860))
    #expect(event?.startedAt == Date(timeIntervalSince1970: 1_784_800_800))
}

@Test func userAbortedTaskIsTerminated() {
    let start = #"{"timestamp":"2026-07-23T10:00:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":1784800800}}"#
    let abort = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","started_at":1784800800,"completed_at":1784800860,"reason":"interrupted"}}"#
    var tasks: [String: TaskExecution] = [:]
    var pending: [String: String] = [:]

    for line in [start, abort] {
        guard let event = TaskMonitor.parseEvent(line[...], threadID: "thread-1", title: "构建应用") else {
            Issue.record("Expected a task event")
            return
        }
        TaskMonitor.apply(event, to: &tasks, pendingUserMessages: &pending)
    }

    #expect(tasks["turn-1"]?.status == .terminated)
    #expect(tasks["turn-1"]?.completedAt == Date(timeIntervalSince1970: 1_784_800_860))
}

@Test func pausedGoalReclassifiesTheMostRecentAbortedTask() {
    let start = #"{"timestamp":"2026-07-23T10:00:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":1784800800}}"#
    let abort = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","started_at":1784800800,"completed_at":1784800860,"reason":"interrupted"}}"#
    let pause = #"{"timestamp":"2026-07-23T10:01:00.250Z","type":"event_msg","payload":{"type":"thread_goal_updated","threadId":"thread-1","goal":{"status":"paused"}}}"#
    var tasks: [String: TaskExecution] = [:]
    var pending: [String: String] = [:]

    for line in [start, abort, pause] {
        guard let event = TaskMonitor.parseEvent(line[...], threadID: "thread-1", title: "构建应用") else {
            Issue.record("Expected a task or goal event")
            return
        }
        TaskMonitor.apply(event, to: &tasks, pendingUserMessages: &pending)
    }

    #expect(tasks["turn-1"]?.status == .paused)
    #expect(tasks["turn-1"]?.completedAt == Date(timeIntervalSince1970: 1_784_800_860.25))
}

@Test func pausedGoalPausesTheCurrentlyRunningTask() {
    let start = #"{"timestamp":"2026-07-23T10:00:00Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":1784800800}}"#
    let pause = #"{"timestamp":"2026-07-23T10:01:00Z","type":"event_msg","payload":{"type":"thread_goal_updated","threadId":"thread-1","goal":{"status":"paused"}}}"#
    var tasks: [String: TaskExecution] = [:]
    var pending: [String: String] = [:]

    for line in [start, pause] {
        guard let event = TaskMonitor.parseEvent(line[...], threadID: "thread-1", title: "构建应用") else {
            Issue.record("Expected a task or goal event")
            return
        }
        TaskMonitor.apply(event, to: &tasks, pendingUserMessages: &pending)
    }

    #expect(tasks["turn-1"]?.status == .paused)
    #expect(tasks["turn-1"]?.completedAt == Date(timeIntervalSince1970: 1_784_800_860))
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

@Test func responseItemUserMessageIsParsedWithItsTurnID() {
    let line = #"{"timestamp":"2026-08-23T07:00:36.478Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"第一行\n第二行"}],"internal_chat_message_metadata_passthrough":{"turn_id":"turn-1"}}}"#
    let event = TaskMonitor.parseEvent(
        line[...],
        threadID: "thread-1",
        title: "Session",
        projectName: "Codex Pulse"
    )

    #expect(event?.id == "turn-1")
    #expect(event?.projectName == "Codex Pulse")
    guard case .userMessage(let message, _) = event?.kind else {
        Issue.record("Expected a response-item user message")
        return
    }
    #expect(message == "第一行 第二行")
}

@Test func injectedCodexContextsAreNotDisplayedAsUserMessages() {
    let injectedMessages = [
        #"<codex_internal_context source=\"goal\">Continue the goal</codex_internal_context>"#,
        #"<recommended_plugins>Plugin list</recommended_plugins>"#,
        "# AGENTS.md instructions for /tmp/project",
        "<environment_context><cwd>/tmp/project</cwd></environment_context>",
    ]

    for message in injectedMessages {
        let escapedMessage = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let line = #"{"timestamp":"2026-08-23T07:06:16.195Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"\#(escapedMessage)"}],"internal_chat_message_metadata_passthrough":{"turn_id":"turn-1"}}}"#
        #expect(TaskMonitor.parseEvent(line[...], threadID: "thread-1", title: "Session") == nil)
    }
}

@Test func insertedConversationUpdatesTheRunningGoalTurn() {
    let start = #"{"timestamp":"2026-08-23T07:06:15.123Z","type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1","started_at":"2026-08-23T07:06:15.123Z"}}"#
    let goalContext = #"{"timestamp":"2026-08-23T07:06:16.195Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<codex_internal_context source=\"goal\">Continue working</codex_internal_context>"}],"internal_chat_message_metadata_passthrough":{"turn_id":"turn-1"}}}"#
    let insertedConversation = #"{"timestamp":"2026-08-23T07:06:37.146Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"批准修改\n"}],"internal_chat_message_metadata_passthrough":{"turn_id":"turn-1"}}}"#
    var tasks: [String: TaskExecution] = [:]
    var pending: [String: String] = [:]

    guard let startEvent = TaskMonitor.parseEvent(start[...], threadID: "thread-1", title: "Session"),
          let conversationEvent = TaskMonitor.parseEvent(
              insertedConversation[...], threadID: "thread-1", title: "Session"
          ) else {
        Issue.record("Expected the task and inserted conversation events")
        return
    }
    #expect(TaskMonitor.parseEvent(goalContext[...], threadID: "thread-1", title: "Session") == nil)

    TaskMonitor.apply(startEvent, to: &tasks, pendingUserMessages: &pending)
    TaskMonitor.apply(conversationEvent, to: &tasks, pendingUserMessages: &pending)

    #expect(tasks["turn-1"]?.latestUserMessage == "批准修改")
    #expect(tasks["turn-1"]?.status == .running)
    #expect(pending.isEmpty)
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

@Test func sessionDeepLinksResumeExactSessionsAndOpenCodeProjects() {
    #expect(
        SessionDeepLink.url(tool: .codex, threadID: "thread-1", directory: "/tmp/demo")?.absoluteString
            == "codex://threads/thread-1"
    )
    #expect(
        SessionDeepLink.url(
            tool: .claude,
            threadID: "claude:0197f3a2-1b2c-7d3e-9f40-5a6b7c8d9e0f",
            directory: ""
        )?.absoluteString == "claude://resume?session=0197f3a2-1b2c-7d3e-9f40-5a6b7c8d9e0f"
    )
    #expect(
        SessionDeepLink.url(tool: .opencode, threadID: "opencode:s1", directory: "/tmp/My Project")?.absoluteString
            == "opencode://open-project?directory=/tmp/My%20Project"
    )
}

@Test func sessionDeepLinksRejectUnusableIdentifiers() {
    // The Claude desktop app only imports UUID session IDs.
    #expect(SessionDeepLink.url(tool: .claude, threadID: "claude:not-a-uuid", directory: "/tmp/demo") == nil)
    #expect(SessionDeepLink.url(tool: .opencode, threadID: "opencode:s1", directory: "") == nil)
    #expect(SessionDeepLink.url(tool: .codex, threadID: "thread-1", directory: "") != nil)
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

@Test func codexRateLimitsIgnoreNamedModelQuotaAndAcceptLegacyShape() {
    let valid: [String: Any] = [
        "limit_id": "codex",
        "primary": ["used_percent": 5, "window_minutes": 10_080, "resets_at": 1_786_169_220]
    ]
    let compacted: [String: Any] = [
        "limit_id": "codex_bengalfox",
        "limit_name": "GPT-5.3-Codex-Spark",
        "primary": ["used_percent": 0, "window_minutes": 10_080, "resets_at": 1_786_804_800]
    ]
    let validDate = Date(timeIntervalSince1970: 1_785_600_000)
    let compactedDate = Date(timeIntervalSince1970: 1_786_100_000)

    for observations in [[(valid, validDate), (compacted, compactedDate)],
                         [(compacted, compactedDate), (valid, validDate)]] {
        var limits: [Int: RateWindow] = [:]
        for (rates, observedAt) in observations {
            UsageScanner.mergeRateLimits(rates, observedAt: observedAt, into: &limits)
        }

        #expect(limits[10_080]?.used == 5)
        #expect(limits[10_080]?.observedAt == validDate)
        #expect(limits[10_080]?.resetsAt == Date(timeIntervalSince1970: 1_786_169_220))
    }

    let legacy: [String: Any] = [
        "primary": ["used_percent": 7, "window_minutes": 300, "resets_at": 1_786_200_000],
        "secondary": ["used_percent": 42, "window_minutes": 10_080, "resets_at": 1_786_700_000],
    ]
    var legacyLimits: [Int: RateWindow] = [:]
    UsageScanner.mergeRateLimits(legacy, observedAt: validDate, into: &legacyLimits)

    #expect(legacyLimits[300]?.used == 7)
    #expect(legacyLimits[10_080]?.used == 42)
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
    let firstTimestamp = Date.now.addingTimeInterval(-60).formatted(.iso8601)
    let first = #"{"type":"assistant","timestamp":"\#(firstTimestamp)","message":{"id":"message-1","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":2}}}"#
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

    let secondTimestamp = Date.now.formatted(.iso8601)
    let second = #"{"type":"assistant","timestamp":"\#(secondTimestamp)","message":{"id":"message-1","model":"claude-sonnet","usage":{"input_tokens":20,"output_tokens":5}}}"#
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: (second + "\n").data(using: .utf8)!)
    try handle.close()

    let changed = await scanner.scan()
    let changedStatistics = await scanner.scanStatistics()
    #expect(changed.usage[.claude]?.total == 25)
    #expect(changedStatistics.parsedJSONFiles == 2)
}

@Test func usageScannerDefaultsToEverySource() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let recentTimestamp = Date.now.addingTimeInterval(-60).formatted(.iso8601)
    let claude = #"{"type":"assistant","timestamp":"\#(recentTimestamp)","message":{"id":"message-1","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":2}}}"#
    try (claude + "\n").data(using: .utf8)!.write(to: projects.appending(path: "session.jsonl"))
    let codex = #"{"timestamp":"\#(recentTimestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":5,"output_tokens":3}}}}"#
    try (codex + "\n").data(using: .utf8)!.write(to: sessions.appending(path: "session.jsonl"))

    let scanner = UsageScanner(home: home)
    let snapshot = await scanner.scan()
    let statistics = await scanner.scanStatistics()

    #expect(snapshot.usage[.codex]?.total == 23)
    #expect(snapshot.usage[.claude]?.total == 12)
    #expect(snapshot.usage[.opencode] == .zero)
    #expect(snapshot.errors[.claude] == nil)
    #expect(snapshot.errors[.opencode] != nil)
    #expect(snapshot.dailyUsage.allSatisfy { Set($0.usage.keys) == Set(Tool.allCases) })
    #expect(snapshot.activeTools == [.claude, .codex])
    #expect(statistics.parsedJSONFiles == 2)
    #expect(statistics.acceleratedCodexFiles == 1)
}

@Test func usageScannerColdStartReadsOnlyFourteenDayCandidatesAndCreatesNoCacheFiles() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let now = Date.now
    let recent = #"{"type":"assistant","timestamp":"\#(now.formatted(.iso8601))","message":{"id":"recent","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":2}}}"#
    let recentFile = projects.appending(path: "recent.jsonl")
    try (recent + "\n").data(using: .utf8)!.write(to: recentFile)

    // Even deliberately misleading recent content is never opened when the
    // source file itself has been inactive outside the rolling window.
    let dormantFile = projects.appending(path: "dormant.jsonl")
    try (recent.replacingOccurrences(of: #""recent""#, with: #""dormant""#) + "\n")
        .data(using: .utf8)!.write(to: dormantFile)
    try FileManager.default.setAttributes(
        [.modificationDate: now.addingTimeInterval(-15 * 86_400)],
        ofItemAtPath: dormantFile.path
    )

    let before = Set(try FileManager.default.subpathsOfDirectory(atPath: home.path))
    let scanner = UsageScanner(home: home, enabledTools: [.claude])
    let snapshot = await scanner.scan(now: now)
    let statistics = await scanner.scanStatistics()
    let after = Set(try FileManager.default.subpathsOfDirectory(atPath: home.path))

    #expect(snapshot.usage[.claude]?.total == 12)
    #expect(statistics.parsedJSONFiles == 1)
    #expect(statistics.activeJSONFiles == 1)
    #expect(before == after)
}

@Test func usageScannerSeeksPastTheExpiredPrefixOfAnActiveCodexFile() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = UsageScanner.date("2026-08-20T12:00:00Z")!
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions/2026/07/01", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let metadata = #"{"timestamp":"2026-07-01T00:00:00Z","type":"session_meta","payload":{"session_id":"long-session","id":"long-session"}}"#
    let expiredPadding = String(repeating: "x", count: 4_096)
    let expiredLines = (0..<600).map { index in
        #"{"timestamp":"2026-07-\#(String(format: "%02d", 1 + index / 100))T00:00:00Z","type":"response_item","payload":{"type":"message","role":"assistant","content":"\#(expiredPadding)"}}"#
    }
    let recentContext = #"{"timestamp":"2026-08-19T10:00:00Z","type":"turn_context","payload":{"model":"gpt-5"}}"#
    let recentUsage = #"{"timestamp":"2026-08-19T10:00:01Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5},"last_token_usage":{"input_tokens":10,"cached_input_tokens":0,"output_tokens":5}}}}"#
    let contents = ([metadata] + expiredLines + [recentContext, recentUsage]).joined(separator: "\n") + "\n"
    let file = sessions.appending(path: "rollout-2026-07-01T00-00-00-long.jsonl")
    try contents.data(using: .utf8)!.write(to: file)

    let scanner = UsageScanner(home: home, enabledTools: [.codex], calendar: calendar)
    let snapshot = await scanner.scan(now: now)
    let statistics = await scanner.scanStatistics()
    let fileBytes = (try FileManager.default.attributesOfItem(atPath: file.path)[.size] as! NSNumber).uint64Value

    #expect(snapshot.usage[.codex]?.total == 15)
    #expect(statistics.parsedJSONBytes < fileBytes / 10)
    #expect(statistics.acceleratedCodexFiles == 0)
}

@Test func usageScannerColdFilterFallsBackForAnIncompleteCodexTail() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let sessions = home.appending(path: ".codex/sessions", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let timestamp = Date.now.formatted(.iso8601)
    let metadata = #"{"timestamp":"\#(timestamp)","type":"session_meta","payload":{"session_id":"tail","id":"tail"}}"#
    let usage = #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":20,"cached_input_tokens":5,"output_tokens":3}}}}"#
    let split = usage.index(usage.startIndex, offsetBy: usage.count / 2)
    let file = sessions.appending(path: "tail.jsonl")
    try (metadata + "\n" + usage[..<split]).data(using: .utf8)!.write(to: file)

    let scanner = UsageScanner(home: home, enabledTools: [.codex])
    let partial = await scanner.scan()
    #expect(partial.usage[.codex] == .zero)
    #expect(await scanner.scanStatistics().acceleratedCodexFiles == 0)

    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: (String(usage[split...]) + "\n").data(using: .utf8)!)
    try handle.close()

    let complete = await scanner.scan()
    #expect(complete.usage[.codex]?.total == 23)
}

@Test func usageScannerReadsOnlyAppendedBytesAndWaitsForCompleteTailLine() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }

    let now = Date.now
    let first = #"{"type":"assistant","timestamp":"\#(now.addingTimeInterval(-60).formatted(.iso8601))","message":{"id":"m1","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":2}}}"#
    let second = #"{"type":"assistant","timestamp":"\#(now.formatted(.iso8601))","message":{"id":"m2","model":"claude-sonnet","usage":{"input_tokens":20,"output_tokens":5}}}"#
    let split = second.index(second.startIndex, offsetBy: second.count / 2)
    let file = projects.appending(path: "session.jsonl")
    let initialData = (first + "\n" + second[..<split]).data(using: .utf8)!
    try initialData.write(to: file)

    let scanner = UsageScanner(home: home, enabledTools: [.claude])
    let partial = await scanner.scan(now: now)
    let firstStatistics = await scanner.scanStatistics()
    #expect(partial.usage[.claude]?.total == 12)

    let appendData = (String(second[split...]) + "\n").data(using: .utf8)!
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: appendData)
    try handle.close()

    let complete = await scanner.scan(now: now)
    let secondStatistics = await scanner.scanStatistics()
    #expect(complete.usage[.claude]?.total == 37)
    #expect(secondStatistics.parsedJSONBytes - firstStatistics.parsedJSONBytes < UInt64(initialData.count))
    #expect(secondStatistics.parsedJSONBytes - firstStatistics.parsedJSONBytes == UInt64(second.utf8.count + 1))
}

@Test func usageScannerPrunesTheFifteenthDayWithoutRereadingHistory() async throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = UsageScanner.date("2026-08-20T12:00:00Z")!
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let oldest = calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!
    let lines = [
        #"{"type":"assistant","timestamp":"\#(oldest.formatted(.iso8601))","message":{"id":"oldest","model":"claude-sonnet","usage":{"input_tokens":10,"output_tokens":0}}}"#,
        #"{"type":"assistant","timestamp":"\#(now.formatted(.iso8601))","message":{"id":"current","model":"claude-sonnet","usage":{"input_tokens":20,"output_tokens":0}}}"#,
    ]
    try (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
        .write(to: projects.appending(path: "session.jsonl"))

    let scanner = UsageScanner(home: home, enabledTools: [.claude], calendar: calendar)
    let first = await scanner.scan(now: now)
    let firstStatistics = await scanner.scanStatistics()
    let rolled = await scanner.scan(now: calendar.date(byAdding: .day, value: 1, to: now)!)
    let rolledStatistics = await scanner.scanStatistics()

    #expect(first.usage[.claude]?.total == 30)
    #expect(rolled.usage[.claude]?.total == 20)
    #expect(rolledStatistics.parsedJSONBytes == firstStatistics.parsedJSONBytes)
    #expect(rolledStatistics.retainedUsageRecords == 1)
}

@Test func usageScannerRebuildsOnlyAReplacedFile() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let projects = home.appending(path: ".claude/projects", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let timestamp = Date.now.formatted(.iso8601)
    let file = projects.appending(path: "session.jsonl")
    let original = #"{"type":"assistant","timestamp":"\#(timestamp)","message":{"id":"original-long-id","model":"claude-sonnet","usage":{"input_tokens":100,"output_tokens":20}}}"#
    try (original + "\n").data(using: .utf8)!.write(to: file)
    let scanner = UsageScanner(home: home, enabledTools: [.claude])
    _ = await scanner.scan()

    let replacement = #"{"type":"assistant","timestamp":"\#(timestamp)","message":{"id":"new","model":"claude-sonnet","usage":{"input_tokens":7,"output_tokens":3}}}"#
    try (replacement + "\n").data(using: .utf8)!.write(to: file)
    let snapshot = await scanner.scan()

    #expect(snapshot.usage[.claude]?.total == 10)
    #expect(await scanner.scanStatistics().retainedUsageRecords == 1)
}

@Test func openCodeUsageScannerQueriesAndDecodesOnlyChangedRecentRows() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let directory = home.appending(path: ".local/share/opencode", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let database = directory.appending(path: "opencode.db")
    var db: OpaquePointer?
    #expect(sqlite3_open(database.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    #expect(sqlite3_exec(db, "CREATE TABLE message (id TEXT PRIMARY KEY, time_created INTEGER, time_updated INTEGER, data TEXT)", nil, nil, nil) == SQLITE_OK)

    let now = Date.now
    let recentMS = Int64(now.timeIntervalSince1970 * 1_000)
    let oldMS = Int64(now.addingTimeInterval(-15 * 86_400).timeIntervalSince1970 * 1_000)
    func insert(_ id: String, milliseconds: Int64, input: Int) {
        let json = #"{"role":"assistant","time":{"completed":\#(milliseconds)},"tokens":{"input":\#(input),"output":1}}"#
        var statement: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO message VALUES (?1, ?2, ?3, ?4)", -1, &statement, nil)
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1 as Int, to: sqlite3_destructor_type.self)
        sqlite3_bind_text(statement, 1, id, -1, transient)
        sqlite3_bind_int64(statement, 2, milliseconds)
        sqlite3_bind_int64(statement, 3, milliseconds)
        sqlite3_bind_text(statement, 4, json, -1, transient)
        #expect(sqlite3_step(statement) == SQLITE_DONE)
    }
    insert("old", milliseconds: oldMS, input: 99)
    insert("recent", milliseconds: recentMS, input: 10)

    let scanner = UsageScanner(home: home, enabledTools: [.opencode])
    let cold = await scanner.scan(now: now)
    let coldStatistics = await scanner.scanStatistics()
    let unchanged = await scanner.scan(now: now)
    let unchangedStatistics = await scanner.scanStatistics()
    #expect(cold.usage[.opencode]?.total == 11)
    #expect(unchanged.usage[.opencode]?.total == 11)
    #expect(coldStatistics.parsedOpenCodeRows == 1)
    #expect(unchangedStatistics.parsedOpenCodeRows == 1)

    insert("recent-2", milliseconds: recentMS + 1, input: 20)
    let appended = await scanner.scan(now: now)
    #expect(appended.usage[.opencode]?.total == 32)
    #expect(await scanner.scanStatistics().parsedOpenCodeRows == 2)

    #expect(sqlite3_exec(db, "DELETE FROM message WHERE id='recent'", nil, nil, nil) == SQLITE_OK)
    let deleted = await scanner.scan(now: now)
    #expect(deleted.usage[.opencode]?.total == 21)
    #expect(await scanner.scanStatistics().parsedOpenCodeRows == 2)
}

// MARK: - Claude Code task monitoring

@Test func claudeParseLineRecognizesTurnBoundaries() {
    let prompt = #"{"type":"user","sessionId":"session-1","cwd":"/Users/i/project/Demo","uuid":"prompt-1","timestamp":"2026-07-26T10:00:00.100Z","message":{"role":"user","content":"修复登录\n问题"}}"#
    guard case .prompt(let sessionID, let cwd, let uuid, let text, _) = ClaudeTaskMonitor.parseLine(prompt[...]) else {
        Issue.record("Expected a prompt")
        return
    }
    #expect(sessionID == "session-1")
    #expect(cwd == "/Users/i/project/Demo")
    #expect(uuid == "prompt-1")
    #expect(text == "修复登录\n问题")

    let endTurn = #"{"type":"assistant","sessionId":"session-1","timestamp":"2026-07-26T10:01:00Z","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"完成"}]}}"#
    guard case .turnEnd = ClaudeTaskMonitor.parseLine(endTurn[...]) else {
        Issue.record("Expected a turn end")
        return
    }

    let interrupt = #"{"type":"user","sessionId":"session-1","uuid":"stop-1","timestamp":"2026-07-26T10:02:00Z","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#
    guard case .interrupted = ClaudeTaskMonitor.parseLine(interrupt[...]) else {
        Issue.record("Expected an interruption")
        return
    }

    let customTitle = #"{"type":"custom-title","customTitle":"登录修复","sessionId":"session-1"}"#
    #expect(ClaudeTaskMonitor.parseLine(customTitle[...]) == .customTitle(sessionID: "session-1", title: "登录修复"))
    let aiTitle = #"{"type":"ai-title","aiTitle":"修复登录问题","sessionId":"session-1"}"#
    #expect(ClaudeTaskMonitor.parseLine(aiTitle[...]) == .aiTitle(sessionID: "session-1", title: "修复登录问题"))
}

@Test func claudeParseLineIgnoresNonTaskEntries() {
    let toolUse = #"{"type":"assistant","sessionId":"s","timestamp":"2026-07-26T10:00:00Z","message":{"stop_reason":"tool_use","content":[{"type":"tool_use"}]}}"#
    let noStop = #"{"type":"assistant","sessionId":"s","timestamp":"2026-07-26T10:00:00Z","message":{"stop_reason":null,"content":[{"type":"text","text":"…"}]}}"#
    let toolResult = #"{"type":"user","sessionId":"s","uuid":"u","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}"#
    let sidechain = #"{"type":"user","isSidechain":true,"sessionId":"s","uuid":"u","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":"子代理提示词"}}"#
    let meta = #"{"type":"user","isMeta":true,"sessionId":"s","uuid":"u","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":"Caveat: …"}}"#
    let compact = #"{"type":"user","isCompactSummary":true,"sessionId":"s","uuid":"u","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":"总结"}}"#
    let command = #"{"type":"user","sessionId":"s","uuid":"u","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":"<command-name>/clear</command-name>"}}"#
    let queue = #"{"type":"queue-operation","operation":"enqueue","timestamp":"2026-07-26T10:00:00Z","sessionId":"s","content":"排队消息"}"#
    for line in [toolUse, noStop, toolResult, sidechain, meta, compact, command, queue] {
        #expect(ClaudeTaskMonitor.parseLine(line[...]) == nil)
    }
}

@Test func claudeTaskMonitorTracksTurnLifecycleFromTranscript() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let project = home.appending(path: ".claude/projects/-Users-i-project-Demo", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let file = project.appending(path: "session-1.jsonl")

    func append(_ lines: [String]) throws {
        let data = (lines.joined(separator: "\n") + "\n").data(using: .utf8)!
        if FileManager.default.fileExists(atPath: file.path) {
            let handle = try FileHandle(forWritingTo: file)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } else {
            try data.write(to: file)
        }
    }

    let start = try Date("2026-07-26T10:00:00Z", strategy: .iso8601)
    try append([
        #"{"type":"user","sessionId":"session-1","cwd":"/Users/i/project/Demo","uuid":"prompt-1","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":"修复登录问题"}}"#,
        #"{"type":"assistant","sessionId":"session-1","timestamp":"2026-07-26T10:00:10Z","message":{"stop_reason":"tool_use","content":[{"type":"tool_use"}]}}"#,
    ])

    let monitor = ClaudeTaskMonitor(home: home)
    var tasks = await monitor.scan(now: start.addingTimeInterval(30))
    #expect(tasks.count == 1)
    #expect(tasks.first?.tool == .claude)
    #expect(tasks.first?.threadID == "claude:session-1")
    #expect(tasks.first?.isCompleted == false)
    #expect(tasks.first?.latestUserMessage == "修复登录问题")
    #expect(tasks.first?.projectName == "Demo")
    #expect(tasks.first?.title == "修复登录问题")

    // A queued prompt updates the running task; an AI title renames the session.
    try append([
        #"{"type":"ai-title","aiTitle":"登录问题修复","sessionId":"session-1"}"#,
        #"{"type":"user","sessionId":"session-1","cwd":"/Users/i/project/Demo","uuid":"prompt-2","timestamp":"2026-07-26T10:01:00Z","message":{"role":"user","content":"顺便更新文档"}}"#,
    ])
    tasks = await monitor.scan(now: start.addingTimeInterval(70))
    #expect(tasks.count == 1)
    #expect(tasks.first?.latestUserMessage == "顺便更新文档")
    #expect(tasks.first?.title == "登录问题修复")

    try append([
        #"{"type":"assistant","sessionId":"session-1","timestamp":"2026-07-26T10:03:00Z","message":{"stop_reason":"end_turn","content":[{"type":"text","text":"完成"}]}}"#,
    ])
    tasks = await monitor.scan(now: start.addingTimeInterval(200))
    #expect(tasks.count == 1)
    #expect(tasks.first?.isCompleted == true)
    #expect(tasks.first?.completedAt == start.addingTimeInterval(180))

    // A fresh prompt starts a second task in the same session.
    try append([
        #"{"type":"user","sessionId":"session-1","cwd":"/Users/i/project/Demo","uuid":"prompt-3","timestamp":"2026-07-26T10:04:00Z","message":{"role":"user","content":"再跑一次测试"}}"#,
    ])
    tasks = await monitor.scan(now: start.addingTimeInterval(250))
    #expect(tasks.count == 2)
    #expect(tasks.filter { !$0.isCompleted }.count == 1)

    // Interruption removes the running task.
    try append([
        #"{"type":"user","sessionId":"session-1","uuid":"stop-1","timestamp":"2026-07-26T10:05:00Z","message":{"role":"user","content":[{"type":"text","text":"[Request interrupted by user]"}]}}"#,
    ])
    tasks = await monitor.scan(now: start.addingTimeInterval(310))
    #expect(tasks.count == 1)
    #expect(tasks.filter { !$0.isCompleted }.isEmpty)
}

@Test func claudeRunningTaskGoesStaleAfterSilenceButSurvivesTranscriptGrowth() async throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    let project = home.appending(path: ".claude/projects/-Users-i-project-Demo", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let file = project.appending(path: "session-1.jsonl")
    let start = try Date("2026-07-26T10:00:00Z", strategy: .iso8601)

    let line = #"{"type":"user","sessionId":"session-1","cwd":"/Users/i/project/Demo","uuid":"prompt-1","timestamp":"2026-07-26T10:00:00Z","message":{"role":"user","content":"修复登录问题"}}"#
    try (line + "\n").data(using: .utf8)!.write(to: file)
    try FileManager.default.setAttributes([.modificationDate: start], ofItemAtPath: file.path)

    let monitor = ClaudeTaskMonitor(home: home)
    var tasks = await monitor.scan(now: start.addingTimeInterval(30))
    #expect(tasks.count == 1)

    // Tool traffic appends unparsed lines without any task event: the
    // transcript keeps growing, so the running turn must stay alive.
    let toolNoise = #"{"type":"assistant","sessionId":"session-1","timestamp":"2026-07-26T10:11:00Z","message":{"stop_reason":"tool_use","content":[{"type":"tool_use"}]}}"#
    let handle = try FileHandle(forWritingTo: file)
    try handle.seekToEnd()
    try handle.write(contentsOf: (toolNoise + "\n").data(using: .utf8)!)
    try handle.close()
    let grown = start.addingTimeInterval(11 * 60)
    try FileManager.default.setAttributes([.modificationDate: grown], ofItemAtPath: file.path)

    tasks = await monitor.scan(now: start.addingTimeInterval(13 * 60))
    #expect(tasks.count == 1)

    // Silence past the stale interval with no further growth drops the turn.
    tasks = await monitor.scan(now: grown.addingTimeInterval(ClaudeTaskMonitor.runningStaleInterval + 60))
    #expect(tasks.isEmpty)
}

// MARK: - OpenCode task monitoring

private func openCodeRow(
    id: String,
    role: String,
    parent: String? = nil,
    finish: String? = nil,
    created: TimeInterval,
    completed: TimeInterval? = nil
) -> OpenCodeTaskMonitor.MessageRow {
    OpenCodeTaskMonitor.MessageRow(
        id: id,
        role: role,
        parentID: parent,
        finish: finish,
        created: Date(timeIntervalSince1970: created),
        completed: completed.map(Date.init(timeIntervalSince1970:))
    )
}

@Test func openCodeTurnIsRunningWhileAnAssistantStepIsIncomplete() {
    let rows = [
        openCodeRow(id: "user-1", role: "user", created: 100),
        openCodeRow(id: "a-1", role: "assistant", parent: "user-1", finish: "tool-calls", created: 101, completed: 105),
        openCodeRow(id: "a-2", role: "assistant", parent: "user-1", created: 105),
    ]
    let tasks = OpenCodeTaskMonitor.turnTasks(
        sessionID: "ses_1",
        title: "登录修复",
        projectName: "Demo",
        rows: rows,
        prompts: ["user-1": "修复登录问题"]
    )
    #expect(tasks.count == 1)
    #expect(tasks.first?.tool == .opencode)
    #expect(tasks.first?.threadID == "opencode:ses_1")
    #expect(tasks.first?.isCompleted == false)
    #expect(tasks.first?.latestUserMessage == "修复登录问题")
    #expect(tasks.first?.startedAt == Date(timeIntervalSince1970: 100))
}

@Test func openCodeTurnCompletesOnStopAndDropsAbortedTurns() {
    let completedRows = [
        openCodeRow(id: "user-1", role: "user", created: 100),
        openCodeRow(id: "a-1", role: "assistant", parent: "user-1", finish: "stop", created: 101, completed: 130),
    ]
    let completed = OpenCodeTaskMonitor.turnTasks(
        sessionID: "ses_1", title: "", projectName: "Demo", rows: completedRows, prompts: [:]
    )
    #expect(completed.first?.completedAt == Date(timeIntervalSince1970: 130))
    #expect(completed.first?.title == "OpenCode")

    let abortedRows = [
        openCodeRow(id: "user-1", role: "user", created: 100),
        openCodeRow(id: "a-1", role: "assistant", parent: "user-1", finish: "unknown", created: 101, completed: 110),
    ]
    let aborted = OpenCodeTaskMonitor.turnTasks(
        sessionID: "ses_1", title: "t", projectName: "Demo", rows: abortedRows, prompts: [:]
    )
    #expect(aborted.isEmpty)
}

@Test func openCodeOnlyTheLatestUnansweredPromptWaits() {
    let rows = [
        openCodeRow(id: "user-1", role: "user", created: 100),
        openCodeRow(id: "user-2", role: "user", created: 200),
    ]
    let tasks = OpenCodeTaskMonitor.turnTasks(
        sessionID: "ses_1", title: "t", projectName: "Demo", rows: rows, prompts: [:]
    )
    #expect(tasks.map(\.id) == ["opencode:user-2"])
    #expect(tasks.first?.isCompleted == false)
}

@Test func openCodeMessageRowParsesMillisecondTimes() {
    let row = OpenCodeTaskMonitor.messageRow(id: "a-1", data: [
        "role": "assistant",
        "parentID": "user-1",
        "finish": "stop",
        "time": ["created": 1_785_000_000_123, "completed": 1_785_000_009_456],
    ])
    #expect(row?.parentID == "user-1")
    #expect(row?.created == Date(timeIntervalSince1970: 1_785_000_000.123))
    #expect(row?.completed == Date(timeIntervalSince1970: 1_785_000_009.456))
}

@Test func mergedToolTasksShareOneDisplayOrder() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let codex = TaskExecution(id: "turn-1", threadID: "thread-1", title: "Codex", startedAt: base.addingTimeInterval(20))
    let claude = TaskExecution(id: "claude:u1", threadID: "claude:s1", tool: .claude, title: "Claude", startedAt: base.addingTimeInterval(10))
    let opencode = TaskExecution(
        id: "opencode:m1", threadID: "opencode:ses1", tool: .opencode, title: "OpenCode",
        startedAt: base, completedAt: base.addingTimeInterval(5)
    )
    let merged = TaskMonitor.sortedForDisplay([codex, claude, opencode])
    #expect(merged.map(\.id) == ["opencode:m1", "claude:u1", "turn-1"])
}
