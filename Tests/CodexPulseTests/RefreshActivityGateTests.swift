import Testing
@testable import CodexPulse

@Test func refreshActivityGateWaitsForAllSuspensionReasonsToClear() {
    var gate = RefreshActivityGate()

    #expect(gate.allowsRefresh)
    #expect(gate.setSuspended(true, for: .sessionInactive) == .becameSuspended)
    #expect(!gate.allowsRefresh)
    #expect(gate.setSuspended(true, for: .screensAsleep) == .unchanged)
    #expect(!gate.allowsRefresh)

    #expect(gate.setSuspended(false, for: .sessionInactive) == .unchanged)
    #expect(!gate.allowsRefresh)
    #expect(gate.setSuspended(false, for: .screensAsleep) == .becameActive)
    #expect(gate.allowsRefresh)
}

@Test func refreshActivityGateHandlesWakeBeforeUnlock() {
    var gate = RefreshActivityGate()

    gate.setSuspended(true, for: .sessionInactive)
    gate.setSuspended(true, for: .screensAsleep)

    #expect(gate.setSuspended(false, for: .screensAsleep) == .unchanged)
    #expect(!gate.allowsRefresh)
    #expect(gate.setSuspended(false, for: .sessionInactive) == .becameActive)
    #expect(gate.allowsRefresh)
}

@MainActor
@Test func taskStatusAnimationFollowsRefreshSuspension() {
    let model = UsageModel()

    #expect(!model.isTaskStatusAnimationPaused)
    model.setRefreshSuspended(true, for: .sessionInactive)
    model.setRefreshSuspended(true, for: .screensAsleep)
    #expect(model.isTaskStatusAnimationPaused)

    model.setRefreshSuspended(false, for: .screensAsleep)
    #expect(model.isTaskStatusAnimationPaused)
    model.setRefreshSuspended(false, for: .sessionInactive)
    #expect(!model.isTaskStatusAnimationPaused)
}
