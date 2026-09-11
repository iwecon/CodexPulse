import Foundation
import Testing
@testable import CodexPulse

@MainActor
struct TaskMonitoringLifecycleTests {
    actor PendingScan {
        private var continuation: CheckedContinuation<[TaskExecution], Never>?
        private(set) var started = false
        func scan() async -> [TaskExecution] {
            started = true
            return await withCheckedContinuation { continuation = $0 }
        }
        func finish(_ tasks: [TaskExecution]) {
            continuation?.resume(returning: tasks)
            continuation = nil
        }
    }

    func eventually(_ condition: () async -> Bool) async -> Bool {
        for _ in 0..<200 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }

    @Test func hiddenStartupPersistsAndWakeDoesNotStartMonitoring() async throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(true, forKey: UsageModel.hidesTaskActivityKey)
        var creations = 0
        let model = UsageModel(defaults: defaults, usageScan: { Snapshot() }, makeTaskSession: {
            creations += 1
            return TaskMonitoringSession(scan: { [] })
        })
        model.start()
        defer { model.stop() }
        #expect(model.isTaskActivityHidden)
        #expect(model.isTaskStatusAnimationPaused)
        #expect(creations == 0)
        model.setRefreshSuspended(true, for: .screensAsleep)
        model.setRefreshSuspended(false, for: .screensAsleep)
        #expect(creations == 0)
        #expect(await eventually { model.hasLoadedSnapshot })
        model.setRefreshSuspended(true, for: .sessionInactive)
        model.setTaskActivityHidden(false)
        #expect(creations == 0)
        model.setRefreshSuspended(false, for: .sessionInactive)
        #expect(creations == 1)
        model.setTaskActivityHidden(true)
        #expect(!model.hasTaskMonitoringSession)
        #expect(UsageModel(defaults: defaults).isTaskActivityHidden)
    }

    @Test func cancelledScanCannotRepopulateAndSessionIsReleased() async throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let scan = PendingScan()
        weak var firstSession: TaskMonitoringSession?
        var creations = 0
        let model = UsageModel(defaults: defaults, usageScan: { Snapshot() }, makeTaskSession: {
            creations += 1
            if creations == 1 {
                let session = TaskMonitoringSession(scan: { await scan.scan() })
                firstSession = session
                return session
            }
            return TaskMonitoringSession(scan: { [] })
        })
        model.start()
        defer { model.stop() }
        #expect(await eventually { await scan.started })
        let stale = TaskExecution(id: "old", threadID: "thread", title: "Old", startedAt: Date())
        model.tasks = [stale]
        model.setTaskActivityHidden(true)
        #expect(model.tasks.isEmpty)
        #expect(!model.hasTaskMonitoringSession)
        model.setTaskActivityHidden(false)
        #expect(creations == 2)
        await scan.finish([stale])
        #expect(await eventually { firstSession == nil })
        #expect(model.tasks.isEmpty)
        for _ in 0..<5 {
            model.setTaskActivityHidden(true)
            model.setTaskActivityHidden(false)
        }
        #expect(creations == 7)
        model.setTaskActivityHidden(true)
        model.setRefreshSuspended(true, for: .screensAsleep)
        model.setRefreshSuspended(false, for: .screensAsleep)
        #expect(creations == 7)
        #expect(!model.hasTaskMonitoringSession)
    }
}
