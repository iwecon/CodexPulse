import Foundation
import Testing
@testable import CodexPulse

private func layoutTask(
    _ id: String,
    project: String = "Codex Pulse",
    session: String = "session-1",
    message: String? = nil,
    startedAt: Date = Date(timeIntervalSince1970: 1_780_000_000)
) -> TaskExecution {
    TaskExecution(
        id: id,
        threadID: session,
        title: session,
        projectName: project,
        latestUserMessage: message ?? id,
        startedAt: startedAt,
        completedAt: nil
    )
}

@Test func taskExecutionLayoutUsesCompactExactEmptyHeight() {
    let plan = TaskExecutionLayout.plan(for: [])

    #expect(plan.projects.isEmpty)
    #expect(plan.panelHeight == TaskExecutionLayout.emptyStateHeight + DockPanelContentLayout.bottomInset)
    #expect(plan.panelHeight < TaskExecutionLayout.maximumHeight)
}

@Test func taskExecutionLayoutSizesOneTaskExactly() throws {
    let plan = TaskExecutionLayout.plan(for: [layoutTask("task-1")])

    #expect(plan.panelHeight == 37)
    #expect(try #require(plan.projects.first).sessions.first?.tasks.map(\.id) == ["task-1"])
}

@Test func taskExecutionLayoutSharesProjectAndSessionRows() throws {
    let plan = TaskExecutionLayout.plan(for: [layoutTask("task-1"), layoutTask("task-2")])

    #expect(plan.panelHeight == 49)
    #expect(try #require(plan.projects.first).sessions.count == 1)
    #expect(try #require(plan.projects.first?.sessions.first).tasks.count == 2)
}

@Test func taskExecutionLayoutAddsOnlyNewSessionRowWithinProject() throws {
    let plan = TaskExecutionLayout.plan(for: [
        layoutTask("task-1"),
        layoutTask("task-2", session: "session-2")
    ])

    #expect(plan.panelHeight == 60)
    #expect(try #require(plan.projects.first).sessions.count == 2)
}

@Test func taskExecutionLayoutAddsProjectAndSessionRowsTogether() {
    let plan = TaskExecutionLayout.plan(for: [
        layoutTask("task-1"),
        layoutTask("task-2", project: "Other", session: "session-2")
    ])

    #expect(plan.panelHeight == 70)
    #expect(plan.projects.count == 2)
}

@Test func taskExecutionLayoutUsesExactVisibleHeightWhenMoreRowsDoNotFit() {
    let tasks = (1...6).map { layoutTask("task-\($0)") }
    let plan = TaskExecutionLayout.plan(for: tasks)

    #expect(plan.panelHeight == 97)
    #expect(plan.panelHeight < TaskExecutionLayout.maximumHeight)
    #expect(plan.projects.flatMap(\.sessions).flatMap(\.tasks).count == 6)
}

@Test func taskExecutionLayoutKeepsTwoLinesForMessagesThatWrap() throws {
    let task = layoutTask("task-1", message: String(repeating: "较长消息", count: 40))
    let plan = TaskExecutionLayout.plan(for: [task], panelWidth: 180)

    #expect(TaskExecutionLayout.taskRowHeight(for: task, panelWidth: 180) == TaskExecutionLayout.twoLineTaskRowHeight)
    #expect(plan.panelHeight == 47)
}

@Test func taskExecutionLayoutSessionLinksMatchSessionRows() throws {
    let plan = TaskExecutionLayout.plan(for: [layoutTask("task-1")], panelWidth: 350)
    let link = try #require(TaskExecutionLayout.sessionLinks(for: plan, panelWidth: 350).first)

    #expect(link.threadID == "session-1")
    #expect(link.title == "# session-1")
    #expect(link.frame.height == TaskExecutionLayout.sessionRowHeight)
    #expect(link.frame.minY == DockPanelContentLayout.bottomInset + TaskExecutionLayout.singleLineTaskRowHeight)
}

@Test func taskExecutionLayoutRightAlignsSessionLinks() throws {
    let panelWidth: CGFloat = 350
    let plan = TaskExecutionLayout.plan(for: [layoutTask("task-1")], panelWidth: panelWidth)
    let left = try #require(TaskExecutionLayout.sessionLinks(
        for: plan,
        panelWidth: panelWidth,
        textAlignment: .left
    ).first)
    let right = try #require(TaskExecutionLayout.sessionLinks(
        for: plan,
        panelWidth: panelWidth,
        textAlignment: .right
    ).first)

    #expect(left.frame.width == right.frame.width)
    #expect(left.frame.minX == DockPanelContentLayout.horizontalInset + 8)
    #expect(right.frame.maxX == panelWidth - DockPanelContentLayout.horizontalInset - 8)
}

@Test func taskExecutionLayoutKeepsNewestTaskAtBottomAcrossGroups() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let tasks = [
        layoutTask("old-a", project: "A", startedAt: base),
        layoutTask("middle-b", project: "B", startedAt: base.addingTimeInterval(1)),
        layoutTask("new-a", project: "A", startedAt: base.addingTimeInterval(2)),
    ]

    let plan = TaskExecutionLayout.plan(for: tasks)
    let displayed = plan.projects.flatMap(\.sessions).flatMap(\.tasks)
    #expect(displayed.last?.id == "new-a")
}

@Test func taskExecutionLayoutDropsOldestRowsFirstWhenHeightIsLimited() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let longMessage = String(repeating: "很长", count: 100)
    let tasks = (0..<6).map { index in
        var task = layoutTask(
            "task-\(index)",
            message: longMessage,
            startedAt: base.addingTimeInterval(Double(index))
        )
        task.completedAt = base.addingTimeInterval(Double(index + 10))
        return task
    }

    let plan = TaskExecutionLayout.plan(for: tasks, panelWidth: 180)
    let displayed = plan.projects.flatMap(\.sessions).flatMap(\.tasks)
    #expect(displayed.map(\.id) == ["task-2", "task-3", "task-4", "task-5"])
}

@Test func taskExecutionLayoutShowsAllRunningTasksBeyondNormalMaximumHeight() {
    let base = Date(timeIntervalSince1970: 1_780_000_000)
    let longMessage = String(repeating: "很长", count: 100)
    let tasks = (0..<6).map { index in
        TaskExecution(
            id: "running-\(index)",
            threadID: "session-1",
            title: "session-1",
            projectName: "Codex Pulse",
            latestUserMessage: longMessage,
            startedAt: base.addingTimeInterval(Double(index)),
            completedAt: nil
        )
    }

    let plan = TaskExecutionLayout.plan(for: tasks, panelWidth: 180)
    let displayed = plan.projects.flatMap(\.sessions).flatMap(\.tasks)

    #expect(displayed.map(\.id) == tasks.map(\.id))
    #expect(plan.panelHeight > TaskExecutionLayout.maximumHeight)
}
