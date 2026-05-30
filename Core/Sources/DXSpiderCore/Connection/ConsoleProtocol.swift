import Foundation

/// One framed message on the DXSpider console socket: `<sort><call>|<text>`
/// (see `docs/NodeProtocol.md`).
public struct ConsoleMessage: Equatable, Sendable {
    public let sort: Character
    public let call: String
    public let text: String

    public init(sort: Character, call: String, text: String) {
        self.sort = sort
        self.call = call
        self.text = text
    }

    /// Display line: command output, banner or prompt — this is what we parse as a response.
    public var isDisplay: Bool { sort == "D" }
    /// Asynchronous broadcast (DX spots, announcements) — a separate feed, not a response.
    public var isBroadcast: Bool { sort == "X" }
    /// End/disconnect marker.
    public var isEnd: Bool { sort == "Z" }
}

/// Helpers for the line-based DXSpider console-socket protocol (`docs/NodeProtocol.md`).
///
/// `console.pl` itself is a Curses TUI; the underlying socket (default `127.0.0.1:27754`)
/// speaks this simple text protocol and grants sysop without a challenge.
public enum ConsoleProtocol {
    /// Attach message, sent once right after connecting.
    public static func attach(call: String, columns: Int = 80) -> String {
        "A\(call)|local width=\(columns) enhanced"
    }

    /// Wrap a command line as an input message.
    public static func input(call: String, line: String) -> String {
        "I\(call)|\(line)"
    }

    /// Parse one received line `<sort><call>|<text>`. Returns `nil` if there is no `|`
    /// separator or no sort character. A single trailing CR is stripped.
    public static func parse(_ line: String) -> ConsoleMessage? {
        var line = line
        if line.hasSuffix("\r") { line.removeLast() }

        guard let bar = line.firstIndex(of: "|"), bar > line.startIndex else { return nil }
        let prefix = line[line.startIndex..<bar]
        guard let sort = prefix.first else { return nil }

        let call = String(prefix.dropFirst())
        let text = String(line[line.index(after: bar)...])
        return ConsoleMessage(sort: sort, call: call, text: text)
    }
}
