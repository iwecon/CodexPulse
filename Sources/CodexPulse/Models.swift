import Foundation

enum Tool: String, CaseIterable, Identifiable, Sendable {
    case claude = "Claude Code"
    case codex = "Codex / ChatGPT"
    case opencode = "OpenCode"
    var id: Self { self }
    var symbol: String { switch self { case .claude: "brain.head.profile"; case .codex: "terminal"; case .opencode: "chevron.left.forwardslash.chevron.right" } }
}

enum UsageSourcePolicy {
    /// Product default: retain every source implementation, but collect Codex usage only.
    static let enabledTools: Set<Tool> = [.codex]
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
    var title: String
    var projectName = ""
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
