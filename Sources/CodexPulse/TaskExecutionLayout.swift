import AppKit

struct TaskExecutionLayout {
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
        let tool: Tool
        let name: String
        var tasks: [TaskExecution]
    }

    struct SessionLink: Identifiable {
        let id: String
        let threadID: String
        let tool: Tool
        /// Project directory backing directory-based deep links; empty when
        /// none of the session's tasks reported one.
        let directory: String
        let title: String
        let frame: CGRect
    }

    private struct SessionKey: Hashable {
        let projectName: String
        let threadID: String
    }

    static func emptyStateTextAlignment(for panelSide: PanelSide) -> TaskActivityTextAlignment {
        panelSide == .left ? .left : .right
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

        // The panel has no height cap: every task passed in (all running
        // tasks plus completions still inside their visibility window)
        // renders, and the panel height follows the content exactly.
        var usedHeight: CGFloat = 0
        var knownProjects: Set<String> = []
        var knownSessions: Set<SessionKey> = []
        for task in tasks {
            let sessionKey = SessionKey(projectName: task.projectName, threadID: task.threadID)
            usedHeight += taskRowHeight(for: task, panelWidth: panelWidth)
            if knownProjects.insert(task.projectName).inserted { usedHeight += projectRowHeight }
            if knownSessions.insert(sessionKey).inserted { usedHeight += sessionRowHeight }
        }

        var projects: [Project] = []
        for task in tasks {
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
                    Session(id: task.threadID, tool: task.tool, name: task.title, tasks: [task])
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

    static func sessionLinks(
        for plan: Plan,
        panelWidth: CGFloat,
        textAlignment: TaskActivityTextAlignment = .left
    ) -> [SessionLink] {
        let contentHeight = plan.panelHeight - DockPanelContentLayout.bottomInset
        let horizontalOffset = DockPanelContentLayout.horizontalInset + 8
        let maximumWidth = max(1, panelWidth - horizontalOffset - DockPanelContentLayout.horizontalInset)
        let font = NSFont.systemFont(ofSize: 8, weight: .semibold)
        var offsetFromTop: CGFloat = 0
        var links: [SessionLink] = []

        for project in plan.projects {
            offsetFromTop += projectRowHeight
            for session in project.sessions {
                let title = "# \(session.name)"
                let titleWidth = ceil((title as NSString).size(withAttributes: [.font: font]).width) + 2
                let width = min(maximumWidth, titleWidth)
                let x = textAlignment == .left
                    ? horizontalOffset
                    : panelWidth - horizontalOffset - width
                let y = DockPanelContentLayout.bottomInset
                    + contentHeight - offsetFromTop - sessionRowHeight
                links.append(SessionLink(
                    id: "\(project.name)\u{0}\(session.id)",
                    threadID: session.id,
                    tool: session.tool,
                    directory: session.tasks.first(where: { !$0.directory.isEmpty })?.directory ?? "",
                    title: title,
                    frame: CGRect(x: x, y: y, width: width, height: sessionRowHeight)
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
