import Foundation

/// Monitors Claude Code session transcripts (`~/.claude/projects/*/*.jsonl`)
/// and derives task executions from turn boundaries: a plain user prompt
/// starts a turn, an assistant entry whose `stop_reason` is anything other
/// than `tool_use` ends it, and an interrupt marker aborts it. Claude Code
/// writes no explicit task events, so a running turn whose transcript stays
/// silent past `runningStaleInterval` is treated as abandoned.
actor ClaudeTaskMonitor {
    /// Slightly above the ten-minute ceiling of a single Bash tool call — the
    /// longest legitimately silent gap inside a live turn's transcript.
    static let runningStaleInterval: TimeInterval = 12 * 60
    /// Transcript files untouched for longer than this cannot contribute a
    /// visible task (completed tasks expire after ten minutes and running
    /// turns go stale after twelve), so they are never read at all.
    static let sourceFreshnessInterval: TimeInterval = 15 * 60
    /// First encounter of a large transcript starts this far from its end;
    /// the leading partial line fails JSON parsing and is skipped.
    static let initialTailBytes: UInt64 = 8 * 1024 * 1024
    static let maximumSourceCount = 24

    enum ParsedLine: Equatable, Sendable {
        case prompt(sessionID: String, cwd: String, uuid: String, text: String, date: Date)
        case turnEnd(sessionID: String, date: Date)
        case interrupted(sessionID: String, date: Date)
        case customTitle(sessionID: String, title: String)
        case aiTitle(sessionID: String, title: String)

        var threadID: String? {
            switch self {
            case .prompt(let sessionID, _, _, _, _),
                 .turnEnd(let sessionID, _),
                 .interrupted(let sessionID, _),
                 .customTitle(let sessionID, _),
                 .aiTitle(let sessionID, _):
                ClaudeTaskMonitor.threadID(sessionID)
            }
        }
    }

    private struct FileCursor {
        var offset: UInt64 = 0
        var remainder = Data()
    }

    private struct SessionState {
        var projectName = ""
        var customTitle = ""
        var aiTitle = ""
        var firstPromptTitle = ""
        var runningTaskID: String?
        var lastEventDate = Date.distantPast

        var title: String {
            let preferred = !customTitle.isEmpty ? customTitle
                : !aiTitle.isEmpty ? aiTitle
                : firstPromptTitle
            return preferred.isEmpty ? "Claude Code" : preferred
        }
    }

    private let home: URL
    private var cursors: [String: FileCursor] = [:]
    private var executions: [String: TaskExecution] = [:]
    /// Keyed by prefixed thread ID (`claude:<sessionId>`).
    private var sessions: [String: SessionState] = [:]
    /// Thread IDs observed per transcript path, so transcript growth counts
    /// as session activity even when the appended lines carry no parsed
    /// events (tool calls and tool results during a long turn).
    private var threadsByPath: [String: Set<String>] = [:]
    private var cachedSources: [URL]?
    private var lastSourceRefresh = Date.distantPast
    private let sourceRefreshInterval: TimeInterval = 5

    init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.home = home
    }

    func scan(now: Date = Date()) -> [TaskExecution] {
        let sources = recentTranscripts(now: now)
        let livePaths = Set(sources.map(\.path))
        cursors = cursors.filter { livePaths.contains($0.key) }
        threadsByPath = threadsByPath.filter { livePaths.contains($0.key) }

        for source in sources {
            let read = readNewLines(from: source)
            var threads = threadsByPath[source.path] ?? []
            for line in read.lines {
                apply(line)
                if let threadID = line.threadID { threads.insert(threadID) }
            }
            threadsByPath[source.path] = threads
            guard let activityDate = read.activityDate else { continue }
            for threadID in threads {
                guard var state = sessions[threadID] else { continue }
                state.lastEventDate = max(state.lastEventDate, activityDate)
                sessions[threadID] = state
            }
        }

        dropStaleRunningTasks(now: now)
        pruneExpired(now: now)

        for (id, var task) in executions {
            guard let state = sessions[task.threadID] else { continue }
            task.title = state.title
            if !state.projectName.isEmpty { task.projectName = state.projectName }
            executions[id] = task
        }

        return TaskMonitor.visible(executions, now: now)
    }

    // MARK: - Sources

    private func recentTranscripts(now: Date) -> [URL] {
        if let cachedSources, now.timeIntervalSince(lastSourceRefresh) < sourceRefreshInterval {
            return cachedSources
        }
        let root = home.appending(path: ".claude/projects")
        let projectDirectories = (try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        var fresh: [(URL, Date)] = []
        for directory in projectDirectories {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
            )) ?? []
            for file in files where file.pathExtension == "jsonl" {
                guard let values = try? file.resourceValues(
                    forKeys: [.contentModificationDateKey, .isRegularFileKey]
                ), values.isRegularFile == true,
                      let modified = values.contentModificationDate,
                      now.timeIntervalSince(modified) <= Self.sourceFreshnessInterval else { continue }
                fresh.append((file, modified))
            }
        }
        let sources = fresh
            .sorted { $0.1 > $1.1 }
            .prefix(Self.maximumSourceCount)
            .map(\.0)
        cachedSources = sources
        lastSourceRefresh = now
        return sources
    }

    private struct ReadResult {
        var lines: [ParsedLine] = []
        /// Transcript modification date when new bytes were appended, `nil`
        /// when the file did not grow. Growth marks its sessions as active.
        var activityDate: Date?
    }

    private func readNewLines(from source: URL) -> ReadResult {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: source.path),
              let byteCount = (attributes[.size] as? NSNumber)?.uint64Value else { return ReadResult() }

        var cursor: FileCursor
        if let existing = cursors[source.path], existing.offset <= byteCount {
            cursor = existing
        } else {
            cursor = FileCursor()
            if byteCount > Self.initialTailBytes {
                cursor.offset = byteCount - Self.initialTailBytes
            }
        }
        guard byteCount > cursor.offset,
              let handle = FileHandle(forReadingAtPath: source.path) else { return ReadResult() }
        defer { try? handle.close() }

        do {
            try handle.seek(toOffset: cursor.offset)
            var lines: [ParsedLine] = []
            while let data = try handle.read(upToCount: 64 * 1024), !data.isEmpty {
                cursor.offset += UInt64(data.count)
                cursor.remainder.append(data)
                var lineStart = cursor.remainder.startIndex
                while let newline = cursor.remainder[lineStart...].firstIndex(of: 0x0A) {
                    autoreleasepool {
                        let line = String(decoding: cursor.remainder[lineStart..<newline], as: UTF8.self)
                        if let parsed = Self.parseLine(line[...]) {
                            lines.append(parsed)
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
            return ReadResult(
                lines: lines,
                activityDate: attributes[.modificationDate] as? Date ?? Date()
            )
        } catch {
            return ReadResult()
        }
    }

    // MARK: - State

    private func apply(_ line: ParsedLine) {
        switch line {
        case .prompt(let sessionID, let cwd, let uuid, let text, let date):
            let threadID = Self.threadID(sessionID)
            var state = sessions[threadID] ?? SessionState()
            state.projectName = TaskMonitor.projectName(from: cwd)
            state.lastEventDate = max(state.lastEventDate, date)
            if state.firstPromptTitle.isEmpty {
                state.firstPromptTitle = TaskMonitor.displayText(text, maximumLength: 80)
            }
            let message = TaskMonitor.displayText(text, maximumLength: 160)
            if let runningID = state.runningTaskID, executions[runningID]?.isCompleted == false {
                executions[runningID]?.latestUserMessage = message
            } else {
                let id = "claude:\(uuid)"
                executions[id] = TaskExecution(
                    id: id,
                    threadID: threadID,
                    tool: .claude,
                    title: state.title,
                    projectName: state.projectName,
                    latestUserMessage: message,
                    startedAt: date,
                    completedAt: nil
                )
                state.runningTaskID = id
            }
            sessions[threadID] = state
        case .turnEnd(let sessionID, let date):
            let threadID = Self.threadID(sessionID)
            guard var state = sessions[threadID] else { return }
            state.lastEventDate = max(state.lastEventDate, date)
            if let runningID = state.runningTaskID {
                executions[runningID]?.completedAt = date
                state.runningTaskID = nil
            }
            sessions[threadID] = state
        case .interrupted(let sessionID, let date):
            let threadID = Self.threadID(sessionID)
            guard var state = sessions[threadID] else { return }
            state.lastEventDate = max(state.lastEventDate, date)
            if let runningID = state.runningTaskID {
                executions.removeValue(forKey: runningID)
                state.runningTaskID = nil
            }
            sessions[threadID] = state
        case .customTitle(let sessionID, let title):
            sessions[Self.threadID(sessionID), default: SessionState()].customTitle = title
        case .aiTitle(let sessionID, let title):
            sessions[Self.threadID(sessionID), default: SessionState()].aiTitle = title
        }
    }

    private func dropStaleRunningTasks(now: Date) {
        for (threadID, state) in sessions {
            guard let runningID = state.runningTaskID,
                  now.timeIntervalSince(state.lastEventDate) > Self.runningStaleInterval else { continue }
            executions.removeValue(forKey: runningID)
            sessions[threadID]?.runningTaskID = nil
        }
    }

    private func pruneExpired(now: Date) {
        executions = executions.filter { _, task in
            guard let completedAt = task.completedAt else { return true }
            return now.timeIntervalSince(completedAt) <= TaskExecution.completedVisibilityDuration
        }
        sessions = sessions.filter { _, state in
            state.runningTaskID != nil
                || now.timeIntervalSince(state.lastEventDate) <= Self.sourceFreshnessInterval
        }
    }

    // MARK: - Parsing

    nonisolated static func threadID(_ sessionID: String) -> String { "claude:\(sessionID)" }

    nonisolated static func parseLine(_ line: Substring) -> ParsedLine? {
        guard let root = UsageScanner.object(line),
              let type = root["type"] as? String else { return nil }

        switch type {
        case "custom-title":
            guard let sessionID = root["sessionId"] as? String,
                  let title = root["customTitle"] as? String, !title.isEmpty else { return nil }
            return .customTitle(sessionID: sessionID, title: TaskMonitor.displayText(title, maximumLength: 80))
        case "ai-title":
            guard let sessionID = root["sessionId"] as? String,
                  let title = root["aiTitle"] as? String, !title.isEmpty else { return nil }
            return .aiTitle(sessionID: sessionID, title: TaskMonitor.displayText(title, maximumLength: 80))
        case "user", "assistant":
            break
        default:
            return nil
        }

        guard root["isSidechain"] as? Bool != true,
              let sessionID = root["sessionId"] as? String,
              let message = root["message"] as? [String: Any],
              let date = UsageScanner.date(root["timestamp"]) else { return nil }

        if type == "assistant" {
            guard let stopReason = message["stop_reason"] as? String,
                  stopReason != "tool_use" else { return nil }
            return .turnEnd(sessionID: sessionID, date: date)
        }

        guard root["isMeta"] as? Bool != true,
              root["isCompactSummary"] as? Bool != true,
              let text = promptText(message["content"]) else { return nil }
        if text.hasPrefix("[Request interrupted") {
            return .interrupted(sessionID: sessionID, date: date)
        }
        guard !text.isEmpty, !text.hasPrefix("<command-"), !text.hasPrefix("<local-command") else {
            return nil
        }
        return .prompt(
            sessionID: sessionID,
            cwd: root["cwd"] as? String ?? "",
            uuid: root["uuid"] as? String ?? "\(sessionID)-\(date.timeIntervalSince1970)",
            text: text,
            date: date
        )
    }

    /// Plain prompt text of a user entry. Tool results are not prompts; text
    /// blocks (used for queued and interrupt messages) are joined in order.
    private nonisolated static func promptText(_ content: Any?) -> String? {
        if let text = content as? String { return text }
        guard let blocks = content as? [[String: Any]] else { return nil }
        var texts: [String] = []
        for block in blocks {
            switch block["type"] as? String {
            case "text":
                if let text = block["text"] as? String { texts.append(text) }
            case "tool_result":
                return nil
            default:
                continue
            }
        }
        return texts.isEmpty ? nil : texts.joined(separator: " ")
    }
}
