import Foundation

/// Tolerant parser for `show/registered` output (verified against HB9HJI-2, V1.57).
///
/// The node prints a status header, then registered calls in fixed columns with a
/// `(level)` suffix, then a trailing count, e.g.:
/// ```
/// Registration is Required
/// HB9AF(1)       HB9TAA(1)      HB9TAF(1)
/// 3 records
/// ```
/// We extract the callsigns (dropping the `(…)` suffix) and surface whether registration
/// is required, keeping the raw text as a fallback for the UI.
public struct ShowRegisteredParser: Sendable {
    public init() {}

    public struct Result: Sendable, Equatable {
        public let users: [ClusterUser]
        /// `true`/`false` from the "Registration is Required/NOT Required" header, else `nil`.
        public let registrationRequired: Bool?
        public let rawText: String
    }

    public func parse(_ raw: String) -> Result {
        var seen = Set<String>()
        var users: [ClusterUser] = []
        var required: Bool?

        for rawLine in raw.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let lower = line.trimmingCharacters(in: .whitespaces).lowercased()

            if lower.hasPrefix("registration is") {
                required = !lower.contains("not")   // "Required" vs "NOT Required"
                continue
            }
            // Skip the trailing "N records" / "N record" summary line.
            if lower.hasSuffix("records") || lower.hasSuffix("record") { continue }

            for token in line.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                var call = String(token)
                // Drop the "(level)" status suffix, e.g. "HB9AF(1)" -> "HB9AF".
                if let paren = call.firstIndex(of: "(") {
                    call = String(call[call.startIndex..<paren])
                }
                call = call.uppercased()
                guard Callsign.isLikely(call), !seen.contains(call) else { continue }
                seen.insert(call)
                users.append(ClusterUser(callsign: call, isRegistered: true))
            }
        }

        return Result(users: users, registrationRequired: required, rawText: raw)
    }
}
