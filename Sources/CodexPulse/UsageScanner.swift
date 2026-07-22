import CSQLite
import Foundation

actor UsageScanner {
    struct ScanStatistics: Sendable, Equatable {
        var parsedJSONFiles = 0
    }

    private struct FileVersion: Equatable {
        let size: UInt64
        let modificationDate: Date
    }

    private struct ClaudeRecord {
        let usage: Usage
        let date: Date?
    }

    private struct ClaudeFileResult {
        var messages: [String: ClaudeRecord] = [:]
    }

    private struct CodexFileResult {
        var total = Usage.zero
        var daily: [Date: Usage] = [:]
        var limits: [Int: RateWindow] = [:]
    }

    private struct OpenCodeResult {
        var total = Usage.zero
        var daily: [Date: Usage] = [:]
        var error: String?
    }

    private struct Cached<Value> {
        let version: FileVersion
        let value: Value
    }

    private let home: URL
    private let enabledTools: Set<Tool>
    private var claudeCache: [String: Cached<ClaudeFileResult>] = [:]
    private var codexCache: [String: Cached<CodexFileResult>] = [:]
    private var openCodeCache: (
        database: FileVersion,
        wal: FileVersion?,
        sharedMemory: FileVersion?,
        result: OpenCodeResult
    )?
    private var statistics = ScanStatistics()

    init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        enabledTools: Set<Tool> = UsageSourcePolicy.enabledTools
    ) {
        self.home = home
        self.enabledTools = enabledTools
    }

    func scanStatistics() -> ScanStatistics { statistics }

    func scan() async -> Snapshot {
        let c = enabledTools.contains(.claude) ? scanClaude() : (.zero, [:], nil)
        let x = enabledTools.contains(.codex) ? scanCodex() : (.zero, [:], [], nil)
        let o = enabledTools.contains(.opencode) ? scanOpenCode() : (.zero, [:], nil)
        var result = Snapshot()
        if enabledTools.contains(.claude) {
            result.usage[.claude] = c.0; result.errors[.claude] = c.2
        }
        if enabledTools.contains(.codex) {
            result.usage[.codex] = x.0; result.errors[.codex] = x.3; result.limits = x.2
        }
        if enabledTools.contains(.opencode) {
            result.usage[.opencode] = o.0; result.errors[.opencode] = o.2
        }
        result.dailyUsage = Self.last14Days(
            claude: c.1,
            codex: x.1,
            openCode: o.1,
            enabledTools: enabledTools
        )
        return result
    }

    private func jsonFiles(in root: URL) -> [(URL, FileVersion)] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var files: [(URL, FileVersion)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  let modificationDate = values.contentModificationDate else { continue }
            files.append((url, FileVersion(size: UInt64(size), modificationDate: modificationDate)))
        }
        return files
    }

    private func scanClaude() -> (Usage, [Date: Usage], String?) {
        let root = home.appending(path: ".claude/projects")
        guard FileManager.default.fileExists(atPath: root.path) else {
            claudeCache.removeAll(keepingCapacity: false)
            return (.zero, [:], "未找到 ~/.claude/projects")
        }

        let files = jsonFiles(in: root)
        let livePaths = Set(files.map { $0.0.path })
        claudeCache = claudeCache.filter { livePaths.contains($0.key) }
        for (file, version) in files where claudeCache[file.path]?.version != version {
            claudeCache[file.path] = Cached(version: version, value: parseClaudeFile(file))
            statistics.parsedJSONFiles += 1
        }

        var seen: [String: ClaudeRecord] = [:]
        for cached in claudeCache.values {
            for (id, record) in cached.value.messages where record.usage.total > (seen[id]?.usage.total ?? -1) {
                seen[id] = record
            }
        }
        var total = Usage.zero
        var daily: [Date: Usage] = [:]
        for record in seen.values {
            total.add(record.usage)
            if let date = record.date { daily[Self.day(date), default: .zero].add(record.usage) }
        }
        return (total, daily, nil)
    }

    private func parseClaudeFile(_ file: URL) -> ClaudeFileResult {
        var result = ClaudeFileResult()
        try? Self.forEachJSONLine(in: file) { line in
            guard let root = Self.object(line), root["type"] as? String == "assistant",
                  let message = root["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any],
                  let id = message["id"] as? String else { return }
            var parsed = Usage(
                input: Self.int(usage["input_tokens"]),
                output: Self.int(usage["output_tokens"]),
                cacheRead: Self.int(usage["cache_read_input_tokens"]),
                cacheWrite: Self.int(usage["cache_creation_input_tokens"]),
                requests: 1
            )
            parsed.costUSD = Pricing.forModel(message["model"] as? String ?? "").cost(parsed)
            if parsed.total > (result.messages[id]?.usage.total ?? -1) {
                result.messages[id] = ClaudeRecord(usage: parsed, date: Self.date(root["timestamp"]))
            }
        }
        return result
    }

    private func scanCodex() -> (Usage, [Date: Usage], [RateWindow], String?) {
        let root = home.appending(path: ".codex/sessions")
        guard FileManager.default.fileExists(atPath: root.path) else {
            codexCache.removeAll(keepingCapacity: false)
            return (.zero, [:], [], "未找到 ~/.codex/sessions")
        }

        let files = jsonFiles(in: root)
        let livePaths = Set(files.map { $0.0.path })
        codexCache = codexCache.filter { livePaths.contains($0.key) }
        for (file, version) in files where codexCache[file.path]?.version != version {
            codexCache[file.path] = Cached(version: version, value: parseCodexFile(file))
            statistics.parsedJSONFiles += 1
        }

        var total = Usage.zero
        var daily: [Date: Usage] = [:]
        var limits: [Int: RateWindow] = [:]
        for cached in codexCache.values {
            total.add(cached.value.total)
            for (date, usage) in cached.value.daily { daily[date, default: .zero].add(usage) }
            for (minutes, window) in cached.value.limits
            where window.observedAt >= (limits[minutes]?.observedAt ?? .distantPast) {
                limits[minutes] = window
            }
        }
        return (total, daily, limits.values.sorted { $0.minutes < $1.minutes }, nil)
    }

    private func parseCodexFile(_ file: URL) -> CodexFileResult {
        var result = CodexFileResult()
        var model = "gpt-5"
        var previous: Usage?
        try? Self.forEachJSONLine(in: file) { line in
            guard let root = Self.object(line) else { return }
            if root["type"] as? String == "turn_context", let payload = root["payload"] as? [String: Any] {
                model = payload["model"] as? String ?? model
            }
            guard root["type"] as? String == "event_msg",
                  let payload = root["payload"] as? [String: Any],
                  payload["type"] as? String == "token_count" else { return }
            if let info = payload["info"] as? [String: Any],
               let tokens = info["total_token_usage"] as? [String: Any] {
                let current = Self.codexCumulativeUsage(tokens)
                var delta = Self.codexDelta(current: current, previous: previous)
                delta.costUSD = Pricing.forModel(model).cost(delta)
                if delta.total > 0 {
                    result.total.add(delta)
                    if let date = Self.date(root["timestamp"]) {
                        result.daily[Self.day(date), default: .zero].add(delta)
                    }
                }
                previous = current
            }
            if let rates = payload["rate_limits"] as? [String: Any] {
                Self.mergeRateLimits(rates, observedAt: Self.date(root["timestamp"]), into: &result.limits)
            }
        }
        return result
    }

    /// Calls `body` once per complete UTF-8 line without retaining the complete file.
    /// Extremely large malformed lines are discarded so a damaged log cannot grow memory without bound.
    nonisolated static func forEachJSONLine(
        in url: URL,
        chunkSize: Int = 64 * 1024,
        maximumLineLength: Int = 8 * 1024 * 1024,
        _ body: (Substring) -> Void
    ) throws {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var buffer = Data()
        buffer.reserveCapacity(min(chunkSize * 2, maximumLineLength))
        var discardingOversizedLine = false

        while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
            var chunkStart = chunk.startIndex
            if discardingOversizedLine {
                guard let newline = chunk[chunkStart...].firstIndex(of: 0x0A) else { continue }
                chunkStart = chunk.index(after: newline)
                discardingOversizedLine = false
            }
            if chunkStart < chunk.endIndex { buffer.append(contentsOf: chunk[chunkStart...]) }

            var lineStart = buffer.startIndex
            while let newline = buffer[lineStart...].firstIndex(of: 0x0A) {
                let lineData = buffer[lineStart..<newline]
                if lineData.count <= maximumLineLength {
                    autoreleasepool {
                        body(String(decoding: lineData, as: UTF8.self)[...])
                    }
                }
                lineStart = buffer.index(after: newline)
            }
            if lineStart > buffer.startIndex { buffer.removeSubrange(buffer.startIndex..<lineStart) }
            if buffer.count > maximumLineLength {
                buffer.removeAll(keepingCapacity: true)
                discardingOversizedLine = true
            }
        }
        if !discardingOversizedLine, !buffer.isEmpty, buffer.count <= maximumLineLength {
            autoreleasepool {
                body(String(decoding: buffer, as: UTF8.self)[...])
            }
        }
    }

    /// Codex reports cached input as a subset of `input_tokens`. Keep the two
    /// categories disjoint before taking cumulative deltas so totals and cost do
    /// not count cached tokens twice.
    nonisolated static func codexCumulativeUsage(_ tokens: [String: Any]) -> Usage {
        let cachedInput = max(0, int(tokens["cached_input_tokens"]))
        let inclusiveInput = max(0, int(tokens["input_tokens"]))
        return Usage(
            input: max(0, inclusiveInput - cachedInput),
            output: max(0, int(tokens["output_tokens"])),
            cacheRead: cachedInput,
            requests: 1
        )
    }

    nonisolated static func codexDelta(current: Usage, previous: Usage?) -> Usage {
        Usage(
            input: max(0, current.input - (previous?.input ?? 0)),
            output: max(0, current.output - (previous?.output ?? 0)),
            cacheRead: max(0, current.cacheRead - (previous?.cacheRead ?? 0)),
            requests: 1
        )
    }

    nonisolated static func mergeRateLimits(
        _ rates: [String: Any], observedAt: Date?, into limits: inout [Int: RateWindow]
    ) {
        for key in ["primary", "secondary", "individual_limit"] {
            guard let window = rates[key] as? [String: Any],
                  let minutes = (window["window_minutes"] as? NSNumber)?.intValue,
                  let reset = (window["resets_at"] as? NSNumber)?.doubleValue else { continue }
            let timestamp = observedAt ?? .distantPast
            guard timestamp >= (limits[minutes]?.observedAt ?? .distantPast) else { continue }
            let name = minutes <= 300 ? "5 小时额度" : minutes <= 10_080 ? "周额度" : "月额度"
            limits[minutes] = RateWindow(
                name: name,
                used: (window["used_percent"] as? NSNumber)?.doubleValue ?? 0,
                minutes: minutes,
                resetsAt: Date(timeIntervalSince1970: reset),
                observedAt: timestamp
            )
        }
    }

    private func scanOpenCode() -> (Usage, [Date: Usage], String?) {
        let url = home.appending(path: ".local/share/opencode/opencode.db")
        guard let databaseVersion = fileVersion(at: url) else {
            openCodeCache = nil
            return (.zero, [:], "未找到 OpenCode 数据库")
        }
        let walVersion = fileVersion(at: URL(fileURLWithPath: url.path + "-wal"))
        let sharedMemoryVersion = fileVersion(at: URL(fileURLWithPath: url.path + "-shm"))
        if let cached = openCodeCache,
           cached.database == databaseVersion,
           cached.wal == walVersion,
           cached.sharedMemory == sharedMemoryVersion {
            return (cached.result.total, cached.result.daily, cached.result.error)
        }

        let result = readOpenCodeDatabase(at: url.path)
        // Opening a WAL database can update shared-memory metadata. Capture the
        // post-read versions so our own read does not invalidate the next scan.
        openCodeCache = (
            fileVersion(at: url) ?? databaseVersion,
            fileVersion(at: URL(fileURLWithPath: url.path + "-wal")),
            fileVersion(at: URL(fileURLWithPath: url.path + "-shm")),
            result
        )
        return (result.total, result.daily, result.error)
    }

    private func readOpenCodeDatabase(at path: String) -> OpenCodeResult {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return OpenCodeResult(error: "无法只读打开 OpenCode 数据库")
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT data FROM message", -1, &statement, nil) == SQLITE_OK else {
            return OpenCodeResult(error: "OpenCode 数据库结构不兼容")
        }
        defer { sqlite3_finalize(statement) }
        var result = OpenCodeResult()
        while sqlite3_step(statement) == SQLITE_ROW {
            autoreleasepool {
                guard let cString = sqlite3_column_text(statement, 0),
                      let data = String(cString: cString).data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      value["role"] as? String == "assistant",
                      let tokens = value["tokens"] as? [String: Any],
                      (value["time"] as? [String: Any])?["completed"] != nil else { return }
                let cache = tokens["cache"] as? [String: Any]
                var usage = Usage(
                    input: Self.int(tokens["input"]),
                    output: Self.int(tokens["output"]) + Self.int(tokens["reasoning"]),
                    cacheRead: Self.int(cache?["read"]),
                    cacheWrite: Self.int(cache?["write"]),
                    requests: 1
                )
                usage.costUSD = (value["cost"] as? Double)
                    ?? Pricing.forModel(value["modelID"] as? String ?? "").cost(usage)
                if usage.total > 0 {
                    result.total.add(usage)
                    if let completed = (value["time"] as? [String: Any])?["completed"],
                       let date = Self.date(completed) {
                        result.daily[Self.day(date), default: .zero].add(usage)
                    }
                }
            }
        }
        return result
    }

    private func fileVersion(at url: URL) -> FileVersion? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize,
              let modificationDate = values.contentModificationDate else { return nil }
        return FileVersion(size: UInt64(size), modificationDate: modificationDate)
    }

    nonisolated static func last14Days(
        claude: [Date: Usage],
        codex: [Date: Usage],
        openCode: [Date: Usage],
        enabledTools: Set<Tool> = Set(Tool.allCases),
        now: Date = Date()
    ) -> [DailyUsage] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        return (0..<14).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            var usage: [Tool: Usage] = [:]
            if enabledTools.contains(.claude) { usage[.claude] = claude[date] ?? .zero }
            if enabledTools.contains(.codex) { usage[.codex] = codex[date] ?? .zero }
            if enabledTools.contains(.opencode) { usage[.opencode] = openCode[date] ?? .zero }
            return DailyUsage(date: date, usage: usage)
        }
    }

    nonisolated static func day(_ date: Date) -> Date { Calendar.current.startOfDay(for: date) }

    nonisolated static func date(_ value: Any?) -> Date? {
        if let value = value as? NSNumber {
            let seconds = value.doubleValue > 10_000_000_000 ? value.doubleValue / 1_000 : value.doubleValue
            return Date(timeIntervalSince1970: seconds)
        }
        guard let value = value as? String else { return nil }
        return try? Date(value, strategy: .iso8601)
    }

    nonisolated static func object(_ line: Substring) -> [String: Any]? {
        guard let data = line.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    nonisolated static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
}
