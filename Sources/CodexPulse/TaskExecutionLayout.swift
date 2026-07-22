import AppKit

struct TaskExecutionLayout {
    static let maximumHeight: CGFloat = 120
    static let projectRowHeight: CGFloat = 10
    static let sessionRowHeight: CGFloat = 11
    static let singleLineTaskRowHeight: CGFloat = 12
    static let twoLineTaskRowHeight: CGFloat = 22
    static let emptyStateHeight: CGFloat = 22

    struct Plan {
        let projects: [Project]
        let panelHeight: CGFloat
    }

    struct Project: Identifiable {
        let name: String
        var sessions: [Session]
        var id: String { name }
    }

    struct Session: Identifiable {
        let id: String
        let name: String
        var tasks: [TaskExecution]
    }

    struct SessionLink: Identifiable {
        let id: String
        let threadID: String
        let title: String
        let frame: CGRect
    }

    private struct SessionKey: Hashable {
        let projectName: String
        let threadID: String
    }

    static func taskRowHeight(for task: TaskExecution, panelWidth: CGFloat) -> CGFloat {
        let horizontalInsets = DockPanelContentLayout.horizontalInset * 2
        let fixedContentWidth: CGFloat = 8 + 9 + 6 + 2 + 45
        let availableMessageWidth = max(1, panelWidth - horizontalInsets - fixedContentWidth)
        let message = task.latestUserMessage.isEmpty ? "—" : task.latestUserMessage
        let width = ceil((message as NSString).size(withAttributes: [
            .font: NSFont.systemFont(ofSize: 9)
        ]).width)
        return width > availableMessageWidth ? twoLineTaskRowHeight : singleLineTaskRowHeight
    }

    static func plan(
        for tasks: [TaskExecution],
        panelWidth: CGFloat = DockPanelWidthGeometry.defaultWidth
    ) -> Plan {
        guard !tasks.isEmpty else {
            return Plan(
                projects: [],
                panelHeight: emptyStateHeight + DockPanelContentLayout.bottomInset
            )
        }

        let maximumContentHeight = maximumHeight - DockPanelContentLayout.bottomInset
        var selected: [TaskExecution] = []
        var knownProjects: Set<String> = []
        var knownSessions: Set<SessionKey> = []
        var usedHeight: CGFloat = 0

        func append(_ task: TaskExecution, respectingHeightLimit: Bool) {
            let sessionKey = SessionKey(projectName: task.projectName, threadID: task.threadID)
            var requiredHeight = taskRowHeight(for: task, panelWidth: panelWidth)
            if !knownProjects.contains(task.projectName) { requiredHeight += projectRowHeight }
            if !knownSessions.contains(sessionKey) { requiredHeight += sessionRowHeight }
            guard !respectingHeightLimit || usedHeight + requiredHeight <= maximumContentHeight else { return }

            selected.append(task)
            knownProjects.insert(task.projectName)
            knownSessions.insert(sessionKey)
            usedHeight += requiredHeight
        }

        let runningTasks = tasks.filter { !$0.isCompleted }.sorted(by: taskAscending)
        for task in runningTasks {
            append(task, respectingHeightLimit: false)
        }

        let recentCompletions = tasks.filter(\.isCompleted).sorted {
            let left = $0.completedAt ?? $0.startedAt
            let right = $1.completedAt ?? $1.startedAt
            if left == right { return $0.id < $1.id }
            return left < right
        }
        for task in recentCompletions.reversed() {
            append(task, respectingHeightLimit: true)
        }

        var projects: [Project] = []
        for task in selected {
            let projectIndex: Int
            if let existing = projects.firstIndex(where: { $0.name == task.projectName }) {
                projectIndex = existing
            } else {
                projects.append(Project(name: task.projectName, sessions: []))
                projectIndex = projects.index(before: projects.endIndex)
            }

            if let sessionIndex = projects[projectIndex].sessions.firstIndex(where: { $0.id == task.threadID }) {
                projects[projectIndex].sessions[sessionIndex].tasks.append(task)
            } else {
                projects[projectIndex].sessions.append(
                    Session(id: task.threadID, name: task.title, tasks: [task])
                )
            }
        }

        for projectIndex in projects.indices {
            for sessionIndex in projects[projectIndex].sessions.indices {
                projects[projectIndex].sessions[sessionIndex].tasks.sort(by: taskAscending)
            }
            projects[projectIndex].sessions.sort {
                sessionLatestStart($0) < sessionLatestStart($1)
            }
        }
        projects.sort {
            projectLatestStart($0) < projectLatestStart($1)
        }

        return Plan(
            projects: projects,
            panelHeight: usedHeight + DockPanelContentLayout.bottomInset
        )
    }

    static func sessionLinks(for plan: Plan, panelWidth: CGFloat) -> [SessionLink] {
        let contentHeight = plan.panelHeight - DockPanelContentLayout.bottomInset
        let x = DockPanelContentLayout.horizontalInset + 8
        let maximumWidth = max(1, panelWidth - x - DockPanelContentLayout.horizontalInset)
        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        var offsetFromTop: CGFloat = 0
        var links: [SessionLink] = []

        for project in plan.projects {
            offsetFromTop += projectRowHeight
            for session in project.sessions {
                let title = "# \(session.name)"
                let titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width) + 2
                let y = DockPanelContentLayout.bottomInset
                    + contentHeight - offsetFromTop - sessionRowHeight
                links.append(SessionLink(
                    id: "\(project.name)\u{0}\(session.id)",
                    threadID: session.id,
                    title: title,
                    frame: CGRect(x: x, y: y, width: min(maximumWidth, titleWidth), height: sessionRowHeight)
                ))
                offsetFromTop += sessionRowHeight
                for task in session.tasks {
                    offsetFromTop += taskRowHeight(for: task, panelWidth: panelWidth)
                }
            }
        }
        return links
    }

    private static func taskAscending(_ left: TaskExecution, _ right: TaskExecution) -> Bool {
        if left.startedAt == right.startedAt { return left.id < right.id }
        return left.startedAt < right.startedAt
    }

    private static func sessionLatestStart(_ session: Session) -> Date {
        session.tasks.map(\.startedAt).max() ?? .distantPast
    }

    private static func projectLatestStart(_ project: Project) -> Date {
        project.sessions.map(sessionLatestStart).max() ?? .distantPast
    }
}
