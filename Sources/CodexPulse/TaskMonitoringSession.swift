import Foundation

/// Owns task-only caches for one visible-panel lifetime. Releasing this session
/// releases all three monitors once any cancelled scan has unwound.
final class TaskMonitoringSession: Sendable {
    let scan: @Sendable () async -> [TaskExecution]

    init(scan: @escaping @Sendable () async -> [TaskExecution]) {
        self.scan = scan
    }

    convenience init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let codex = TaskMonitor(home: home)
        let claude = ClaudeTaskMonitor(home: home)
        let openCode = OpenCodeTaskMonitor(home: home)
        self.init {
            guard !Task.isCancelled else { return [] }
            async let codexTasks = codex.scan()
            async let claudeTasks = claude.scan()
            async let openCodeTasks = openCode.scan()
            let tasks = await codexTasks + claudeTasks + openCodeTasks
            guard !Task.isCancelled else { return [] }
            return TaskMonitor.sortedForDisplay(tasks)
        }
    }
}
