import CSQLite
import Foundation

/// Monitors OpenCode turns from its SQLite database (read-only). A turn is a
/// user message plus the assistant messages that reference it via `parentID`:
/// the turn runs while an assistant message has no completion time or ends a
/// step with `finish == "tool-calls"`, completes when the last assistant
/// message finishes with `stop`/`length`, and is dropped when it finishes
/// with `unknown` (aborted). The database is re-read only when the database,
/// WAL, or shared-memory file changes.
actor OpenCodeTaskMonitor {
    /// Same abandonment rule as `ClaudeTaskMonitor`: a running turn whose
    /// session shows no activity past this interval is dropped.
    static let runningStaleInterval: TimeInterval = 12 * 60
    static let sourceFreshnessInterval: TimeInterval = 15 * 60
    static let maximumSessionCount = 24
    static let maximumMessagesPerSession = 40

    struct MessageRow: Sendable, Equatable {
        let id: String
        let role: String
        let parentID: String?
        let finish: String?
        let created: Date?
        let completed: Date?
    }

    private struct FileState: Equatable {
        let size: UInt64
        let modificationDate: Date
    }

    private struct Cache {
        var database: FileState
        var wal: FileState?
        var sharedMemory: FileState?
        var executions: [String: TaskExecution]
        /// Latest session activity keyed by thread ID, for staleness checks
        /// between database changes.
        var activity: [String: Date]
    }

    private let home: URL
    private var cache: Cache?

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    func scan(now: Date = Date()) -> [TaskExecution] {
        let url = home.appending(path: ".local/share/opencode/opencode.db")
        guard let databaseState = fileState(at: url) else {
            cache = nil
            return []
        }
        let walState = fileState(at: URL(fileURLWithPath: url.path + "-wal"))
        let sharedMemoryState = fileState(at: URL(fileURLWithPath: url.path + "-shm"))

        if cache == nil
            || cache?.database != databaseState
            || cache?.wal != walState
            || cache?.sharedMemory != sharedMemoryState {
            let (executions, activity) = readDatabase(at: url.path, now: now)
            // Opening a WAL database can update shared-memory metadata; capture
            // post-read versions so this read does not invalidate the next scan.
            cache = Cache(
                database: fileState(at: url) ?? databaseState,
                wal: fileState(at: URL(fileURLWithPath: url.path + "-wal")),
                sharedMemory: fileState(at: URL(fileURLWithPath: url.path + "-shm")),
                executions: executions,
                activity: activity
            )
        }

        guard var cache else { return [] }
        cache.executions = cache.executions.filter { _, task in
            guard !task.isCompleted else { return true }
            let activity = cache.activity[task.threadID] ?? task.startedAt
            return now.timeIntervalSince(activity) <= Self.runningStaleInterval
        }
        self.cache = cache
        return TaskMonitor.visible(cache.executions, now: now)
    }

    // MARK: - Database

    private func readDatabase(at path: String, now: Date) -> ([String: TaskExecution], [String: Date]) {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return ([:], [:])
        }
        defer { sqlite3_close(db) }

        var executions: [String: TaskExecution] = [:]
        var activity: [String: Date] = [:]
        for session in querySessions(db) {
            guard now.timeIntervalSince(session.updated) <= Self.sourceFreshnessInterval else { continue }
            let threadID = Self.threadID(session.id)
            activity[threadID] = session.updated
            let rows = queryMessages(db, sessionID: session.id)
            var prompts: [String: String] = [:]
            for row in rows where row.role == "user" {
                prompts[row.id] = queryPromptText(db, messageID: row.id)
            }
            let tasks = Self.turnTasks(
                sessionID: session.id,
                title: session.title,
                projectName: TaskMonitor.projectName(from: session.directory),
                directory: session.directory,
                rows: rows,
                prompts: prompts
            )
            for task in tasks {
                executions[task.id] = task
            }
        }
        return (executions, activity)
    }

    private struct SessionRow {
        let id: String
        let title: String
        let directory: String
        let updated: Date
    }

    private func querySessions(_ db: OpaquePointer?) -> [SessionRow] {
        let sql = """
            SELECT id, title, directory, time_updated
            FROM session
            WHERE parent_id IS NULL AND time_archived IS NULL
            ORDER BY time_updated DESC
            LIMIT \(Self.maximumSessionCount)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        var result: [SessionRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = sqlite3_column_text(statement, 0),
                  let title = sqlite3_column_text(statement, 1),
                  let directory = sqlite3_column_text(statement, 2) else { continue }
            result.append(SessionRow(
                id: String(cString: id),
                title: String(cString: title),
                directory: String(cString: directory),
                updated: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 3)) / 1_000)
            ))
        }
        return result
    }

    private func queryMessages(_ db: OpaquePointer?, sessionID: String) -> [MessageRow] {
        let sql = """
            SELECT id, data FROM message
            WHERE session_id = ?1
            ORDER BY time_created DESC
            LIMIT \(Self.maximumMessagesPerSession)
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, sessionID, -1, Self.transientDestructor)
        var rows: [MessageRow] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            autoreleasepool {
                guard let id = sqlite3_column_text(statement, 0),
                      let json = sqlite3_column_text(statement, 1),
                      let data = String(cString: json).data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let row = Self.messageRow(id: String(cString: id), data: value) else { return }
                rows.append(row)
            }
        }
        return rows.reversed()
    }

    private func queryPromptText(_ db: OpaquePointer?, messageID: String) -> String {
        let sql = "SELECT data FROM part WHERE message_id = ?1 ORDER BY id LIMIT 8"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return "" }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_text(statement, 1, messageID, -1, Self.transientDestructor)
        var texts: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            autoreleasepool {
                guard let json = sqlite3_column_text(statement, 0),
                      let data = String(cString: json).data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      value["type"] as? String == "text",
                      let text = value["text"] as? String, !text.isEmpty else { return }
                texts.append(text)
            }
        }
        return TaskMonitor.displayText(texts.joined(separator: " "), maximumLength: 160)
    }

    private static let transientDestructor = unsafeBitCast(
        -1 as Int,
        to: sqlite3_destructor_type.self
    )

    private func fileState(at url: URL) -> FileState? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize,
              let modificationDate = values.contentModificationDate else { return nil }
        return FileState(size: UInt64(size), modificationDate: modificationDate)
    }

    // MARK: - Turn derivation

    nonisolated static func threadID(_ sessionID: String) -> String { "opencode:\(sessionID)" }

    nonisolated static func messageRow(id: String, data: [String: Any]) -> MessageRow? {
        guard let role = data["role"] as? String else { return nil }
        let time = data["time"] as? [String: Any]
        return MessageRow(
            id: id,
            role: role,
            parentID: data["parentID"] as? String,
            finish: data["finish"] as? String,
            created: UsageScanner.date(time?["created"]),
            completed: UsageScanner.date(time?["completed"])
        )
    }

    /// Builds one task per user message from ascending message rows.
    nonisolated static func turnTasks(
        sessionID: String,
        title: String,
        projectName: String,
        directory: String = "",
        rows: [MessageRow],
        prompts: [String: String]
    ) -> [TaskExecution] {
        let users = rows.filter { $0.role == "user" }
        guard !users.isEmpty else { return [] }
        let displayTitle = title.isEmpty ? "OpenCode" : TaskMonitor.displayText(title, maximumLength: 80)
        var tasks: [TaskExecution] = []
        for user in users {
            guard let startedAt = user.created else { continue }
            let assistants = rows.filter { $0.role == "assistant" && $0.parentID == user.id }
            var completedAt: Date?
            if let last = assistants.last {
                if assistants.contains(where: { $0.completed == nil }) {
                    completedAt = nil
                } else if last.finish == "stop" || last.finish == "length" {
                    completedAt = last.completed ?? last.created
                } else if last.finish == "unknown" {
                    continue // Aborted turn.
                }
            } else if user.id != users.last?.id {
                // An old prompt with no responses cannot still be waiting.
                continue
            }
            tasks.append(TaskExecution(
                id: "opencode:\(user.id)",
                threadID: threadID(sessionID),
                tool: .opencode,
                title: displayTitle,
                projectName: projectName,
                directory: directory,
                latestUserMessage: prompts[user.id] ?? "",
                startedAt: startedAt,
                completedAt: completedAt
            ))
        }
        return tasks
    }
}
