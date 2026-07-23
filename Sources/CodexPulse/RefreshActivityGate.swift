enum RefreshSuspensionReason: Hashable {
    case sessionInactive
    case screensAsleep
}

enum RefreshActivityTransition: Equatable {
    case unchanged
    case becameSuspended
    case becameActive
}

struct RefreshActivityGate {
    private(set) var suspensionReasons: Set<RefreshSuspensionReason> = []

    var allowsRefresh: Bool {
        suspensionReasons.isEmpty
    }

    @discardableResult
    mutating func setSuspended(
        _ suspended: Bool,
        for reason: RefreshSuspensionReason
    ) -> RefreshActivityTransition {
        let previouslyAllowed = allowsRefresh
        if suspended {
            suspensionReasons.insert(reason)
        } else {
            suspensionReasons.remove(reason)
        }

        return switch (previouslyAllowed, allowsRefresh) {
        case (true, false): .becameSuspended
        case (false, true): .becameActive
        default: .unchanged
        }
    }
}
