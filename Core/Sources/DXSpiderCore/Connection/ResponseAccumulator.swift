import Foundation

/// Buffers chunks streamed from the node and yields a complete response once the trailing
/// prompt reappears. This lets the connection layer read continuously (Konzeptdokument §4)
/// instead of guessing how long a command takes.
public struct ResponseAccumulator: Sendable {
    private let detector: PromptDetector
    private var buffer = ""

    public init(detector: PromptDetector = PromptDetector()) {
        self.detector = detector
    }

    /// Output read so far that has not yet been delimited into a response.
    public var pending: String { buffer }

    /// Append a freshly read chunk of output.
    public mutating func append(_ chunk: String) {
        buffer.append(chunk)
    }

    /// If the buffer now ends at a prompt, return everything up to (but excluding) that
    /// final prompt line as the completed response and clear the buffer; otherwise `nil`.
    public mutating func takeCompletedResponse() -> String? {
        guard detector.endsAtPrompt(buffer) else { return nil }
        let response = Self.stripTrailingPrompt(from: buffer, using: detector)
        buffer = ""
        return response
    }

    static func stripTrailingPrompt(from text: String, using detector: PromptDetector) -> String {
        var lines = text
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)

        func dropTrailingBlankLines() {
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeLast()
            }
        }

        dropTrailingBlankLines()
        if let last = lines.last, detector.isPromptLine(last) {
            lines.removeLast()
        }
        dropTrailingBlankLines()

        return lines.joined(separator: "\n")
    }
}
