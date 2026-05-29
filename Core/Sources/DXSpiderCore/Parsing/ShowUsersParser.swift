import Foundation

/// Preliminary, tolerant parser for `show/users` output.
///
/// DXSpider prints free text in fixed columns whose exact shape can vary between
/// versions. Until real fixtures from HB9HJI-2 are captured (see Konzeptdokument §10),
/// this extracts callsign-shaped tokens and de-duplicates them, so callers always get a
/// usable list plus access to the raw text as a fallback.
public struct ShowUsersParser: Sendable {
    public init() {}

    /// The raw, unparsed response, kept so the UI can fall back to plain text.
    public struct Result: Sendable, Equatable {
        public let users: [ClusterUser]
        public let rawText: String
    }

    public func parse(_ raw: String) -> Result {
        var seen = Set<String>()
        var users: [ClusterUser] = []

        for line in raw.split(whereSeparator: \.isNewline) {
            let tokens = line.split { $0 == " " || $0 == "\t" || $0 == "," }
            for token in tokens {
                let candidate = String(token).uppercased()
                guard Self.isLikelyCallsign(candidate), !seen.contains(candidate) else {
                    continue
                }
                seen.insert(candidate)
                users.append(ClusterUser(callsign: candidate))
            }
        }

        return Result(users: users, rawText: raw)
    }

    /// Heuristic: an amateur callsign is short, alphanumeric (plus an optional `-SSID`),
    /// and contains at least one letter and one digit.
    static func isLikelyCallsign(_ token: String) -> Bool {
        let parts = token.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
        guard let base = parts.first, (3...10).contains(base.count) else { return false }

        var hasLetter = false
        var hasDigit = false
        for ch in base {
            if ch.isLetter, ch.isASCII { hasLetter = true }
            else if ch.isNumber, ch.isASCII { hasDigit = true }
            else { return false } // only A-Z/0-9 allowed in the base
        }
        guard hasLetter, hasDigit else { return false }

        // Optional SSID must be 1–2 digits.
        if parts.count == 2 {
            let ssid = parts[1]
            guard (1...2).contains(ssid.count), ssid.allSatisfy({ $0.isNumber && $0.isASCII }) else {
                return false
            }
        }
        return true
    }
}
