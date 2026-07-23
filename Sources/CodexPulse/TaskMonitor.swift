import CSQLite
import Foundation

actor TaskMonitor {
    private struct ThreadSource {
        let id: String
        let title: String
        let projectName: String
        let path: String
    }

    private struct FileCursor {
        var offset: UInt64 = 0
        var remainder = Data()
    }

    private let home: URL
    private var cursors: [String: FileCursor] = [:]
    private var executions: [String: TaskExecution] = [:]
    private var pendingUserMessages: [String: String] = [:]
    private var cachedSources: [ThreadSource]?
    private var lastSourceRefresh = Date.distantPast
    private let sourceRefreshInterval: TimeInterval = 5

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    func scan(now: Date = Date()) -> [TaskExecution] {
        guard let sources = recentThreads(now: now) else { return Self.visible(executions, now: now) }
        let sourceIDs = Set(sources.map(\.id))
        let sourcePaths = Set(sources.map(\.path))
        executions = executions.filter { sourceIDs.contains($0.value.threadID) }
        cursors = cursors.filter { sourcePaths.contains($0.key) }
        pendingUserMessages = pendingUserMessages.filter { sourceIDs.contains($0.key) }
        let titles = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.title) })
        let projects = Dictionary(uniqueKeysWithValues: sources.map { ($0.id, $0.projectName) })
        for (id, var task) in executions {
            if let title = titles[task.threadID] {
                task.title = title
            }
            if let project = projects[task.threadID] { task.projectName = project }
            executions[id] = task
        }

        var events: [TaskExecutionEvent] = []
        for source in sources {
            events.append(contentsOf: readNewEvents(from: source))
        }
        for event in events.sorted(by: { $0.eventDate < $1.eventDate }) {
            apply(event)
        }

        return Self.visible(executions, now: now)
    }

    private func stateDatabasePath() -> String? {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: home.appending(path: ".codex"),
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .compactMap { url -> (Int, String)? in
                let name = url.deletingPathExtension().lastPathComponent
                guard url.pathExtension == "sqlite", name.hasPrefix("state_"),
                      let version = Int(name.dropFirst("state_".count)) else { return nil }
                return (version, url.path)
            }
            .max { $0.0 < $1.0 }?.1
    }

    private func recentThreads(now: Date) -> [ThreadSource]? {
        if let cachedSources, now.timeIntervalSince(lastSourceRefresh) < sourceRefreshInterval {
            return cachedSources
        }
        guard let sources = queryRecentThreads() else { return cachedSources }
        cachedSources = sources
        lastSourceRefresh = now
        return sources
    }

    private func queryRecentThreads() -> [ThreadSource]? {
        guard let path = stateDatabasePath() else { return nil }
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT id, title, rollout_path, cwd
            FROM threads
            WHERE archived = 0
              AND rollout_path <> ''
              AND thread_source = 'user'
            ORDER BY COALESCE(updated_at_ms, updated_at * 1000) DESC
            LIMIT 24
            """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(statement) }

        var result: [ThreadSource] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = sqlite3_column_text(statement, 0),
                  let title = sqlite3_column_text(statement, 1),
                  let path = sqlite3_column_text(statement, 2),
                  let cwd = sqlite3_column_text(statement, 3) else { continue }
            let rawTitle = String(cString: title)
            let singleLineTitle = rawTitle.split(whereSeparator: \.isNewline).joined(separator: " ")
            let displayTitle = singleLineTitle.count > 80
                ? String(singleLineTitle.prefix(80)) + "…"
                : singleLineTitle
            result.append(ThreadSource(
                id: String(cString: id),
                title: displayTitle.isEmpty ? "Codex" : displayTitle,
                projectName: Self.projectName(from: String(cString: cwd)),
                path: String(cString: path)
            ))
        }
        return result
    }

    private func readNewEvents(from source: ThreadSource) -> [TaskExecutionEvent] {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let byteCount = (attributes[.size] as? NSNumber)?.uint64Value else { return [] }

        var cursor = cursors[source.path] ?? FileCursor()
        if byteCount < cursor.offset { cursor = FileCursor() }
        guard byteCount > cursor.offset,
              let handle = FileHandle(forReadingAtPath: source.path) else { return [] }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: cursor.offset)
            var events: [TaskExecutionEvent] = []
            while let data = try handle.read(upToCount: 64 * 1024), !data.isEmpty {
                cursor.offset += UInt64(data.count)
                cursor.remainder.append(data)
                var lineStart = cursor.remainder.startIndex
                while let newline = cursor.remainder[lineStart...].firstIndex(of: 0x0A) {
                    autoreleasepool {
                        let line = String(decoding: cursor.remainder[lineStart..<newline], as: UTF8.self)
                        if let event = Self.parseEvent(
                            line[...],
                            threadID: source.id,
                            title: source.title,
                            projectName: source.projectName
                        ) {
                            events.append(event)
                        }
                    }
                    lineStart = cursor.remainder.index(after: newline)
                }
                if lineStart > cursor.remainder.startIndex {
                    cursor.remainder = Data(cursor.remainder[lineStart...])
                }
                if cursor.remainder.count > 8 * 1024 * 1024 {
                    cursor.remainder.removeAll(keepingCapacity: false)
                }
            }
            cursors[source.path] = cursor
            return events
        } catch {
            return []
        }
    }

    private func apply(_ event: TaskExecutionEvent) {
        switch event.kind {
        case .started:
            if let current = executions[event.id], current.completedAt != nil { return }
            executions[event.id] = TaskExecution(
                id: event.id,
                threadID: event.threadID,
                title: event.title,
                projectName: event.projectName,
                latestUserMessage: pendingUserMessages.removeValue(forKey: event.threadID) ?? "",
                startedAt: event.startedAt,
                completedAt: nil
            )
        case .completed(let completedAt):
            let current = executions[event.id]
            executions[event.id] = TaskExecution(
                id: event.id,
                threadID: event.threadID,
                title: event.title,
                projectName: current?.projectName ?? event.projectName,
                latestUserMessage: current?.latestUserMessage ?? "",
                startedAt: event.startedAt,
                completedAt: completedAt
            )
        case .aborted:
            executions.removeValue(forKey: event.id)
        case .userMessage(let message, _):
            if let id = executions.values
                .filter({ $0.threadID == event.threadID && $0.completedAt == nil })
                .max(by: { $0.startedAt < $1.startedAt })?.id {
                executions[id]?.latestUserMessage = message
            } else {
                pendingUserMessages[event.threadID] = message
            }
        }
    }

    nonisolated static func parseEvent(
        _ line: Substring,
        threadID: String,
        title: String,
        projectName: String = ""
    ) -> TaskExecutionEvent? {
        guard let root = UsageScanner.object(line), root["type"] as? String == "event_msg",
              let payload = root["payload"] as? [String: Any],
              let type = payload["type"] as? String else { return nil }

        if type == "user_message" {
            guard let rawMessage = payload["message"] as? String,
                  let messageAt = UsageScanner.date(root["timestamp"]) else { return nil }
            let message = displayText(rawMessage, maximumLength: 160)
            guard !message.isEmpty else { return nil }
            return TaskExecutionEvent(
                id: threadID,
                threadID: threadID,
                title: title,
                projectName: projectName,
                startedAt: messageAt,
                kind: .userMessage(message, messageAt)
            )
        }

        guard let turnID = payload["turn_id"] as? String else { return nil }

        switch type {
        case "task_started":
            guard let startedAt = UsageScanner.date(payload["started_at"] ?? root["timestamp"]) else { return nil }
            return TaskExecutionEvent(id: turnID, threadID: threadID, title: title, projectName: projectName, startedAt: startedAt, kind: .started)
        case "task_complete":
            guard let startedAt = UsageScanner.date(payload["started_at"] ?? root["timestamp"]),
                  let completedAt = UsageScanner.date(payload["completed_at"] ?? root["timestamp"]) else { return nil }
            return TaskExecutionEvent(id: turnID, threadID: threadID, title: title, projectName: projectName, startedAt: startedAt, kind: .completed(completedAt))
        case "turn_aborted":
            guard let abortedAt = UsageScanner.date(payload["completed_at"] ?? root["timestamp"]) else { return nil }
            return TaskExecutionEvent(id: turnID, threadID: threadID, title: title, projectName: projectName, startedAt: abortedAt, kind: .aborted(abortedAt))
        default:
            return nil
        }
    }

    nonisolated static func projectName(from cwd: String) -> String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "—" : name
    }

    nonisolated static func displayText(_ raw: String, maximumLength: Int) -> String {
        let singleLine = raw.split(whereSeparator: \.isNewline).joined(separator: " ")
        guard singleLine.count > maximumLength else { return singleLine }
        return String(singleLine.prefix(maximumLength)) + "…"
    }

    nonisolated static func visible(
        _ executions: [String: TaskExecution],
        now: Date
    ) -> [TaskExecution] {
        executions.values
            .filter { task in
                guard let completedAt = task.completedAt else { return true }
                return now.timeIntervalSince(completedAt) <= TaskExecution.completedVisibilityDuration
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted {
                    return $0.isCompleted
                }
                let left = $0.completedAt ?? $0.startedAt
                let right = $1.completedAt ?? $1.startedAt
                if left == right { return $0.id < $1.id }
                return left < right
            }
    }
}
