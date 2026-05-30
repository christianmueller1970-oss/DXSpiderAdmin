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

    /// Heuristic for a callsign-shaped token. Delegates to ``Callsign/isLikely(_:)``.
    static func isLikelyCallsign(_ token: String) -> Bool {
        Callsign.isLikely(token)
    }
}
