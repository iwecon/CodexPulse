import Foundation

enum Tool: String, CaseIterable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex / ChatGPT"
    case opencode = "OpenCode"
    var id: Self { self }
    /// Stable identifier for `UserDefaults` keys; the raw value is a display
    /// name and must never leak into persistence.
    var settingsKey: String { switch self { case .claude: "claude"; case .codex: "codex"; case .opencode: "opencode" } }
    var symbol: String { switch self { case .claude: "brain.head.profile"; case .codex: "terminal"; case .opencode: "chevron.left.forwardslash.chevron.right" } }
    /// OKLab hue distinguishing this tool's trend-bar segments and legend dot.
    /// `nil` renders achromatic — OpenCode's monochrome brand shows as white
    /// on dark panels and dark gray on light panels.
    var barHueDegrees: Double? { switch self { case .claude: 55; case .codex: 290; case .opencode: nil } }
    /// Exact brand color that overrides the polarity-adaptive hue rendering.
    /// Codex uses its brand blue #4144F5 in both panel appearances.
    var fixedBarColor: WallpaperRGB? {
        switch self {
        case .codex: WallpaperRGB(red: 65 / 255, green: 68 / 255, blue: 245 / 255)
        case .claude, .opencode: nil
        }
    }
}

enum UsageSourcePolicy {
    /// Product default: scan every source. The Usage Overview Panel shows a
    /// tool only while it has usage inside the visible 14-day window, so
    /// uninstalled or dormant tools stay invisible without a setting.
    static let enabledTools: Set<Tool> = Set(Tool.allCases)
}

struct Usage: Sendable, Equatable {
    var input = 0
    var output = 0
    var cacheRead = 0
    var cacheWrite = 0
    var costUSD = 0.0
    var requests = 0
    var total: Int { input + output + cacheRead + cacheWrite }
    static let zero = Usage()
    mutating func add(_ other: Usage) {
        input += other.input; output += other.output; cacheRead += other.cacheRead
        cacheWrite += other.cacheWrite; costUSD += other.costUSD; requests += other.requests
    }
}

struct RateWindow: Identifiable, Sendable, Equatable {
    let name: String
    let used: Double
    let minutes: Int
    let resetsAt: Date
    let observedAt: Date
    var id: String { "\(name)-\(minutes)" }
}

struct DailyUsage: Identifiable, Sendable, Equatable {
    let date: Date
    var usage: [Tool: Usage] = [:]
    var id: Date { date }
    var total: Int { usage.values.reduce(0) { $0 + $1.total } }
}

struct TaskExecution: Identifiable, Sendable, Equatable {
    static let completedDimmingDelay: TimeInterval = 3 * 60
    static let completedVisibilityDuration: TimeInterval = 10 * 60

    let id: String
    let threadID: String
    /// Source application of this task, selecting the session deep link
    /// style: Codex and Claude Code resume their exact session, OpenCode
    /// jumps to the session's project directory.
    var tool: Tool = .codex
    var title: String
    var projectName = ""
    /// Absolute project directory backing OpenCode's directory-based deep
    /// link; empty when the source never reported one.
    var directory = ""
    var latestUserMessage = ""
    let startedAt: Date
    var completedAt: Date?

    var isCompleted: Bool { completedAt != nil }

    func shouldDimMessage(at now: Date) -> Bool {
        guard let completedAt else { return false }
        return now.timeIntervalSince(completedAt) > Self.completedDimmingDelay
    }
}

enum TaskEventKind: Sendable {
    case started
    case completed(Date)
    case aborted(Date)
    case userMessage(String, Date)
}

struct TaskExecutionEvent: Sendable {
    let id: String
    let threadID: String
    let title: String
    let projectName: String
    let startedAt: Date
    let kind: TaskEventKind

    var eventDate: Date {
        switch kind {
        case .started: startedAt
        case .completed(let date): date
        case .aborted(let date): date
        case .userMessage(_, let date): date
        }
    }
}

struct Snapshot: Sendable {
    var usage: [Tool: Usage] = [:]
    var dailyUsage: [DailyUsage] = []
    var limits: [RateWindow] = []
    var errors: [Tool: String] = [:]
    var updatedAt = Date()

    /// Tools with usage inside the visible 14-day window, in display order.
    var activeTools: [Tool] {
        Tool.allCases.filter { tool in
            dailyUsage.contains { ($0.usage[tool]?.total ?? 0) > 0 }
        }
    }

    func hasSameContent(as other: Snapshot) -> Bool {
        usage == other.usage
            && dailyUsage == other.dailyUsage
            && limits == other.limits
            && errors == other.errors
    }
}

struct Pricing: Sendable {
    let input, output, cacheRead, cacheWrite: Double
    static func forModel(_ raw: String) -> Pricing {
        let model = raw.lowercased().split(separator: "/").last.map(String.init) ?? raw.lowercased()
        if model.contains("opus") { return .init(input: 15, output: 75, cacheRead: 1.5, cacheWrite: 18.75) }
        if model.contains("haiku") { return .init(input: 0.8, output: 4, cacheRead: 0.08, cacheWrite: 1) }
        if model.contains("sonnet") { return .init(input: 3, output: 15, cacheRead: 0.3, cacheWrite: 3.75) }
        if model.contains("gpt-5.3") { return .init(input: 1.75, output: 14, cacheRead: 0.175, cacheWrite: 0) }
        if model.contains("gpt-5") { return .init(input: 1.25, output: 10, cacheRead: 0.125, cacheWrite: 0) }
        if model.contains("deepseek") { return .init(input: 0.28, output: 1.11, cacheRead: 0.028, cacheWrite: 0) }
        return .init(input: 0, output: 0, cacheRead: 0, cacheWrite: 0)
    }
    func cost(_ u: Usage) -> Double {
        (Double(u.input) * input + Double(u.output) * output + Double(u.cacheRead) * cacheRead + Double(u.cacheWrite) * cacheWrite) / 1_000_000
    }
}
