import Darwin
import Foundation
import Observation

@MainActor @Observable
final class UsageModel {
    var snapshot = Snapshot()
    /// False until the first scan completes, while the panel shows a
    /// loading indicator instead of an empty trend.
    private(set) var hasLoadedSnapshot = false
    var tasks: [TaskExecution] = []
    private(set) var isTaskStatusAnimationPaused = false
    private let scanner = UsageScanner()
    private let usageScan: (@Sendable () async -> Snapshot)?
    static let hidesTaskActivityKey = "hidesTaskActivity"
    private(set) var isTaskActivityHidden: Bool
    private let defaults: UserDefaults
    private let makeTaskSession: @MainActor () -> TaskMonitoringSession
    private var taskSession: TaskMonitoringSession?
    private var taskGeneration = 0
    var hasTaskMonitoringSession: Bool { taskSession != nil }

    init(defaults: UserDefaults = .standard,
         usageScan: (@Sendable () async -> Snapshot)? = nil,
         makeTaskSession: @escaping @MainActor () -> TaskMonitoringSession = { TaskMonitoringSession() }) {
        self.defaults = defaults
        self.usageScan = usageScan
        self.makeTaskSession = makeTaskSession
        isTaskActivityHidden = defaults.bool(forKey: Self.hidesTaskActivityKey)
        isTaskStatusAnimationPaused = isTaskActivityHidden
    }

    func setTaskActivityHidden(_ hidden: Bool) {
        guard hidden != isTaskActivityHidden else { return }
        isTaskActivityHidden = hidden
        defaults.set(hidden, forKey: Self.hidesTaskActivityKey)
        isTaskStatusAnimationPaused = hidden || !refreshGate.allowsRefresh
        if hidden {
            taskSession = nil
            tasks = []
            stopTaskLoop(reclaimMemory: true)
        } else {
            startLoopsIfAllowed()
        }
    }
    private var started = false
    private var refreshGate = RefreshActivityGate()
    private var usageLoopTask: Task<Void, Never>?
    private var taskLoopTask: Task<Void, Never>?

    func start() {
        guard !started else { return }
        started = true
        startLoopsIfAllowed()
    }

    func stop() {
        started = false
        stopLoops()
        taskSession = nil
    }

    func setRefreshSuspended(
        _ suspended: Bool,
        for reason: RefreshSuspensionReason
    ) {
        let transition = refreshGate.setSuspended(suspended, for: reason)
        isTaskStatusAnimationPaused = isTaskActivityHidden || !refreshGate.allowsRefresh
        switch transition {
        case .becameSuspended:
            stopLoops()
        case .becameActive:
            startLoopsIfAllowed()
        case .unchanged:
            break
        }
    }

    private func startLoopsIfAllowed() {
        guard started, refreshGate.allowsRefresh else { return }
        if usageLoopTask == nil {
            usageLoopTask = Task { [weak self] in
                await self?.runUsageLoop()
            }
        }
        if !isTaskActivityHidden, taskLoopTask == nil {
            let session = taskSession ?? makeTaskSession()
            taskSession = session
            let generation = taskGeneration
            taskLoopTask = Task { [weak self] in
                await self?.runTaskLoop(session: session, generation: generation)
            }
        }
    }

    private func stopLoops() {
        usageLoopTask?.cancel()
        usageLoopTask = nil
        stopTaskLoop()
    }

    private func stopTaskLoop(reclaimMemory: Bool = false) {
        taskGeneration += 1
        let retiredLoop = taskLoopTask
        retiredLoop?.cancel()
        taskLoopTask = nil
        if reclaimMemory {
            // Wait for cancelled readers to release their buffers before asking
            // malloc to return free pages. This runs only on explicit hide.
            Task.detached(priority: .utility) {
                await retiredLoop?.value
                malloc_zone_pressure_relief(nil, 0)
            }
        }
    }

    private func runUsageLoop() async {
        await refresh()
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {
                return
            }
            await refresh()
        }
    }

    private func runTaskLoop(session: TaskMonitoringSession, generation: Int) async {
        while !Task.isCancelled {
            guard refreshGate.allowsRefresh, !isTaskActivityHidden, generation == taskGeneration else { return }
            let newTasks = await session.scan().map { stored in
                var task = stored
                // Activity timestamps affect pause projection, not running-row
                // rendering. Do not invalidate SwiftUI for invisible metadata.
                task.lastActivityAt = nil
                return task
            }
            guard !Task.isCancelled, refreshGate.allowsRefresh,
                  !isTaskActivityHidden, generation == taskGeneration else { return }
            if newTasks != tasks { tasks = newTasks }
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                return
            }
        }
    }

    func refresh() async {
        guard refreshGate.allowsRefresh else { return }
        let newSnapshot: Snapshot
        if let usageScan { newSnapshot = await usageScan() }
        else { newSnapshot = await scanner.scan() }
        guard !Task.isCancelled, refreshGate.allowsRefresh else { return }
        if !snapshot.hasSameContent(as: newSnapshot) { snapshot = newSnapshot }
        hasLoadedSnapshot = true
    }

    nonisolated static func compact(_ number: Int) -> String {
        if number >= 1_000_000_000_000 { return String(format: "%.1fT", Double(number) / 1_000_000_000_000) }
        if number >= 1_000_000_000 { return String(format: "%.1fB", Double(number) / 1_000_000_000) }
        if number >= 1_000_000 { return String(format: "%.1fM", Double(number) / 1_000_000) }
        if number >= 1_000 { return String(format: "%.1fK", Double(number) / 1_000) }
        return "\(number)"
    }
}
