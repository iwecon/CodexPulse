import CSQLite
import Darwin
import Foundation

actor TaskMonitor {
    static let runningStaleInterval: TimeInterval = 3 * 60
    private static let eventMessageMarker = Data(#""type":"event_msg""#.utf8)
    private static let responseItemMarker = Data(#""type":"response_item""#.utf8)
    private static let responseUserRoleMarker = Data(#""role":"user""#.utf8)
    private static let responseInputTextMarker = Data(#""type":"input_text""#.utf8)
    private static let relevantEventMarkers = [
        "user_message", "thread_goal_updated", "task_started", "task_complete", "turn_aborted",
    ].map { Data("\"type\":\"\($0)\"".utf8) }
    private struct ThreadSource {
        let id: String
        let title: String
        let projectName: String
        let path: String
    }

    private struct FileCursor {
        var offset: UInt64 = 0
        var remainder = Data()
        var discardingLine = false
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
        autoreleasepool { scanContents(now: now) }
    }

    private func scanContents(now: Date) -> [TaskExecution] {
        guard !Task.isCancelled else { return [] }
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
            guard !Task.isCancelled else { return [] }
            events.append(contentsOf: readNewEvents(from: source))
        }
        guard !Task.isCancelled else { return [] }
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
        while !Task.isCancelled, sqlite3_step(statement) == SQLITE_ROW {
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
            let startingOffset = cursor.offset
            var events: [TaskExecutionEvent] = []
            var hasUnstampedData = false
            while try autoreleasepool(invoking: { () throws -> Bool in
                guard !Task.isCancelled else { return false }
                guard let data = try handle.read(upToCount: 64 * 1024), !data.isEmpty else { return false }
                cursor.offset += UInt64(data.count)
                var searchStart = cursor.remainder.endIndex
                cursor.remainder.append(data)
                var lineStart = cursor.remainder.startIndex
                while let newline = Self.newline(in: cursor.remainder, from: searchStart) {
                    guard !Task.isCancelled else { return false }
                    if cursor.discardingLine {
                        cursor.discardingLine = false
                        lineStart = cursor.remainder.index(after: newline)
                        searchStart = lineStart
                        continue
                    }
                    let lineData = cursor.remainder[lineStart..<newline]
                    let isRelevantEvent = lineData.range(of: Self.eventMessageMarker) != nil
                        && Self.relevantEventMarkers.contains { lineData.range(of: $0) != nil }
                    let isResponseUserMessage = lineData.range(of: Self.responseItemMarker) != nil
                        && lineData.range(of: Self.responseUserRoleMarker) != nil
                        && lineData.range(of: Self.responseInputTextMarker) != nil
                    if isRelevantEvent || isResponseUserMessage {
                        let line = String(decoding: lineData, as: UTF8.self)
                        if let event = Self.parseEvent(
                            line[...],
                            threadID: source.id,
                            title: source.title,
                            projectName: source.projectName
                        ) {
                            events.append(event)
                        }
                    }
                    if let activityAt = Self.activityTimestamp(in: lineData) {
                        if case .activity = events.last?.kind { events.removeLast() }
                        events.append(TaskExecutionEvent(
                            id: source.id, threadID: source.id, title: source.title,
                            projectName: source.projectName, startedAt: activityAt,
                            kind: .activity(activityAt)
                        ))
                    } else {
                        hasUnstampedData = true
                    }
                    lineStart = cursor.remainder.index(after: newline)
                    searchStart = lineStart
                }
                if lineStart > cursor.remainder.startIndex {
                    cursor.remainder = Data(cursor.remainder[lineStart...])
                }
                let prefix = cursor.remainder.prefix(4096)
                if cursor.discardingLine || (cursor.remainder.count > 4096 && Self.canDiscardLongRecord(prefix))
                    || cursor.remainder.count > 8 * 1024 * 1024 {
                    // Ordinary long output need not be assembled in memory. Keep
                    // its timestamp, then skip through its newline across reads.
                    if !cursor.discardingLine, let activityAt = Self.activityTimestamp(in: prefix) {
                        if case .activity = events.last?.kind { events.removeLast() }
                        events.append(TaskExecutionEvent(
                            id: source.id, threadID: source.id, title: source.title,
                            projectName: source.projectName, startedAt: activityAt,
                            kind: .activity(activityAt)
                        ))
                    }
                    cursor.discardingLine = true
                    cursor.remainder.removeAll(keepingCapacity: false)
                }
                return true
            }) {}
            guard !Task.isCancelled else { return [] }
            // Every live append counts, even replayed timestamps or partial writes.
            // Cold replay uses envelope times, with historical file time only when
            // a partial/malformed record cannot supply its timestamp.
            if startingOffset > 0 || !cursor.remainder.isEmpty || cursor.discardingLine || hasUnstampedData,
               let activityAt = attributes[.modificationDate] as? Date {
                events.append(TaskExecutionEvent(
                    id: source.id, threadID: source.id, title: source.title,
                    projectName: source.projectName, startedAt: activityAt,
                    kind: .activity(activityAt)
                ))
            }
            cursors[source.path] = cursor
            if cursor.offset - startingOffset >= 16 * 1024 * 1024 {
                malloc_zone_pressure_relief(nil, 0)
            }
            return events
        } catch {
            return []
        }
    }

    private func apply(_ event: TaskExecutionEvent) {
        Self.apply(
            event,
            to: &executions,
            pendingUserMessages: &pendingUserMessages
        )
    }

    nonisolated static func apply(
        _ event: TaskExecutionEvent,
        to executions: inout [String: TaskExecution],
        pendingUserMessages: inout [String: String]
    ) {
        switch event.kind {
        case .activity(let activityAt):
            guard let id = executions.values
                .filter({ $0.threadID == event.threadID && $0.status == .running && $0.startedAt <= activityAt })
                .max(by: { $0.startedAt < $1.startedAt })?.id else { return }
            let previous = executions[id]?.lastActivityAt ?? .distantPast
            executions[id]?.lastActivityAt = max(previous, activityAt)
        case .started:
            if let current = executions[event.id], current.completedAt != nil { return }
            let inheritedMessage = executions.values
                .filter { $0.threadID == event.threadID && !$0.latestUserMessage.isEmpty }
                .max(by: { $0.startedAt < $1.startedAt })?.latestUserMessage ?? ""
            for (id, task) in executions where task.threadID == event.threadID
                && id != event.id && task.status == .running && task.startedAt <= event.startedAt {
                executions[id]?.completedAt = task.lastActivityAt ?? task.startedAt
                executions[id]?.terminalStatus = .paused
            }
            executions[event.id] = TaskExecution(
                id: event.id,
                threadID: event.threadID,
                title: event.title,
                projectName: event.projectName,
                latestUserMessage: pendingUserMessages.removeValue(forKey: event.threadID)
                    ?? inheritedMessage,
                startedAt: event.startedAt,
                completedAt: nil,
                terminalStatus: nil,
                lastActivityAt: event.startedAt
            )
        case .completed(let completedAt):
            let current = executions[event.id]
            executions[event.id] = TaskExecution(
                id: event.id,
                threadID: event.threadID,
                title: event.title,
                projectName: current?.projectName ?? event.projectName,
                latestUserMessage: current?.latestUserMessage ?? "",
                startedAt: current?.startedAt ?? event.startedAt,
                completedAt: completedAt,
                terminalStatus: nil
            )
        case .aborted(let abortedAt):
            let current = executions[event.id]
            executions[event.id] = TaskExecution(
                id: event.id,
                threadID: event.threadID,
                title: event.title,
                projectName: current?.projectName ?? event.projectName,
                latestUserMessage: current?.latestUserMessage ?? "",
                startedAt: current?.startedAt ?? event.startedAt,
                completedAt: abortedAt,
                terminalStatus: .paused
            )
        case .goalPaused(let pausedAt):
            guard let taskID = executions.values
                .filter({ $0.threadID == event.threadID && ($0.status == .paused || $0.status == .running) })
                .max(by: { $0.startedAt < $1.startedAt })?.id else { return }
            executions[taskID]?.completedAt = pausedAt
            executions[taskID]?.terminalStatus = .paused
        case .userMessage(let message, _):
            if executions[event.id]?.threadID == event.threadID,
               executions[event.id]?.status == .running {
                executions[event.id]?.latestUserMessage = message
            } else if let id = executions.values
                .filter({ $0.threadID == event.threadID && $0.status == .running })
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
        guard let root = UsageScanner.object(line),
              let rootType = root["type"] as? String else { return nil }

        if rootType == "response_item" {
            return parseResponseUserMessage(
                root,
                threadID: threadID,
                title: title,
                projectName: projectName
            )
        }

        guard rootType == "event_msg",
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

        if type == "thread_goal_updated" {
            guard let goal = payload["goal"] as? [String: Any],
                  goal["status"] as? String == "paused",
                  let pausedAt = UsageScanner.date(root["timestamp"]) else { return nil }
            return TaskExecutionEvent(
                id: threadID,
                threadID: threadID,
                title: title,
                projectName: projectName,
                startedAt: pausedAt,
                kind: .goalPaused(pausedAt)
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
            guard payload["reason"] as? String == "interrupted",
                  let abortedAt = UsageScanner.date(payload["completed_at"] ?? root["timestamp"]),
                  let startedAt = UsageScanner.date(payload["started_at"] ?? root["timestamp"]) else { return nil }
            return TaskExecutionEvent(id: turnID, threadID: threadID, title: title, projectName: projectName, startedAt: startedAt, kind: .aborted(abortedAt))
        default:
            return nil
        }
    }

    /// Only discard recognized non-task envelopes. Unknown formats retain the
    /// existing bounded-line fallback rather than risking a missed user event.
    private nonisolated static func canDiscardLongRecord(_ prefix: Data.SubSequence) -> Bool {
        func value(after marker: String) -> String? {
            guard let range = prefix.range(of: Data(marker.utf8)),
                  let end = prefix[range.upperBound...].firstIndex(of: 0x22) else { return nil }
            return String(decoding: prefix[range.upperBound..<end], as: UTF8.self)
        }
        switch value(after: #""type":""#) {
        case "turn_context", "session_meta": return true
        case "response_item":
            switch value(after: #""payload":{"type":""#) {
            case "function_call", "function_call_output", "custom_tool_call", "custom_tool_call_output", "reasoning":
                return true
            case "message":
                return ["assistant", "developer", "system"].contains(value(after: #""role":""#) ?? "")
            default: return false
            }
        case "event_msg":
            return ["token_count", "item_completed", "agent_message", "agent_reasoning", "thread_settings_applied"]
                .contains(value(after: #""payload":{"type":""#) ?? "")
        default: return false
        }
    }

    /// Scan only bytes appended since the previous incomplete-line search.
    /// memchr avoids per-byte Data indexing and quadratic rescans of long output.
    private nonisolated static func newline(in data: Data, from start: Int) -> Int? {
        guard start < data.endIndex else { return nil }
        return data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress,
                  let found = memchr(base.advanced(by: start - data.startIndex), 0x0A, data.endIndex - start) else { return nil }
            return data.startIndex + base.distance(to: found)
        }
    }

    nonisolated static func activityTimestamp(in data: Data.SubSequence) -> Date? {
        let prefix = data.prefix(128)
        let marker = Data(#""timestamp":""#.utf8)
        guard let range = prefix.range(of: marker),
              let end = prefix[range.upperBound...].firstIndex(of: 0x22) else { return nil }
        return UsageScanner.date(String(decoding: prefix[range.upperBound..<end], as: UTF8.self))
    }

    private nonisolated static func parseResponseUserMessage(
        _ root: [String: Any],
        threadID: String,
        title: String,
        projectName: String
    ) -> TaskExecutionEvent? {
        guard let payload = root["payload"] as? [String: Any],
              payload["type"] as? String == "message",
              payload["role"] as? String == "user",
              let content = payload["content"] as? [[String: Any]],
              let messageAt = UsageScanner.date(root["timestamp"]) else { return nil }

        let rawMessage = content.compactMap { item -> String? in
            guard item["type"] as? String == "input_text",
                  let text = item["text"] as? String,
                  !isInjectedUserContext(text) else { return nil }
            return text
        }.joined(separator: "\n")
        let message = displayText(rawMessage, maximumLength: 160)
        guard !message.isEmpty else { return nil }

        let metadata = payload["internal_chat_message_metadata_passthrough"] as? [String: Any]
        let turnID = metadata?["turn_id"] as? String
        return TaskExecutionEvent(
            id: turnID ?? threadID,
            threadID: threadID,
            title: title,
            projectName: projectName,
            startedAt: messageAt,
            kind: .userMessage(message, messageAt)
        )
    }

    private nonisolated static func isInjectedUserContext(_ raw: String) -> Bool {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.hasPrefix("<codex_internal_context ")
            || text.hasPrefix("<recommended_plugins>")
            || text.hasPrefix("# AGENTS.md instructions for ")
            || text.hasPrefix("<environment_context>")
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
        sortedForDisplay(executions.values.compactMap { stored -> TaskExecution? in
            var task = stored
            if task.tool == .codex, task.status == .running, let activityAt = task.lastActivityAt,
               now.timeIntervalSince(activityAt) >= runningStaleInterval {
                task.completedAt = activityAt
                task.terminalStatus = .paused
            }
            guard let completedAt = task.completedAt else { return task }
            let age = now.timeIntervalSince(completedAt)
            let isVisible = task.status == .paused
                ? age < TaskExecution.completedVisibilityDuration
                : age <= TaskExecution.completedVisibilityDuration
            return isVisible ? task : nil
        })
    }

    /// Shared display order for tasks from every monitored tool, so merged
    /// per-tool scans produce one stable list.
    nonisolated static func sortedForDisplay(_ tasks: [TaskExecution]) -> [TaskExecution] {
        tasks.sorted {
            if $0.isTerminal != $1.isTerminal {
                return $0.isTerminal
            }
            let left = $0.completedAt ?? $0.startedAt
            let right = $1.completedAt ?? $1.startedAt
            if left == right { return $0.id < $1.id }
            return left < right
        }
    }
}
