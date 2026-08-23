import Foundation

/// Allocation-light parser for the narrow subset of Codex rollout JSON used
/// by the usage panel. It deliberately does not construct a JSON object tree:
/// the scanner only needs the root timestamp, token counters, and rate limits.
struct CodexTokenCountEvent: Sendable, Equatable {
    struct RateWindow: Sendable, Equatable {
        let minutes: Int
        let resetsAt: Double
        let usedPercent: Double
    }

    struct RateLimits: Sendable, Equatable {
        /// `nil` is the legacy account-level shape. False identifies a named
        /// or model-specific quota that must not appear in the panel.
        var isAccountLimit: Bool?
        var primary: RateWindow?
        var secondary: RateWindow?
        var individual: RateWindow?
    }

    let observedAt: Date?
    let cumulative: Usage?
    let last: Usage?
    let rateLimits: RateLimits?
}

enum CodexTokenCountParser {
    nonisolated static func parse(_ line: Data.SubSequence) -> CodexTokenCountEvent? {
        var cursor = JSONByteCursor(line)
        guard cursor.beginObject() else { return nil }

        var first = true
        var observedAt: Date?
        var isEventMessage = false
        var payload: ParsedPayload?
        while let key = cursor.nextObjectKey(first: &first) {
            if cursor.matches(key, ascii: "timestamp") {
                observedAt = cursor.readStringToken().flatMap { cursor.iso8601Date($0) }
            } else if cursor.matches(key, ascii: "type") {
                isEventMessage = cursor.readStringToken().map {
                    cursor.matches($0, ascii: "event_msg")
                } ?? false
            } else if cursor.matches(key, ascii: "payload") {
                payload = parsePayload(&cursor)
            } else {
                cursor.skipValue()
            }
        }

        guard cursor.isValid, isEventMessage, let payload, payload.isTokenCount else { return nil }
        return CodexTokenCountEvent(
            observedAt: observedAt,
            cumulative: payload.cumulative,
            last: payload.last,
            rateLimits: payload.rateLimits
        )
    }

    private struct ParsedPayload {
        var isTokenCount = false
        var cumulative: Usage?
        var last: Usage?
        var rateLimits: CodexTokenCountEvent.RateLimits?
    }

    private nonisolated static func parsePayload(_ cursor: inout JSONByteCursor) -> ParsedPayload? {
        guard cursor.beginObject() else {
            cursor.skipValue()
            return nil
        }
        var payload = ParsedPayload()
        var first = true
        while let key = cursor.nextObjectKey(first: &first) {
            if cursor.matches(key, ascii: "type") {
                payload.isTokenCount = cursor.readStringToken().map {
                    cursor.matches($0, ascii: "token_count")
                } ?? false
            } else if cursor.matches(key, ascii: "info") {
                let info = parseInfo(&cursor)
                payload.cumulative = info.cumulative
                payload.last = info.last
            } else if cursor.matches(key, ascii: "rate_limits") {
                payload.rateLimits = parseRateLimits(&cursor)
            } else {
                cursor.skipValue()
            }
        }
        return payload
    }

    private nonisolated static func parseInfo(
        _ cursor: inout JSONByteCursor
    ) -> (cumulative: Usage?, last: Usage?) {
        guard cursor.beginObject() else {
            cursor.skipValue()
            return (nil, nil)
        }
        var cumulative: Usage?
        var last: Usage?
        var first = true
        while let key = cursor.nextObjectKey(first: &first) {
            if cursor.matches(key, ascii: "total_token_usage") {
                cumulative = parseUsage(&cursor)
            } else if cursor.matches(key, ascii: "last_token_usage") {
                last = parseUsage(&cursor)
            } else {
                cursor.skipValue()
            }
        }
        return (cumulative, last)
    }

    private nonisolated static func parseUsage(_ cursor: inout JSONByteCursor) -> Usage? {
        guard cursor.beginObject() else {
            cursor.skipValue()
            return nil
        }
        var inclusiveInput = 0
        var cachedInput = 0
        var output = 0
        var foundCounter = false
        var first = true
        while let key = cursor.nextObjectKey(first: &first) {
            if cursor.matches(key, ascii: "input_tokens") {
                inclusiveInput = max(0, cursor.readInt() ?? 0)
                foundCounter = true
            } else if cursor.matches(key, ascii: "cached_input_tokens") {
                cachedInput = max(0, cursor.readInt() ?? 0)
            } else if cursor.matches(key, ascii: "output_tokens") {
                output = max(0, cursor.readInt() ?? 0)
            } else {
                cursor.skipValue()
            }
        }
        guard foundCounter else { return nil }
        return Usage(
            input: max(0, inclusiveInput - cachedInput),
            output: output,
            cacheRead: cachedInput,
            requests: 1
        )
    }

    private nonisolated static func parseRateLimits(
        _ cursor: inout JSONByteCursor
    ) -> CodexTokenCountEvent.RateLimits? {
        guard cursor.beginObject() else {
            cursor.skipValue()
            return nil
        }
        var limits = CodexTokenCountEvent.RateLimits()
        var first = true
        while let key = cursor.nextObjectKey(first: &first) {
            if cursor.matches(key, ascii: "limit_id") {
                limits.isAccountLimit = cursor.readStringToken().map {
                    cursor.matches($0, ascii: "codex")
                }
            } else if cursor.matches(key, ascii: "primary") {
                limits.primary = parseRateWindow(&cursor)
            } else if cursor.matches(key, ascii: "secondary") {
                limits.secondary = parseRateWindow(&cursor)
            } else if cursor.matches(key, ascii: "individual_limit") {
                limits.individual = parseRateWindow(&cursor)
            } else {
                cursor.skipValue()
            }
        }
        return limits
    }

    private nonisolated static func parseRateWindow(
        _ cursor: inout JSONByteCursor
    ) -> CodexTokenCountEvent.RateWindow? {
        guard cursor.beginObject() else {
            cursor.skipValue()
            return nil
        }
        var minutes: Int?
        var resetsAt: Double?
        var usedPercent: Double?
        var first = true
        while let key = cursor.nextObjectKey(first: &first) {
            if cursor.matches(key, ascii: "window_minutes") {
                minutes = cursor.readInt()
            } else if cursor.matches(key, ascii: "resets_at") {
                resetsAt = cursor.readDouble()
            } else if cursor.matches(key, ascii: "used_percent") {
                usedPercent = cursor.readDouble()
            } else {
                cursor.skipValue()
            }
        }
        guard let minutes, let resetsAt else { return nil }
        return CodexTokenCountEvent.RateWindow(
            minutes: minutes,
            resetsAt: resetsAt,
            usedPercent: usedPercent ?? 0
        )
    }
}

private struct JSONByteCursor {
    struct StringToken {
        let range: Range<Data.Index>
        let containsEscape: Bool
    }

    let bytes: Data.SubSequence
    var index: Data.Index
    var isValid = true

    init(_ bytes: Data.SubSequence) {
        self.bytes = bytes
        self.index = bytes.startIndex
    }

    mutating func beginObject() -> Bool {
        skipWhitespace()
        return consume(0x7B)
    }

    mutating func nextObjectKey(first: inout Bool) -> StringToken? {
        skipWhitespace()
        guard index < bytes.endIndex else {
            isValid = false
            return nil
        }
        if bytes[index] == 0x7D {
            advance()
            return nil
        }
        if first {
            first = false
        } else {
            guard consume(0x2C) else {
                isValid = false
                return nil
            }
        }
        guard let key = readStringToken() else {
            isValid = false
            return nil
        }
        skipWhitespace()
        guard consume(0x3A) else {
            isValid = false
            return nil
        }
        return key
    }

    mutating func readStringToken() -> StringToken? {
        skipWhitespace()
        guard consume(0x22) else { return nil }
        let start = index
        var escaped = false
        while index < bytes.endIndex {
            switch bytes[index] {
            case 0x22:
                let token = StringToken(range: start..<index, containsEscape: escaped)
                advance()
                return token
            case 0x5C:
                escaped = true
                advance()
                guard index < bytes.endIndex else { return nil }
                advance()
            default:
                advance()
            }
        }
        isValid = false
        return nil
    }

    func matches(_ token: StringToken, ascii: StaticString) -> Bool {
        guard !token.containsEscape else { return false }
        return ascii.withUTF8Buffer { expected in
            guard token.range.count == expected.count else { return false }
            var source = token.range.lowerBound
            for byte in expected {
                guard bytes[source] == byte else { return false }
                source = bytes.index(after: source)
            }
            return true
        }
    }

    mutating func readInt() -> Int? {
        guard let number = readDouble(), number.isFinite,
              number >= Double(Int.min), number <= Double(Int.max) else { return nil }
        return Int(number)
    }

    mutating func readDouble() -> Double? {
        skipWhitespace()
        let start = index
        var sign = 1.0
        if consume(0x2D) { sign = -1 }
        var value = 0.0
        var hasDigit = false
        while index < bytes.endIndex, let digit = digit(bytes[index]) {
            hasDigit = true
            value = value * 10 + Double(digit)
            advance()
        }
        if consume(0x2E) {
            var divisor = 10.0
            while index < bytes.endIndex, let digit = digit(bytes[index]) {
                hasDigit = true
                value += Double(digit) / divisor
                divisor *= 10
                advance()
            }
        }
        if index < bytes.endIndex, bytes[index] == 0x65 || bytes[index] == 0x45 {
            advance()
            var exponentSign = 1
            if consume(0x2D) { exponentSign = -1 }
            else if consume(0x2B) {}
            var exponent = 0
            var hasExponentDigit = false
            while index < bytes.endIndex, let digit = digit(bytes[index]) {
                hasExponentDigit = true
                exponent = exponent * 10 + digit
                advance()
            }
            guard hasExponentDigit else {
                isValid = false
                return nil
            }
            value *= pow(10, Double(exponentSign * exponent))
        }
        guard hasDigit, index > start else {
            isValid = false
            return nil
        }
        return sign * value
    }

    mutating func skipValue(depth: Int = 0) {
        guard depth < 64 else {
            isValid = false
            return
        }
        skipWhitespace()
        guard index < bytes.endIndex else {
            isValid = false
            return
        }
        switch bytes[index] {
        case 0x22:
            _ = readStringToken()
        case 0x7B:
            advance()
            var first = true
            while let _ = nextObjectKey(first: &first) { skipValue(depth: depth + 1) }
        case 0x5B:
            advance()
            skipWhitespace()
            if consume(0x5D) { return }
            while isValid {
                skipValue(depth: depth + 1)
                skipWhitespace()
                if consume(0x5D) { return }
                guard consume(0x2C) else {
                    isValid = false
                    return
                }
            }
        case 0x74:
            consumeLiteral("true")
        case 0x66:
            consumeLiteral("false")
        case 0x6E:
            consumeLiteral("null")
        default:
            _ = readDouble()
        }
    }

    func iso8601Date(_ token: StringToken) -> Date? {
        guard !token.containsEscape else { return nil }
        let range = token.range
        guard range.count >= 20 else { return nil }
        let position = range.lowerBound
        func byte(at offset: Int) -> UInt8? {
            guard offset >= 0, offset < range.count else { return nil }
            let candidate = bytes.index(position, offsetBy: offset)
            return bytes[candidate]
        }
        func number(at offset: Int, count: Int) -> Int? {
            var result = 0
            for step in 0..<count {
                guard let byte = byte(at: offset + step), let digit = digit(byte) else { return nil }
                result = result * 10 + digit
            }
            return result
        }
        guard byte(at: 4) == 0x2D, byte(at: 7) == 0x2D,
              byte(at: 10) == 0x54 || byte(at: 10) == 0x74 || byte(at: 10) == 0x20,
              byte(at: 13) == 0x3A, byte(at: 16) == 0x3A,
              let year = number(at: 0, count: 4),
              let month = number(at: 5, count: 2),
              let day = number(at: 8, count: 2),
              let hour = number(at: 11, count: 2),
              let minute = number(at: 14, count: 2),
              let second = number(at: 17, count: 2),
              (1...12).contains(month), (1...31).contains(day),
              (0...23).contains(hour), (0...59).contains(minute), (0...60).contains(second)
        else { return nil }

        var offset = 19
        var fraction = 0.0
        if byte(at: offset) == 0x2E {
            offset += 1
            var divisor = 10.0
            while let value = byte(at: offset), let digit = digit(value) {
                fraction += Double(digit) / divisor
                divisor *= 10
                offset += 1
            }
        }

        var timezoneOffset = 0
        if byte(at: offset) == 0x5A || byte(at: offset) == 0x7A {
            offset += 1
        } else if byte(at: offset) == 0x2B || byte(at: offset) == 0x2D {
            let direction = byte(at: offset) == 0x2B ? 1 : -1
            guard let zoneHour = number(at: offset + 1, count: 2),
                  byte(at: offset + 3) == 0x3A,
                  let zoneMinute = number(at: offset + 4, count: 2) else { return nil }
            timezoneOffset = direction * (zoneHour * 3_600 + zoneMinute * 60)
            offset += 6
        } else {
            return nil
        }
        guard offset == range.count else { return nil }

        let adjustedYear = year - (month <= 2 ? 1 : 0)
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yearOfEra = adjustedYear - era * 400
        let shiftedMonth = month + (month > 2 ? -3 : 9)
        let dayOfYear = (153 * shiftedMonth + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        let daysSinceEpoch = era * 146_097 + dayOfEra - 719_468
        let seconds = daysSinceEpoch * 86_400 + hour * 3_600 + minute * 60 + second - timezoneOffset
        return Date(timeIntervalSince1970: Double(seconds) + fraction)
    }

    private mutating func consumeLiteral(_ literal: StaticString) {
        let matched = literal.withUTF8Buffer { expected -> Bool in
            var candidate = index
            for byte in expected {
                guard candidate < bytes.endIndex, bytes[candidate] == byte else { return false }
                candidate = bytes.index(after: candidate)
            }
            index = candidate
            return true
        }
        if !matched { isValid = false }
    }

    private mutating func skipWhitespace() {
        while index < bytes.endIndex {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: advance()
            default: return
            }
        }
    }

    @discardableResult
    private mutating func consume(_ byte: UInt8) -> Bool {
        skipWhitespace()
        guard index < bytes.endIndex, bytes[index] == byte else { return false }
        advance()
        return true
    }

    private mutating func advance() {
        index = bytes.index(after: index)
    }

    private func digit(_ byte: UInt8) -> Int? {
        guard byte >= 0x30, byte <= 0x39 else { return nil }
        return Int(byte - 0x30)
    }
}
