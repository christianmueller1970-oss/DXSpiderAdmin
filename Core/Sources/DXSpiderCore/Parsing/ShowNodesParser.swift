import Foundation

/// Preliminary, tolerant parser for `show/nodes` output.
///
/// Like ``ShowUsersParser`` this is deliberately forgiving until real fixtures from HB9HJI-2
/// are captured (Konzeptdokument §10). It treats the first callsign-shaped token on each line
/// as a node and makes a best-effort guess at the connection state from common keywords; the
/// raw text is always preserved as a fallback.
public struct ShowNodesParser: Sendable {
    public init() {}

    public struct Result: Sendable, Equatable {
        public let nodes: [ClusterNode]
        public let rawText: String
    }

    public func parse(_ raw: String) -> Result {
        var seen = Set<String>()
        var nodes: [ClusterNode] = []

        for line in raw.split(whereSeparator: \.isNewline) {
            let lower = line.lowercased()
            let connected = (lower.contains("connected") && !lower.contains("disconnected"))
                || lower.contains("online")

            // The first callsign-shaped token on the line is the node itself.
            for token in line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "," }) {
                let candidate = String(token).uppercased()
                guard Callsign.isLikely(candidate) else { continue }
                if !seen.contains(candidate) {
                    seen.insert(candidate)
                    nodes.append(ClusterNode(callsign: candidate, isConnected: connected))
                }
                break
            }
        }

        return Result(nodes: nodes, rawText: raw)
    }
}
