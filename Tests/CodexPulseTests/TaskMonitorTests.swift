import CSQLite
import Foundation
import Testing
@testable import CodexPulse

struct TaskMonitorTests {
    let base = Date(timeIntervalSince1970: 1_789_000_000)

    func event(_ kind: TaskEventKind, id: String = "turn", thread: String = "thread", at: Date) -> TaskExecutionEvent {
        TaskExecutionEvent(id: id, threadID: thread, title: "Test", projectName: "Project", startedAt: at, kind: kind)
    }

    @Test func silenceIsReversibleAndExpiresAtTenMinutes() {
        var tasks: [String: TaskExecution] = [:]
        var pending: [String: String] = [:]
        TaskMonitor.apply(event(.started, at: base), to: &tasks, pendingUserMessages: &pending)
        #expect(TaskMonitor.visible(tasks, now: base.addingTimeInterval(179)).first?.status == .running)
        #expect(TaskMonitor.visible(tasks, now: base.addingTimeInterval(180)).first?.status == .paused)
        #expect(TaskMonitor.visible(tasks, now: base.addingTimeInterval(599)).count == 1)
        #expect(TaskMonitor.visible(tasks, now: base.addingTimeInterval(600)).isEmpty)
        #expect(tasks["turn"]?.status == .running)
        let resumed = base.addingTimeInterval(700)
        TaskMonitor.apply(event(.activity(resumed), at: resumed), to: &tasks, pendingUserMessages: &pending)
        #expect(TaskMonitor.visible(tasks, now: resumed).first?.status == .running)
    }

    @Test func nextTurnClosesOrphanAndDoesNotStealMessages() {
        var tasks: [String: TaskExecution] = [:]
        var pending: [String: String] = [:]
        TaskMonitor.apply(event(.started, at: base), to: &tasks, pendingUserMessages: &pending)
        TaskMonitor.apply(event(.userMessage("Old", base), at: base), to: &tasks, pendingUserMessages: &pending)
        let next = base.addingTimeInterval(800)
        TaskMonitor.apply(event(.started, id: "next", at: next), to: &tasks, pendingUserMessages: &pending)
        TaskMonitor.apply(event(.userMessage("New", next), at: next), to: &tasks, pendingUserMessages: &pending)
        #expect(tasks["turn"]?.status == .paused)
        #expect(tasks["turn"]?.completedAt == base)
        #expect(tasks["turn"]?.latestUserMessage == "Old")
        #expect(tasks["next"]?.latestUserMessage == "New")
        TaskMonitor.apply(event(.completed(next), id: "next", at: next), to: &tasks, pendingUserMessages: &pending)
        #expect(TaskMonitor.visible(tasks, now: next).allSatisfy { $0.status == .completed })
    }

    @Test func explicitEndCannotBeRevivedByActivity() {
        for kind in [TaskEventKind.aborted(base), .completed(base), .goalPaused(base)] {
            var tasks: [String: TaskExecution] = [:]
            var pending: [String: String] = [:]
            TaskMonitor.apply(event(.started, at: base), to: &tasks, pendingUserMessages: &pending)
            TaskMonitor.apply(event(kind, at: base), to: &tasks, pendingUserMessages: &pending)
            let ended = tasks["turn"]
            TaskMonitor.apply(event(.activity(base.addingTimeInterval(900)), at: base), to: &tasks, pendingUserMessages: &pending)
            #expect(tasks["turn"] == ended)
        }
    }

    @Test func activityStaysWithinItsThread() {
        var tasks: [String: TaskExecution] = [:]
        var pending: [String: String] = [:]
        TaskMonitor.apply(event(.started, at: base), to: &tasks, pendingUserMessages: &pending)
        let later = base.addingTimeInterval(400)
        TaskMonitor.apply(event(.activity(later), thread: "another", at: later), to: &tasks, pendingUserMessages: &pending)
        #expect(tasks["turn"]?.lastActivityAt == base)
    }

    @Test func incrementalToolOutputPartialWritesAndColdReplayAgree() async throws {
        let home = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: home) }
        let root = home.appending(path: ".codex")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let log = root.appending(path: "rollout.jsonl")
        let stamp = { (date: Date) in date.ISO8601Format(.iso8601(timeZone: .gmt, includingFractionalSeconds: true)) + "Z" }
        let start = "{\"timestamp\":\"\(stamp(base))\",\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\",\"turn_id\":\"turn\"}}\n"
        #expect(TaskMonitor.parseEvent(start.dropLast(), threadID: "thread", title: "Test") != nil, "\(start)")
        try Data(start.utf8).write(to: log)
        var db: OpaquePointer?
        #expect(sqlite3_open(root.appending(path: "state_1.sqlite").path, &db) == SQLITE_OK)
        defer { sqlite3_close(db) }
        let sql = """
        CREATE TABLE threads (id TEXT, title TEXT, rollout_path TEXT, cwd TEXT, archived INTEGER, thread_source TEXT, updated_at_ms INTEGER, updated_at INTEGER);
        INSERT INTO threads VALUES ('thread', 'Test', '\(log.path)', '/Project', 0, 'user', 1, 1);
        """
        #expect(sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK)
        let monitor = TaskMonitor(home: home)
        #expect(await monitor.scan(now: base).first?.status == .running)
        #expect(await monitor.scan(now: base.addingTimeInterval(200)).first?.status == .paused)
        let activity = base.addingTimeInterval(250)
        let output = "{\"timestamp\":\"\(stamp(activity))\",\"type\":\"response_item\",\"payload\":{\"type\":\"custom_tool_call_output\",\"output\":\"OK\"}}\n"
        let handle = try FileHandle(forWritingTo: log)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(output.utf8))
        try FileManager.default.setAttributes([.modificationDate: activity], ofItemAtPath: log.path)
        #expect(await monitor.scan(now: activity).first?.status == .running)
        // Cross several 64 KiB reads, then finish a previously incomplete line.
        let largeAt = base.addingTimeInterval(300)
        let largeOutput = "{\"timestamp\":\"\(stamp(largeAt))\",\"type\":\"response_item\",\"payload\":{\"type\":\"custom_tool_call_output\",\"output\":\"" + String(repeating: "x", count: 200_000)
        try handle.write(contentsOf: Data(largeOutput.utf8))
        try FileManager.default.setAttributes([.modificationDate: largeAt], ofItemAtPath: log.path)
        #expect(await monitor.scan(now: largeAt).first?.lastActivityAt == largeAt)
        try handle.write(contentsOf: Data("\"}}\n".utf8))
        try FileManager.default.setAttributes([.modificationDate: largeAt], ofItemAtPath: log.path)
        #expect(await monitor.scan(now: largeAt).first?.status == .running)
        let partialAt = base.addingTimeInterval(500)
        try handle.write(contentsOf: Data("{\"timestamp\":\"".utf8))
        try FileManager.default.setAttributes([.modificationDate: partialAt], ofItemAtPath: log.path)
        let incremental = await monitor.scan(now: partialAt)
        #expect(incremental.first?.status == .running)
        #expect(incremental.first?.lastActivityAt == partialAt)
        let cold = await TaskMonitor(home: home).scan(now: partialAt)
        #expect(cold == incremental)
        #expect(await monitor.scan(now: partialAt.addingTimeInterval(600)).isEmpty)
        #expect(await TaskMonitor(home: home).scan(now: partialAt.addingTimeInterval(600)).isEmpty)
    }
}
