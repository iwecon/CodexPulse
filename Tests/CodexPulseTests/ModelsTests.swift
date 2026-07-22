import Foundation
import Testing
@testable import CodexPulse

@Test func completedTaskDimsOnlyAfterThreeMinutes() {
    let completedAt = Date(timeIntervalSince1970: 1_780_000_000)
    let task = TaskExecution(
        id: "completed",
        threadID: "thread",
        title: "任务",
        startedAt: completedAt.addingTimeInterval(-30),
        completedAt: completedAt
    )

    #expect(!task.shouldDimMessage(at: completedAt.addingTimeInterval(179)))
    #expect(!task.shouldDimMessage(at: completedAt.addingTimeInterval(180)))
    #expect(task.shouldDimMessage(at: completedAt.addingTimeInterval(181)))
}

@Test func runningTaskNeverDimsAsCompleted() {
    let startedAt = Date(timeIntervalSince1970: 1_780_000_000)
    let task = TaskExecution(
        id: "running",
        threadID: "thread",
        title: "任务",
        startedAt: startedAt,
        completedAt: nil
    )

    #expect(!task.shouldDimMessage(at: startedAt.addingTimeInterval(600)))
}
