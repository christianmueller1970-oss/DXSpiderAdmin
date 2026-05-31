import Foundation

/// Tolerant parser for the simple "list of entries" admin outputs: `show/badspotter`,
/// `show/badnode`, `show/baddx`, `show/badword` and `show/lockout ALL`.
///
/// These print entries (callsigns, or words for bad-words) in fixed columns, sometimes with
/// a header (`Words:`) and/or a trailing count (`441 records`, `0 BadWords`). We extract the
/// distinct entries and drop headers, counts and bare numbers. Verified against HB9HJI-2.
public struct ShowListParser: Sendable {
    public init() {}

    public func parse(_ raw: String) -> [String] {
        var seen = Set<String>()
        var entries: [String] = []

        for rawLine in raw.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let lower = line.trimmingCharacters(in: .whitespaces).lowercased()
            if lower.isEmpty { continue }
            // Trailing summary lines, e.g. "441 records" / "0 BadWords".
            if lower.hasSuffix("records") || lower.hasSuffix("record")
                || lower.hasSuffix("badwords") || lower.hasSuffix("badword") { continue }

            for token in line.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
                let text = String(token)
                if text.hasSuffix(":") { continue }              // header like "Words:"
                if text.allSatisfy(\.isNumber) { continue }       // stray counts
                let entry = text.uppercased()
                if seen.insert(entry).inserted { entries.append(entry) }
            }
        }
        return entries
    }
}
