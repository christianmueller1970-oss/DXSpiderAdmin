import Foundation

/// Recognises the DXSpider cluster prompt so streamed output can be split into discrete
/// command responses, instead of relying on fixed `sleep`/timeout windows (Konzeptdokument §4).
///
/// DXSpider prints a prompt such as `HB9HJI de HB9HJI-2 30-May-2026 2105Z >` after every
/// response. The exact shape varies by version and node, so detection is deliberately
/// tolerant: the hallmark is a final line that contains ` de ` and ends in `>`.
public struct PromptDetector: Sendable {
    public init() {}

    /// Whether `line` (trailing whitespace ignored) looks like a DXSpider prompt.
    public func isPromptLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(">") else { return false }
        // The DXSpider prompt always carries the "<call> de <node>" signature.
        return trimmed.range(of: " de ", options: .caseInsensitive) != nil
    }

    /// Whether the accumulated `text` currently ends at a prompt — i.e. the node is waiting
    /// for the next command and the preceding response is complete.
    public func endsAtPrompt(_ text: String) -> Bool {
        guard let last = Self.lastNonEmptyLine(of: text) else { return false }
        return isPromptLine(last)
    }

    static func lastNonEmptyLine(of text: String) -> String? {
        var result: String?
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            if !String(line).trimmingCharacters(in: .whitespaces).isEmpty {
                result = String(line)
            }
        }
        return result
    }
}
