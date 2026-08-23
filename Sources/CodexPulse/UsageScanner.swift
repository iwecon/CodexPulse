import CSQLite
import CryptoKit
import Darwin
import Foundation

actor UsageScanner {
    struct ScanStatistics: Sendable, Equatable {
        var parsedJSONFiles = 0
        var parsedJSONBytes: UInt64 = 0
        var parsedOpenCodeRows = 0
        var activeJSONFiles = 0
        var retainedUsageRecords = 0
        var retainedCodexFileReferences = 0
        var acceleratedCodexFiles = 0
    }

    private struct FileVersion: Sendable, Equatable {
        let size: UInt64
        let modificationDate: Date
    }

    private struct ClaudeRecord {
        let usage: Usage
        let date: Date
    }

    private struct ClaudeFileCache {
        var version: FileVersion
        var offset: UInt64
        var continuity: Data
        var messages: [RecordFingerprint: ClaudeRecord]
    }

    private struct CodexRecord: Sendable, Equatable {
        let usage: Usage
        let date: Date
    }

    /// Cold scans use contiguous compact candidates only until aggregation.
    /// Codex records never use cache-write tokens and every token event is one
    /// request, so those constants are omitted before the temporary candidates
    /// are discarded in favor of the summary, fingerprints, and cursors.
    private struct CompactCodexRecord: Sendable {
        let key: RecordFingerprint
        let timestamp: TimeInterval
        let input: UInt32
        let output: UInt32
        let cacheRead: UInt32
        let costUSD: Float

        init(key: RecordFingerprint, record: CodexRecord) {
            self.key = key
            timestamp = record.date.timeIntervalSince1970
            // One token event is bounded by a model context window and is
            // therefore far below UInt32.max. Clamp corrupted source values
            // rather than widening every retained record to three machine
            // words.
            input = UInt32(clamping: max(0, record.usage.input))
            output = UInt32(clamping: max(0, record.usage.output))
            cacheRead = UInt32(clamping: max(0, record.usage.cacheRead))
            costUSD = Float(record.usage.costUSD)
        }

        var record: CodexRecord {
            CodexRecord(
                usage: Usage(
                    input: Int(input),
                    output: Int(output),
                    cacheRead: Int(cacheRead),
                    costUSD: Double(costUSD),
                    requests: 1
                ),
                date: Date(timeIntervalSince1970: timestamp)
            )
        }
    }

    private struct CodexParserState: Sendable {
        var pricing = Pricing.forModel("gpt-5")
        var previous: Usage?
        var sessionID: String?
    }

    private struct CodexFileCache: Sendable {
        var version: FileVersion
        var offset: UInt64
        var continuity: Data
        var records: [CompactCodexRecord]
        var limits: [Int: RateWindow]
        var parser: CodexParserState
    }

    private struct CodexFileUpdate {
        var changed = false
        var canMergeIncrementally = true
        var records: [RecordFingerprint: CodexRecord] = [:]
    }

    /// A cold-filter batch mutates one file state once per token event. Keep
    /// that state reference-owned and append directly to its final compact
    /// storage so cold workers never build a transient per-file hash table.
    private final class ColdCodexState {
        var records: [CompactCodexRecord] = []
        var limits: [Int: RateWindow] = [:]
        var parser = CodexParserState()
    }

    private struct ColdCodexBatchResult: Sendable {
        var caches: [String: CodexFileCache] = [:]
        var parsedBytes: UInt64 = 0
        var inputFileCount = 0
        var succeeded = false
    }

    private struct OpenCodeRecord {
        let usage: Usage
        let date: Date?
        let updatedMilliseconds: Int64
    }

    /// Compact process-local identity for recent deduplication. Source IDs are
    /// never copied into aggregate dictionaries, which materially reduces the
    /// footprint of large 14-day windows.
    private struct RecordFingerprint: Hashable {
        let high: UInt64
        let low: UInt64

        init(_ value: String) {
            var high: UInt64 = 0xcbf29ce484222325
            var low: UInt64 = 0x84222325cbf29ce4
            for byte in value.utf8 {
                high = (high ^ UInt64(byte)) &* 0x100000001b3
                low = (low ^ UInt64(byte &+ 0x9d)) &* 0x100000001b3
            }
            self.high = high
            self.low = low
        }

        init(session: String, cumulative: Usage) {
            var high: UInt64 = 0xcbf29ce484222325
            var low: UInt64 = 0x84222325cbf29ce4
            func mix(_ byte: UInt8) {
                high = (high ^ UInt64(byte)) &* 0x100000001b3
                low = (low ^ UInt64(byte &+ 0x9d)) &* 0x100000001b3
            }
            for byte in session.utf8 { mix(byte) }
            mix(0xFF)
            for value in [cumulative.input, cumulative.cacheRead, cumulative.output] {
                var bits = UInt64(bitPattern: Int64(value)).littleEndian
                withUnsafeBytes(of: &bits) { bytes in
                    for byte in bytes { mix(byte) }
                }
                mix(0xFE)
            }
            self.high = high
            self.low = low
        }
    }

    private struct OpenCodeCache {
        var database: FileVersion
        var wal: FileVersion?
        var sharedMemory: FileVersion?
        var records: [String: OpenCodeRecord]
        var error: String?
    }

    private static let claudeAssistantMarker = Data(#""type":"assistant""#.utf8)
    private static let usageMarker = Data(#""usage""#.utf8)
    private static let sessionMetaMarker = Data(#""type":"session_meta""#.utf8)
    private static let turnContextMarker = Data(#""type":"turn_context""#.utf8)
    private static let tokenCountMarker = Data(#""type":"token_count""#.utf8)
    private static let coldCodexWorkerLimit = 8
    private static let codexColdFilterAWK = #"""
        {
            separator = index($0, ":{")
            if (!separator) next
            path = substr($0, 1, separator - 1)
            json = substr($0, separator + 1)
            if (path != previous_path) {
                print "F\t" path
                previous_path = path
            }
            if (index(json, "\"type\":\"turn_context\"") && match(json, /\"model\":\"[^\"]*\"/)) {
                print "M\t" substr(json, RSTART + 9, RLENGTH - 10)
            } else if (index(json, "\"type\":\"token_count\"")) {
                print json
            }
        }
        """#

    private let home: URL
    private let enabledTools: Set<Tool>
    private let calendar: Calendar
    private var claudeCache: [String: ClaudeFileCache] = [:]
    private var codexCache: [String: CodexFileCache] = [:]
    private var mergedCodexRecords: [RecordFingerprint: CodexRecord] = [:]
    private var codexSeenRecords: Set<RecordFingerprint> = []
    private var openCodeCache: OpenCodeCache?
    private var claudeAggregateCache: (cutoff: Date, total: Usage, daily: [Date: Usage])?
    private var codexAggregateCache: (
        cutoff: Date,
        total: Usage,
        daily: [Date: Usage],
        limits: [RateWindow],
        windowTokens: Int?,
        windowStart: Date?
    )?
    private var statistics = ScanStatistics()
    private var jsonBytesSincePressureRelief: UInt64 = 0

    init(
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        enabledTools: Set<Tool> = UsageSourcePolicy.enabledTools,
        calendar: Calendar = .current
    ) {
        self.home = home
        self.enabledTools = enabledTools
        self.calendar = calendar
    }

    func scanStatistics() -> ScanStatistics { statistics }

    func scan(now: Date = Date()) async -> Snapshot {
        let bytesBeforeScan = statistics.parsedJSONBytes
        let cutoff = Self.cutoff(now: now, calendar: calendar)
        let c = enabledTools.contains(.claude) ? scanClaude(cutoff: cutoff) : (.zero, [:], nil)
        let x = enabledTools.contains(.codex) ? await scanCodex(cutoff: cutoff) : (.zero, [:], [], nil, nil)
        let o = enabledTools.contains(.opencode) ? scanOpenCode(cutoff: cutoff) : (.zero, [:], nil)
        var result = Snapshot()
        if enabledTools.contains(.claude) {
            result.usage[.claude] = c.0
            result.errors[.claude] = c.2
        }
        if enabledTools.contains(.codex) {
            result.usage[.codex] = x.0
            result.errors[.codex] = x.4
            result.limits = x.2
            result.codexTokensInWeeklyWindow = x.3
        }
        if enabledTools.contains(.opencode) {
            result.usage[.opencode] = o.0
            result.errors[.opencode] = o.2
        }
        result.dailyUsage = Self.last14Days(
            claude: c.1,
            codex: x.1,
            openCode: o.1,
            enabledTools: enabledTools,
            now: now,
            calendar: calendar
        )
        result.updatedAt = now
        statistics.activeJSONFiles = claudeCache.count + codexCache.count
        statistics.retainedUsageRecords = claudeCache.values.reduce(0) { $0 + $1.messages.count }
            + codexSeenRecords.count
            + (openCodeCache?.records.count ?? 0)
        statistics.retainedCodexFileReferences = codexCache.values.reduce(0) {
            $0 + $1.records.count
        }
        if statistics.parsedJSONBytes > bytesBeforeScan {
            // Foundation JSON parsing creates many short-lived malloc blocks.
            // Return their now-empty pages after a large cold/rebuild scan so
            // physical memory follows retained 14-day state, not allocator high-water marks.
            malloc_zone_pressure_relief(nil, 0)
            jsonBytesSincePressureRelief = 0
        }
        return result
    }

    private static func cutoff(now: Date, calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -13, to: today) ?? today
    }

    private func recentJSONFiles(in root: URL, cutoff: Date) -> [(URL, FileVersion)] {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var files: [(URL, FileVersion)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize,
                  let modificationDate = values.contentModificationDate,
                  modificationDate >= cutoff else { continue }
            files.append((url, FileVersion(size: UInt64(size), modificationDate: modificationDate)))
        }
        return files
    }

    // MARK: - Claude Code

    private func scanClaude(cutoff: Date) -> (Usage, [Date: Usage], String?) {
        let root = home.appending(path: ".claude/projects")
        guard FileManager.default.fileExists(atPath: root.path) else {
            claudeCache.removeAll(keepingCapacity: false)
            claudeAggregateCache = nil
            return (.zero, [:], "未找到 ~/.claude/projects")
        }
        let files = recentJSONFiles(in: root, cutoff: cutoff)
        let livePaths = Set(files.map(\.0.path))
        var changed = livePaths != Set(claudeCache.keys)
        claudeCache = claudeCache.filter { livePaths.contains($0.key) }
        for (file, version) in files {
            changed = updateClaudeFile(file, version: version, cutoff: cutoff) || changed
        }
        let cutoffChanged = claudeAggregateCache?.cutoff != cutoff
        changed = changed || cutoffChanged
        if cutoffChanged {
            for path in Array(claudeCache.keys) {
                guard var cached = claudeCache.removeValue(forKey: path) else { continue }
                let oldCount = cached.messages.count
                cached.messages = cached.messages.filter { $0.value.date >= cutoff }
                changed = changed || cached.messages.count != oldCount
                claudeCache[path] = cached
            }
        }
        if !changed, let aggregate = claudeAggregateCache {
            return (aggregate.total, aggregate.daily, nil)
        }
        var seen: [RecordFingerprint: ClaudeRecord] = [:]
        for cached in claudeCache.values {
            for (id, record) in cached.messages where record.usage.total > (seen[id]?.usage.total ?? -1) {
                seen[id] = record
            }
        }
        let aggregate = Self.aggregate(seen.values.map { ($0.usage, $0.date) }, calendar: calendar)
        claudeAggregateCache = (cutoff, aggregate.0, aggregate.1)
        return aggregate
    }

    private func updateClaudeFile(_ file: URL, version: FileVersion, cutoff: Date) -> Bool {
        let path = file.path
        if claudeCache[path]?.version == version { return false }
        var cached = claudeCache.removeValue(forKey: path)
        let canContinue = cached.map {
            version.size > $0.version.size && version.size >= $0.offset
                && Self.continuity(in: file, at: $0.offset) == $0.continuity
        } ?? false
        if !canContinue { cached = nil }
        var messages = cached?.messages ?? [:]
        let start = cached?.offset ?? Self.initialScanOffset(
            in: file,
            size: version.size,
            cutoff: cutoff
        )
        do {
            let progress = try Self.forEachCompleteJSONLine(in: file, startingAt: start) { line in
                guard Self.contains(line, marker: Self.claudeAssistantMarker),
                      Self.contains(line, marker: Self.usageMarker) else { return }
                guard let root = Self.object(line), root["type"] as? String == "assistant",
                      let date = Self.date(root["timestamp"]), date >= cutoff,
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
                let key = RecordFingerprint(id)
                if parsed.total > (messages[key]?.usage.total ?? -1) {
                    messages[key] = ClaudeRecord(usage: parsed, date: date)
                }
            }
            statistics.parsedJSONFiles += 1
            statistics.parsedJSONBytes += progress.bytesRead
            relieveJSONParsingPressure(afterReading: progress.bytesRead)
            claudeCache[path] = ClaudeFileCache(
                version: version,
                offset: progress.offset,
                continuity: Self.continuity(in: file, at: progress.offset),
                messages: messages.filter { $0.value.date >= cutoff }
            )
        } catch {
            claudeCache.removeValue(forKey: path)
        }
        return true
    }

    // MARK: - Codex

    private func scanCodex(cutoff: Date) async -> (Usage, [Date: Usage], [RateWindow], Int?, String?) {
        let roots = [
            home.appending(path: ".codex/sessions"),
            home.appending(path: ".codex/archived_sessions"),
        ].filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !roots.isEmpty else {
            codexCache.removeAll(keepingCapacity: false)
            mergedCodexRecords.removeAll(keepingCapacity: false)
            codexSeenRecords.removeAll(keepingCapacity: false)
            codexAggregateCache = nil
            return (.zero, [:], [], nil, "未找到 ~/.codex/sessions")
        }
        var files = roots.flatMap { recentJSONFiles(in: $0, cutoff: cutoff) }
        let livePaths = Set(files.map(\.0.path))
        let cachedPaths = Set(codexCache.keys)
        let removedFile = !cachedPaths.isSubset(of: livePaths)
        let crossedDayBoundary = codexAggregateCache?.cutoff != cutoff
        if removedFile || crossedDayBoundary {
            codexCache.removeAll(keepingCapacity: false)
            mergedCodexRecords.removeAll(keepingCapacity: false)
            codexSeenRecords.removeAll(keepingCapacity: false)
            codexAggregateCache = nil
        }
        var changed = livePaths != Set(codexCache.keys)
        if codexCache.isEmpty, !files.isEmpty {
            await accelerateColdCodexFiles(files, cutoff: cutoff)
            // Cold filtering can overlap an append to the currently active
            // rollout. Use fresh versions below so a successful retry becomes
            // an ordinary suffix update instead of a false replacement.
            files = roots.flatMap { recentJSONFiles(in: $0, cutoff: cutoff) }
        }
        var incrementalRecords: [RecordFingerprint: CodexRecord] = [:]
        var requiresFullRebuild = false
        for (file, version) in files {
            let update = updateCodexFile(file, version: version, cutoff: cutoff)
            changed = update.changed || changed
            if update.changed && !update.canMergeIncrementally {
                requiresFullRebuild = true
            }
            for (key, record) in update.records {
                if record.date < (incrementalRecords[key]?.date ?? .distantFuture) {
                    incrementalRecords[key] = record
                }
            }
        }
        if requiresFullRebuild {
            codexCache.removeAll(keepingCapacity: false)
            mergedCodexRecords.removeAll(keepingCapacity: false)
            codexSeenRecords.removeAll(keepingCapacity: false)
            codexAggregateCache = nil
            return await scanCodex(cutoff: cutoff)
        }

        if !changed, let aggregate = codexAggregateCache {
            return (aggregate.total, aggregate.daily, aggregate.limits, aggregate.windowTokens, nil)
        }

        var limits: [Int: RateWindow] = [:]
        for cached in codexCache.values {
            for (minutes, window) in cached.limits
            where window.observedAt >= (limits[minutes]?.observedAt ?? .distantPast) {
                limits[minutes] = window
            }
        }
        let sortedLimits = limits.values.sorted { $0.minutes < $1.minutes }
        let weeklyWindowStart = Snapshot.weeklyLimitWindow(in: sortedLimits).map {
            $0.resetsAt.addingTimeInterval(-Double($0.minutes) * 60)
        }
        if let aggregate = codexAggregateCache,
           aggregate.windowStart != weeklyWindowStart {
            codexCache.removeAll(keepingCapacity: false)
            mergedCodexRecords.removeAll(keepingCapacity: false)
            codexSeenRecords.removeAll(keepingCapacity: false)
            codexAggregateCache = nil
            return await scanCodex(cutoff: cutoff)
        }

        if let aggregate = codexAggregateCache {
            var total = aggregate.total
            var daily = aggregate.daily
            var windowTokens = aggregate.windowTokens
            for (key, record) in incrementalRecords
            where codexSeenRecords.insert(key).inserted {
                total.add(record.usage)
                daily[calendar.startOfDay(for: record.date), default: .zero].add(record.usage)
                if let weeklyWindowStart, record.date >= weeklyWindowStart {
                    windowTokens = (windowTokens ?? 0) + record.usage.total
                }
            }
            discardCodexRecordDetails()
            codexAggregateCache = (
                cutoff,
                total,
                daily,
                sortedLimits,
                weeklyWindowStart == nil ? nil : windowTokens ?? 0,
                weeklyWindowStart
            )
            return (total, daily, sortedLimits, codexAggregateCache?.windowTokens, nil)
        }

        var rebuilt: [RecordFingerprint: CodexRecord] = [:]
        for cached in codexCache.values {
            for compact in cached.records {
                let record = compact.record
                if record.date < (rebuilt[compact.key]?.date ?? .distantFuture) {
                    rebuilt[compact.key] = record
                }
            }
        }
        mergedCodexRecords = rebuilt
        var dayStarts: [Date] = []
        dayStarts.reserveCapacity(15)
        for offset in 0...14 {
            guard let start = calendar.date(byAdding: .day, value: offset, to: cutoff) else { break }
            dayStarts.append(start)
        }
        let dayTimestamps = dayStarts.map(\.timeIntervalSince1970)
        var total = Usage.zero
        var daily: [Date: Usage] = [:]
        var windowTokens: Int?
        var weeklyTokens = 0
        for record in mergedCodexRecords.values {
            total.add(record.usage)
            let timestamp = record.date.timeIntervalSince1970
            var low = 0
            var high = dayTimestamps.count
            while low < high {
                let midpoint = low + (high - low) / 2
                if dayTimestamps[midpoint] <= timestamp {
                    low = midpoint + 1
                } else {
                    high = midpoint
                }
            }
            let dayIndex = low - 1
            if dayIndex >= 0, dayIndex < min(14, dayStarts.count) {
                daily[dayStarts[dayIndex], default: .zero].add(record.usage)
            }
            if let weeklyWindowStart, record.date >= weeklyWindowStart {
                weeklyTokens += record.usage.total
            }
        }
        if weeklyWindowStart != nil { windowTokens = weeklyTokens }
        codexSeenRecords = Set(mergedCodexRecords.keys)
        mergedCodexRecords.removeAll(keepingCapacity: false)
        discardCodexRecordDetails()
        codexAggregateCache = (
            cutoff,
            total,
            daily,
            sortedLimits,
            windowTokens,
            weeklyWindowStart
        )
        return (total, daily, sortedLimits, windowTokens, nil)
    }

    private func discardCodexRecordDetails() {
        for path in Array(codexCache.keys) {
            guard var cached = codexCache.removeValue(forKey: path) else { continue }
            cached.records.removeAll(keepingCapacity: false)
            codexCache[path] = cached
        }
    }

    private func updateCodexFile(
        _ file: URL,
        version: FileVersion,
        cutoff: Date
    ) -> CodexFileUpdate {
        let path = file.path
        if codexCache[path]?.version == version { return CodexFileUpdate() }
        let hadCache = codexCache[path] != nil
        let cached = codexCache.removeValue(forKey: path)
        let canContinue = cached.map {
            version.size > $0.version.size && version.size >= $0.offset
                && Self.continuity(in: file, at: $0.offset) == $0.continuity
        } ?? false
        var limits = canContinue ? cached?.limits ?? [:] : [:]
        var parser = canContinue ? cached?.parser ?? CodexParserState() : CodexParserState()
        let start = canContinue ? cached?.offset ?? 0 : Self.initialScanOffset(
            in: file,
            size: version.size,
            cutoff: cutoff
        )
        if !canContinue, start > 0,
           let firstLine = Self.locatedLine(in: file, atOrAfter: 0, size: version.size),
           Self.contains(firstLine.data[...], marker: Self.sessionMetaMarker) {
            parser.sessionID = Self.jsonString("session_id", in: firstLine.data[...])
                ?? Self.jsonString("id", in: firstLine.data[...])
        }
        var parsedRecords: [RecordFingerprint: CodexRecord] = [:]
        do {
            let progress = try Self.forEachCompleteJSONLine(in: file, startingAt: start) { line in
                if Self.contains(line, marker: Self.sessionMetaMarker) {
                    if parser.sessionID == nil {
                        parser.sessionID = Self.jsonString("session_id", in: line)
                            ?? Self.jsonString("id", in: line)
                    }
                    return
                }
                if Self.contains(line, marker: Self.turnContextMarker) {
                    if let model = Self.jsonString("model", in: line) {
                        parser.pricing = Pricing.forModel(model)
                    }
                    return
                }
                guard Self.contains(line, marker: Self.tokenCountMarker),
                      let event = CodexTokenCountParser.parse(line) else { return }
                let observedAt = event.observedAt
                if let current = event.cumulative {
                    var delta: Usage
                    if let previous = parser.previous {
                        delta = Self.codexDelta(current: current, previous: previous)
                    } else if let last = event.last {
                        delta = last
                    } else {
                        delta = current
                    }
                    delta.costUSD = parser.pricing.cost(delta)
                    if delta.total > 0, let observedAt, observedAt >= cutoff {
                        let key = RecordFingerprint(
                            session: parser.sessionID ?? path,
                            cumulative: current
                        )
                        if observedAt < (parsedRecords[key]?.date ?? .distantFuture) {
                            let record = CodexRecord(usage: delta, date: observedAt)
                            parsedRecords[key] = record
                        }
                    }
                    parser.previous = current
                }
                if let rates = event.rateLimits,
                   let observedAt, observedAt >= cutoff {
                    Self.mergeRateLimits(rates, observedAt: observedAt, into: &limits)
                }
            }
            statistics.parsedJSONFiles += 1
            statistics.parsedJSONBytes += progress.bytesRead
            relieveJSONParsingPressure(afterReading: progress.bytesRead)
            var records: [CompactCodexRecord]
            if canContinue, let existing = cached {
                records = existing.records
                var indexByKey: [RecordFingerprint: Int] = [:]
                indexByKey.reserveCapacity(records.count)
                for (index, record) in records.enumerated() { indexByKey[record.key] = index }
                for (key, record) in parsedRecords {
                    if let index = indexByKey[key] {
                        if record.date < records[index].record.date {
                            records[index] = CompactCodexRecord(key: key, record: record)
                        }
                    } else {
                        indexByKey[key] = records.count
                        records.append(CompactCodexRecord(key: key, record: record))
                    }
                }
            } else {
                records = parsedRecords.map { CompactCodexRecord(key: $0.key, record: $0.value) }
            }
            codexCache[path] = CodexFileCache(
                version: version,
                offset: progress.offset,
                continuity: Self.continuity(in: file, at: progress.offset),
                records: records,
                limits: limits.filter { $0.value.observedAt >= cutoff },
                parser: parser
            )
        } catch {
            codexCache.removeValue(forKey: path)
            return CodexFileUpdate(changed: true, canMergeIncrementally: false)
        }
        return CodexFileUpdate(
            changed: true,
            canMergeIncrementally: canContinue || !hadCache,
            records: parsedRecords
        )
    }

    /// Uses macOS' optimized streaming text tools for cold files that start
    /// inside the visible window. Grep reads source bytes once, while awk
    /// removes ordinary session content and compresses large turn-context rows
    /// to a model marker before anything reaches this process. Any uncertainty
    /// falls back to the regular per-file reader below.
    private func accelerateColdCodexFiles(
        _ files: [(URL, FileVersion)],
        cutoff: Date
    ) async {
        let eligible = files.filter { file, version in
            Self.initialScanOffset(in: file, size: version.size, cutoff: cutoff) == 0
                && Self.endsInNewline(file, size: version.size)
        }
        guard !eligible.isEmpty else { return }

        var batches: [[(URL, FileVersion)]] = []
        var batch: [(URL, FileVersion)] = []
        var argumentBytes = 0
        var sourceBytes: UInt64 = 0
        let totalSourceBytes = eligible.reduce(UInt64(0)) { partial, item in
            partial &+ item.1.size
        }
        let targetSourceBytes = max(
            totalSourceBytes / UInt64(Self.coldCodexWorkerLimit),
            1
        )
        for item in eligible {
            let bytes = item.0.path.utf8.count + 1
            if !batch.isEmpty,
               argumentBytes + bytes > 96 * 1024 || sourceBytes >= targetSourceBytes {
                batches.append(batch)
                batch.removeAll(keepingCapacity: true)
                argumentBytes = 0
                sourceBytes = 0
            }
            batch.append(item)
            argumentBytes += bytes
            sourceBytes &+= item.1.size
        }
        if !batch.isEmpty { batches.append(batch) }

        await withTaskGroup(of: ColdCodexBatchResult.self) { group in
            var nextBatch = 0
            let workerCount = min(Self.coldCodexWorkerLimit, batches.count)
            for _ in 0..<workerCount {
                let pending = batches[nextBatch]
                nextBatch += 1
                group.addTask {
                    Self.runColdCodexFilter(pending, cutoff: cutoff)
                }
            }

            while let result = await group.next() {
                if result.succeeded {
                    for (path, cache) in result.caches { codexCache[path] = cache }
                    statistics.parsedJSONFiles += result.inputFileCount
                    statistics.parsedJSONBytes += result.parsedBytes
                    statistics.acceleratedCodexFiles += result.inputFileCount
                    relieveJSONParsingPressure(afterReading: result.parsedBytes)
                }
                if nextBatch < batches.count {
                    let pending = batches[nextBatch]
                    nextBatch += 1
                    group.addTask {
                        Self.runColdCodexFilter(pending, cutoff: cutoff)
                    }
                }
            }
        }

        let unresolved = eligible.compactMap { file, version -> (URL, FileVersion)? in
            guard codexCache[file.path]?.version != version,
                  let current = Self.fileVersion(at: file),
                  current != version,
                  Self.endsInNewline(file, size: current.size) else { return nil }
            return (file, current)
        }
        if !unresolved.isEmpty {
            let retry = await Task.detached {
                Self.runColdCodexFilter(unresolved, cutoff: cutoff)
            }.value
            if retry.succeeded {
                for (path, cache) in retry.caches { codexCache[path] = cache }
                statistics.parsedJSONFiles += retry.inputFileCount
                statistics.parsedJSONBytes += retry.parsedBytes
                statistics.acceleratedCodexFiles += retry.inputFileCount
                relieveJSONParsingPressure(afterReading: retry.parsedBytes)
            }
        }
    }

    private nonisolated static func runColdCodexFilter(
        _ files: [(URL, FileVersion)],
        cutoff: Date
    ) -> ColdCodexBatchResult {
        let grep = Process()
        grep.executableURL = URL(fileURLWithPath: "/usr/bin/grep")
        grep.arguments = [
            "-a", "-H", "-F",
            "-e", #""type":"turn_context""#,
            "-e", #""type":"token_count""#,
        ] + files.map(\.0.path)

        let awk = Process()
        awk.executableURL = URL(fileURLWithPath: "/usr/bin/awk")
        awk.arguments = [Self.codexColdFilterAWK]

        let grepOutput = Pipe()
        let filteredOutput = Pipe()
        grep.standardOutput = grepOutput
        grep.standardError = FileHandle.nullDevice
        awk.standardInput = grepOutput
        awk.standardOutput = filteredOutput
        awk.standardError = FileHandle.nullDevice

        do {
            try awk.run()
            try grep.run()
        } catch {
            if grep.isRunning { grep.terminate() }
            if awk.isRunning { awk.terminate() }
            return ColdCodexBatchResult(inputFileCount: files.count)
        }
        grepOutput.fileHandleForReading.closeFile()
        grepOutput.fileHandleForWriting.closeFile()
        filteredOutput.fileHandleForWriting.closeFile()

        let versions = Dictionary(uniqueKeysWithValues: files.map { ($0.0.path, $0.1) })
        var result = ColdCodexBatchResult(inputFileCount: files.count)
        var completedPaths: Set<String> = []
        var currentPath: String?
        var currentState: ColdCodexState?

        func makeState(for path: String) -> ColdCodexState {
            let state = ColdCodexState()
            guard let version = versions[path],
                  let line = Self.locatedLine(
                    in: URL(fileURLWithPath: path),
                    atOrAfter: 0,
                    size: version.size
                  ), Self.contains(line.data[...], marker: Self.sessionMetaMarker) else { return state }
            state.parser.sessionID = Self.jsonString("session_id", in: line.data[...])
                ?? Self.jsonString("id", in: line.data[...])
            return state
        }

        func finishCurrent() {
            guard let path = currentPath, let state = currentState,
                  let version = versions[path],
                  Self.fileVersion(at: URL(fileURLWithPath: path)) == version else { return }
            result.caches[path] = CodexFileCache(
                version: version,
                offset: version.size,
                continuity: Self.continuity(
                    in: URL(fileURLWithPath: path),
                    at: version.size
                ),
                records: state.records,
                limits: state.limits,
                parser: state.parser
            )
            completedPaths.insert(path)
        }

        var outputBuffer = Data()
        outputBuffer.reserveCapacity(512 * 1024)
        var discardingOversizedLine = false
        let readCapacity = 256 * 1024
        let readBuffer = UnsafeMutableRawPointer.allocate(
            byteCount: readCapacity,
            alignment: MemoryLayout<UInt8>.alignment
        )
        defer { readBuffer.deallocate() }
        do {
            let handle = filteredOutput.fileHandleForReading
            while true {
                let count = Darwin.read(handle.fileDescriptor, readBuffer, readCapacity)
                if count == 0 { break }
                guard count > 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
                result.parsedBytes += UInt64(count)
                let chunk = UnsafeBufferPointer(
                    start: readBuffer.assumingMemoryBound(to: UInt8.self),
                    count: count
                )
                var chunkStart = chunk.startIndex
                if discardingOversizedLine {
                    guard let newline = chunk[chunkStart...].firstIndex(of: 0x0A) else { continue }
                    chunkStart = chunk.index(after: newline)
                    discardingOversizedLine = false
                }
                if chunkStart < chunk.endIndex {
                    outputBuffer.append(contentsOf: chunk[chunkStart...])
                }
                var lineStart = outputBuffer.startIndex
                while let newline = outputBuffer[lineStart...].firstIndex(of: 0x0A) {
                    let line = outputBuffer[lineStart..<newline]
                    if line.count <= 8 * 1024 * 1024 {
                        if line.starts(with: [0x46, 0x09]) {
                            finishCurrent()
                            let path = String(decoding: line.dropFirst(2), as: UTF8.self)
                            currentPath = versions[path] == nil ? nil : path
                            currentState = currentPath.map(makeState)
                        } else if let state = currentState {
                            if line.starts(with: [0x4D, 0x09]) {
                                state.parser.pricing = Pricing.forModel(
                                    String(decoding: line.dropFirst(2), as: UTF8.self)
                                )
                            } else if let path = currentPath,
                                      let event = CodexTokenCountParser.parse(line) {
                                applyColdCodexEvent(
                                    event,
                                    path: path,
                                    cutoff: cutoff,
                                    state: state
                                )
                            }
                        }
                    }
                    lineStart = outputBuffer.index(after: newline)
                }
                if lineStart > outputBuffer.startIndex {
                    outputBuffer.removeSubrange(outputBuffer.startIndex..<lineStart)
                }
                if outputBuffer.count > 8 * 1024 * 1024 {
                    outputBuffer.removeAll(keepingCapacity: true)
                    discardingOversizedLine = true
                }
            }
            finishCurrent()
        } catch {
            if grep.isRunning { grep.terminate() }
            if awk.isRunning { awk.terminate() }
        }

        grep.waitUntilExit()
        awk.waitUntilExit()
        let succeeded = (grep.terminationStatus == 0 || grep.terminationStatus == 1)
            && awk.terminationStatus == 0
        guard succeeded else {
            result.caches.removeAll(keepingCapacity: false)
            return result
        }

        for (file, version) in files where !completedPaths.contains(file.path) {
            guard Self.fileVersion(at: file) == version else { continue }
            result.caches[file.path] = CodexFileCache(
                version: version,
                offset: version.size,
                continuity: Self.continuity(in: file, at: version.size),
                records: [],
                limits: [:],
                parser: makeState(for: file.path).parser
            )
        }
        result.succeeded = true
        return result
    }

    private nonisolated static func applyColdCodexEvent(
        _ event: CodexTokenCountEvent,
        path: String,
        cutoff: Date,
        state: ColdCodexState
    ) {
        let observedAt = event.observedAt
        if let current = event.cumulative {
            var delta: Usage
            if let previous = state.parser.previous {
                delta = Self.codexDelta(current: current, previous: previous)
            } else if let last = event.last {
                delta = last
            } else {
                delta = current
            }
            delta.costUSD = state.parser.pricing.cost(delta)
            if delta.total > 0, let observedAt, observedAt >= cutoff {
                let key = RecordFingerprint(
                    session: state.parser.sessionID ?? path,
                    cumulative: current
                )
                state.records.append(
                    CompactCodexRecord(
                        key: key,
                        record: CodexRecord(usage: delta, date: observedAt)
                    )
                )
            }
            state.parser.previous = current
        }
        if let rates = event.rateLimits, let observedAt, observedAt >= cutoff {
            Self.mergeRateLimits(rates, observedAt: observedAt, into: &state.limits)
        }
    }

    // MARK: - Incremental JSONL reading

    private struct ReadProgress {
        let offset: UInt64
        let bytesRead: UInt64
    }

    private struct LocatedLine {
        let start: UInt64
        let end: UInt64
        let data: Data
    }

    private nonisolated static func forEachCompleteJSONLine(
        in url: URL,
        startingAt offset: UInt64,
        chunkSize: Int = 64 * 1024,
        maximumLineLength: Int = 8 * 1024 * 1024,
        _ body: (Data.SubSequence) -> Void
    ) throws -> ReadProgress {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.seek(toOffset: offset)
        var buffer = Data()
        buffer.reserveCapacity(min(chunkSize * 2, maximumLineLength))
        var committedOffset = offset
        var bytesRead: UInt64 = 0
        var discardingOversizedLine = false
        while try autoreleasepool(invoking: { () throws -> Bool in
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { return false }
            let chunkAbsoluteStart = offset + bytesRead
            bytesRead += UInt64(chunk.count)
            var chunkStart = chunk.startIndex
            if discardingOversizedLine {
                guard let newline = chunk[chunkStart...].firstIndex(of: 0x0A) else { return true }
                committedOffset = chunkAbsoluteStart + UInt64(chunk.distance(from: chunk.startIndex, to: newline)) + 1
                chunkStart = chunk.index(after: newline)
                discardingOversizedLine = false
            }
            if chunkStart < chunk.endIndex { buffer.append(contentsOf: chunk[chunkStart...]) }
            var lineStart = buffer.startIndex
            while let newline = buffer[lineStart...].firstIndex(of: 0x0A) {
                let lineData = buffer[lineStart..<newline]
                if lineData.count <= maximumLineLength {
                    body(lineData)
                }
                committedOffset += UInt64(lineData.count + 1)
                lineStart = buffer.index(after: newline)
            }
            if lineStart > buffer.startIndex { buffer.removeSubrange(buffer.startIndex..<lineStart) }
            if buffer.count > maximumLineLength {
                buffer.removeAll(keepingCapacity: true)
                discardingOversizedLine = true
            }
            return true
        }) {}
        return ReadProgress(offset: committedOffset, bytesRead: bytesRead)
    }

    /// Finds the first chronological JSONL record inside the rolling window
    /// without walking an old, still-active file from byte zero. Probes are
    /// aligned to complete lines and compare the root ISO timestamp directly.
    private nonisolated static func initialScanOffset(
        in url: URL,
        size: UInt64,
        cutoff: Date
    ) -> UInt64 {
        guard size > 0,
              let first = locatedLine(in: url, atOrAfter: 0, size: size),
              let firstDate = timestamp(in: first.data),
              firstDate < cutoff else { return 0 }

        var low = first.end
        var high = size
        var best = size
        for _ in 0..<48 where low < high {
            let midpoint = low + (high - low) / 2
            guard let line = locatedLine(in: url, atOrAfter: midpoint, size: size) else {
                high = midpoint
                continue
            }
            guard let date = timestamp(in: line.data) else {
                let next = max(low + 1, line.end)
                low = min(next, size)
                continue
            }
            if date >= cutoff {
                best = min(best, line.start)
                if line.start <= low { break }
                high = line.start
            } else {
                let next = max(low + 1, line.end)
                low = min(next, size)
            }
        }
        return best
    }

    private nonisolated static func locatedLine(
        in url: URL,
        atOrAfter requestedOffset: UInt64,
        size: UInt64,
        chunkSize: Int = 64 * 1024,
        maximumLineLength: Int = 8 * 1024 * 1024
    ) -> LocatedLine? {
        guard requestedOffset < size,
              let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        do {
            var lineStart = requestedOffset
            if requestedOffset > 0 {
                try handle.seek(toOffset: requestedOffset - 1)
                let previous = try handle.read(upToCount: 1)?.first
                if previous != 0x0A {
                    try handle.seek(toOffset: requestedOffset)
                    var absolute = requestedOffset
                    var foundStart = false
                    while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                        if let newline = chunk.firstIndex(of: 0x0A) {
                            lineStart = absolute + UInt64(chunk.distance(from: chunk.startIndex, to: newline)) + 1
                            foundStart = true
                            break
                        }
                        absolute += UInt64(chunk.count)
                    }
                    guard foundStart, lineStart < size else { return nil }
                }
            }

            try handle.seek(toOffset: lineStart)
            var data = Data()
            data.reserveCapacity(min(chunkSize, maximumLineLength))
            var absolute = lineStart
            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                if let newline = chunk.firstIndex(of: 0x0A) {
                    let prefix = chunk[..<newline]
                    if data.count + prefix.count <= maximumLineLength { data.append(contentsOf: prefix) }
                    let end = absolute + UInt64(chunk.distance(from: chunk.startIndex, to: newline)) + 1
                    return LocatedLine(start: lineStart, end: end, data: data)
                }
                if data.count + chunk.count <= maximumLineLength { data.append(chunk) }
                absolute += UInt64(chunk.count)
            }
            return data.isEmpty ? nil : LocatedLine(start: lineStart, end: size, data: data)
        } catch {
            return nil
        }
    }

    private nonisolated static func timestamp(in data: Data) -> Date? {
        let marker = Data(#""timestamp":""#.utf8)
        guard let markerRange = data.range(of: marker) else { return nil }
        let valueStart = markerRange.upperBound
        guard let quote = data[valueStart...].firstIndex(of: 0x22) else { return nil }
        return date(String(decoding: data[valueStart..<quote], as: UTF8.self))
    }

    /// Calls `body` once per UTF-8 line without retaining the complete file.
    /// The final unterminated line is included for this general-purpose helper;
    /// incremental scans only commit newline-terminated records.
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
        while try autoreleasepool(invoking: { () throws -> Bool in
            guard let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty else { return false }
            var chunkStart = chunk.startIndex
            if discardingOversizedLine {
                guard let newline = chunk[chunkStart...].firstIndex(of: 0x0A) else { return true }
                chunkStart = chunk.index(after: newline)
                discardingOversizedLine = false
            }
            if chunkStart < chunk.endIndex { buffer.append(contentsOf: chunk[chunkStart...]) }
            var lineStart = buffer.startIndex
            while let newline = buffer[lineStart...].firstIndex(of: 0x0A) {
                let lineData = buffer[lineStart..<newline]
                if lineData.count <= maximumLineLength {
                    body(String(decoding: lineData, as: UTF8.self)[...])
                }
                lineStart = buffer.index(after: newline)
            }
            if lineStart > buffer.startIndex { buffer.removeSubrange(buffer.startIndex..<lineStart) }
            if buffer.count > maximumLineLength {
                buffer.removeAll(keepingCapacity: true)
                discardingOversizedLine = true
            }
            return true
        }) {}
        if !discardingOversizedLine, !buffer.isEmpty, buffer.count <= maximumLineLength {
            autoreleasepool { body(String(decoding: buffer, as: UTF8.self)[...]) }
        }
    }

    private nonisolated static func continuity(in url: URL, at offset: UInt64) -> Data {
        let length = min(UInt64(64), offset)
        guard let handle = try? FileHandle(forReadingFrom: url) else { return Data() }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: offset - length)
            let data = try handle.read(upToCount: Int(length)) ?? Data()
            return Data(SHA256.hash(data: data))
        } catch {
            return Data()
        }
    }

    private nonisolated static func endsInNewline(_ url: URL, size: UInt64) -> Bool {
        guard size > 0, let handle = try? FileHandle(forReadingFrom: url) else { return size == 0 }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: size - 1)
            return try handle.read(upToCount: 1)?.first == 0x0A
        } catch {
            return false
        }
    }

    private func relieveJSONParsingPressure(afterReading bytes: UInt64) {
        jsonBytesSincePressureRelief += bytes
        guard jsonBytesSincePressureRelief >= 128 * 1024 * 1024 else { return }
        malloc_zone_pressure_relief(nil, 0)
        jsonBytesSincePressureRelief = 0
    }

    // MARK: - OpenCode

    private func scanOpenCode(cutoff: Date) -> (Usage, [Date: Usage], String?) {
        let url = home.appending(path: ".local/share/opencode/opencode.db")
        guard let databaseVersion = Self.fileVersion(at: url) else {
            openCodeCache = nil
            return (.zero, [:], "未找到 OpenCode 数据库")
        }
        let walURL = URL(fileURLWithPath: url.path + "-wal")
        let sharedMemoryURL = URL(fileURLWithPath: url.path + "-shm")
        let walVersion = Self.fileVersion(at: walURL)
        let sharedMemoryVersion = Self.fileVersion(at: sharedMemoryURL)
        let changed = openCodeCache == nil
            || openCodeCache?.database != databaseVersion
            || openCodeCache?.wal != walVersion
            || openCodeCache?.sharedMemory != sharedMemoryVersion
        if changed {
            var records = openCodeCache?.records ?? [:]
            let error = updateOpenCodeDatabase(at: url.path, cutoff: cutoff, records: &records)
            openCodeCache = OpenCodeCache(
                database: Self.fileVersion(at: url) ?? databaseVersion,
                wal: Self.fileVersion(at: walURL),
                sharedMemory: Self.fileVersion(at: sharedMemoryURL),
                records: records,
                error: error
            )
        }
        guard var cache = openCodeCache else { return (.zero, [:], nil) }
        cache.records = cache.records.filter {
            Date(timeIntervalSince1970: Double($0.value.updatedMilliseconds) / 1_000) >= cutoff
        }
        openCodeCache = cache
        let aggregate = Self.aggregate(
            cache.records.values.compactMap { record in
                guard let date = record.date, date >= cutoff, record.usage.total > 0 else { return nil }
                return (record.usage, date)
            },
            calendar: calendar
        )
        return (aggregate.0, aggregate.1, cache.error)
    }

    private func updateOpenCodeDatabase(
        at path: String,
        cutoff: Date,
        records: inout [String: OpenCodeRecord]
    ) -> String? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return "无法只读打开 OpenCode 数据库"
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, "BEGIN", nil, nil, nil)
        defer { sqlite3_exec(db, "COMMIT", nil, nil, nil) }
        let cutoffMilliseconds = Int64(cutoff.timeIntervalSince1970 * 1_000)
        var versions: [String: Int64] = [:]
        var statement: OpaquePointer?
        let candidateSQL = """
            SELECT id FROM message INDEXED BY message_session_time_created_id_idx
            WHERE time_created >= ?1
            """
        if sqlite3_prepare_v2(db, candidateSQL, -1, &statement, nil) == SQLITE_OK {
            // A turn can straddle midnight or the rolling-window boundary.
            // The one-day lookback stays bounded while keeping those rows as
            // candidates; the decoded completion timestamp applies the exact
            // cutoff below.
            sqlite3_bind_int64(statement, 1, cutoffMilliseconds - 86_400_000)
            var candidateIDs: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0) else { continue }
                candidateIDs.append(String(cString: id))
            }
            sqlite3_finalize(statement)
            statement = nil

            let versionSQL = "SELECT time_updated FROM message WHERE id = ?1"
            guard sqlite3_prepare_v2(db, versionSQL, -1, &statement, nil) == SQLITE_OK else {
                return "OpenCode 数据库结构不兼容"
            }
            let transient = unsafeBitCast(-1 as Int, to: sqlite3_destructor_type.self)
            for id in candidateIDs {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_text(statement, 1, id, -1, transient)
                if sqlite3_step(statement) == SQLITE_ROW {
                    versions[id] = sqlite3_column_int64(statement, 0)
                }
            }
        } else {
            sqlite3_finalize(statement)
            statement = nil
            let versionSQL = "SELECT id, time_updated FROM message WHERE time_updated >= ?1"
            guard sqlite3_prepare_v2(db, versionSQL, -1, &statement, nil) == SQLITE_OK else {
                return "OpenCode 数据库结构不兼容"
            }
            sqlite3_bind_int64(statement, 1, cutoffMilliseconds)
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = sqlite3_column_text(statement, 0) else { continue }
                versions[String(cString: id)] = sqlite3_column_int64(statement, 1)
            }
        }
        sqlite3_finalize(statement)
        statement = nil
        records = records.filter { versions[$0.key] != nil }

        let changed = versions.filter { records[$0.key]?.updatedMilliseconds != $0.value }
        let dataSQL = "SELECT data FROM message WHERE id = ?1"
        guard sqlite3_prepare_v2(db, dataSQL, -1, &statement, nil) == SQLITE_OK else {
            return "OpenCode 数据库结构不兼容"
        }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1 as Int, to: sqlite3_destructor_type.self)
        for (id, updated) in changed {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_text(statement, 1, id, -1, transient)
            guard sqlite3_step(statement) == SQLITE_ROW,
                  let cString = sqlite3_column_text(statement, 0) else { continue }
            autoreleasepool {
                let data = String(cString: cString).data(using: .utf8)
                let value = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
                records[id] = Self.openCodeRecord(value, updatedMilliseconds: updated)
            }
            statistics.parsedOpenCodeRows += 1
        }
        return nil
    }

    private nonisolated static func openCodeRecord(
        _ value: [String: Any]?,
        updatedMilliseconds: Int64
    ) -> OpenCodeRecord {
        guard let value,
              value["role"] as? String == "assistant",
              let tokens = value["tokens"] as? [String: Any],
              let completed = (value["time"] as? [String: Any])?["completed"],
              let date = Self.date(completed) else {
            return OpenCodeRecord(usage: .zero, date: nil, updatedMilliseconds: updatedMilliseconds)
        }
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
        return OpenCodeRecord(usage: usage, date: date, updatedMilliseconds: updatedMilliseconds)
    }

    private nonisolated static func fileVersion(at url: URL) -> FileVersion? {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]),
              let size = values.fileSize,
              let modificationDate = values.contentModificationDate else { return nil }
        return FileVersion(size: UInt64(size), modificationDate: modificationDate)
    }

    // MARK: - Parsing and aggregation helpers

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
        if let limitID = rates["limit_id"] as? String, limitID != "codex" { return }
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

    private nonisolated static func mergeRateLimits(
        _ rates: CodexTokenCountEvent.RateLimits,
        observedAt: Date,
        into limits: inout [Int: RateWindow]
    ) {
        guard rates.isAccountLimit != false else { return }
        func merge(_ window: CodexTokenCountEvent.RateWindow?) {
            guard let window,
                  observedAt >= (limits[window.minutes]?.observedAt ?? .distantPast) else { return }
            let name = window.minutes <= 300
                ? "5 小时额度"
                : window.minutes <= 10_080 ? "周额度" : "月额度"
            limits[window.minutes] = RateWindow(
                name: name,
                used: window.usedPercent,
                minutes: window.minutes,
                resetsAt: Date(timeIntervalSince1970: window.resetsAt),
                observedAt: observedAt
            )
        }
        merge(rates.primary)
        merge(rates.secondary)
        merge(rates.individual)
    }

    private static func aggregate(
        _ records: [(Usage, Date)],
        calendar: Calendar
    ) -> (Usage, [Date: Usage], String?) {
        var total = Usage.zero
        var daily: [Date: Usage] = [:]
        for (usage, date) in records {
            total.add(usage)
            daily[calendar.startOfDay(for: date), default: .zero].add(usage)
        }
        return (total, daily, nil)
    }

    nonisolated static func last14Days(
        claude: [Date: Usage],
        codex: [Date: Usage],
        openCode: [Date: Usage],
        enabledTools: Set<Tool> = Set(Tool.allCases),
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [DailyUsage] {
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

    private nonisolated static func object(_ line: Data.SubSequence) -> [String: Any]? {
        try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
    }

    private nonisolated static func contains(_ line: Data.SubSequence, marker: Data) -> Bool {
        line.range(of: marker) != nil
    }

    /// Extracts simple unescaped JSON string fields used by Codex metadata.
    /// Session IDs and model identifiers are ASCII-safe, so decoding the whole
    /// potentially multi-megabyte metadata/context object is unnecessary.
    private nonisolated static func jsonString(_ key: String, in line: Data.SubSequence) -> String? {
        let marker = Data("\"\(key)\":\"".utf8)
        guard let range = line.range(of: marker) else { return nil }
        let start = range.upperBound
        guard let quote = line[start...].firstIndex(of: 0x22) else { return nil }
        return String(decoding: line[start..<quote], as: UTF8.self)
    }

    nonisolated static func int(_ value: Any?) -> Int { (value as? NSNumber)?.intValue ?? 0 }
}
