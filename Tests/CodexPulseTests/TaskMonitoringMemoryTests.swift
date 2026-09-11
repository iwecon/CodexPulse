import Darwin
import Foundation
import Testing
@testable import CodexPulse

/// Opt-in read-only local-data probe; ordinary tests never inspect the user's sessions.
@MainActor
struct TaskMonitoringMemoryTests {
    private func footprint() throws -> String {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        #expect(result == KERN_SUCCESS)
        return String(format: "Physical footprint: %.2f MiB", Double(info.phys_footprint) / 1_048_576)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["CODEXPULSE_LOCAL_TASK_MEMORY"] == "1"))
    func localTaskCachesReleaseAcrossVisibilityCycles() async throws {
        let name = UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var scans = 0
        weak var currentSession: TaskMonitoringSession?
        weak var realSession: TaskMonitoringSession?
        let model = UsageModel(defaults: defaults, usageScan: { Snapshot() }, makeTaskSession: {
            let real = TaskMonitoringSession()
            realSession = real
            let wrapper = TaskMonitoringSession {
                let result = await real.scan()
                await MainActor.run { scans += 1 }
                return result
            }
            currentSession = wrapper
            return wrapper
        })
        let baseline = try footprint()
        print("TASK_MEMORY baseline \(baseline)")
        model.start()
        defer { model.stop() }
        for cycle in 1...3 {
            let before = scans
            if cycle > 1 { model.setTaskActivityHidden(false) }
            let deadline = Date().addingTimeInterval(60)
            while scans == before && Date() < deadline {
                try await Task.sleep(for: .milliseconds(50))
            }
            #expect(scans > before)
            print("TASK_MEMORY cycle=\(cycle) visible rows=\(model.tasks.count) \(try footprint())")
            model.setTaskActivityHidden(true)
            let releaseDeadline = Date().addingTimeInterval(5)
            while currentSession != nil && Date() < releaseDeadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            #expect(currentSession == nil)
            #expect(realSession == nil)
            #expect(model.tasks.isEmpty)
            #expect(!model.hasTaskMonitoringSession)
            let count = scans
            try await Task.sleep(for: .milliseconds(2200))
            #expect(scans == count)
            print("TASK_MEMORY cycle=\(cycle) hidden released=\(currentSession == nil) \(try footprint())")
        }
    }
}
