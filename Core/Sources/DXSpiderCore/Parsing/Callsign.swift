import Foundation

/// Helpers for amateur-radio callsigns, shared by the tolerant output parsers.
public enum Callsign {
    /// Normalised form: trimmed and upper-cased.
    public static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// Heuristic: a callsign is short, alphanumeric (plus an optional `-SSID`), and contains
    /// at least one letter and one digit. Tolerant by design — see Konzeptdokument §5.
    public static func isLikely(_ token: String) -> Bool {
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
