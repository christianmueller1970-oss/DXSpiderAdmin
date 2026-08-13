import Foundation

/// Reads ``NodeStatus`` out of the three status commands.
///
/// Verified against HB9HJI-2 (DXSpider v1.55 build 823):
/// ```
/// Nodes: 3/400 Users [Loc/Clr]: 4/5154 Max: 8/5768 - Uptime:  8d 22h 19m
/// DXSpider v1.55 (build 823 git: mojo/3e9b3621[r]) using perl v5.36.0 on Linux
/// Local Time: 13-Aug-2026 1658, UTC 1658Z
/// ```
/// Each field is matched on its own, so a build that words one line differently only loses
/// that one value instead of the whole status.
public struct NodeStatusParser: Sendable {
    public init() {}

    /// Parse whichever of the three responses are available; empty strings are skipped.
    public func parse(cluster: String = "", version: String = "", time: String = "") -> NodeStatus {
        var status = NodeStatus()

        if let match = cluster.firstMatch(of: #/Nodes:\s*(\d+)\s*/\s*(\d+)/#) {
            status.nodesConnected = Int(match.1)
            status.nodesMax = Int(match.2)
        }
        if let match = cluster.firstMatch(of: #/Users\s*\[Loc/Clr\]:\s*(\d+)\s*/\s*(\d+)/#) {
            status.usersLocal = Int(match.1)
            status.usersCluster = Int(match.2)
        }
        if let match = cluster.firstMatch(of: #/Max:\s*(\d+)\s*/\s*(\d+)/#) {
            status.peakUsersLocal = Int(match.1)
            status.peakUsersCluster = Int(match.2)
        }
        if let match = cluster.firstMatch(of: #/Uptime:\s*(.+?)\s*$/#.anchorsMatchLineEndings()) {
            status.uptime = String(match.1)
        }

        if let match = version.firstMatch(of: #/DXSpider\s+v?([\d.]+)/#) {
            status.version = String(match.1)
        }
        // Beide Schreibweisen: "(build 823 git: …)" hier, "build: 686" bei anderen Nodes.
        if let match = version.firstMatch(of: #/build:?\s*(\d+)/#) {
            status.build = String(match.1)
        }
        if let match = version.firstMatch(of: #/perl\s+v?([\d.]+)/#) {
            status.perlVersion = String(match.1)
        }
        if let match = version.firstMatch(of: #/git:\s*([^)\s]+)/#) {
            status.gitVersion = String(match.1)
        }

        if let match = time.firstMatch(of: #/Local Time:\s*(.+?)\s*,/#) {
            status.localTime = String(match.1)
        }
        if let match = time.firstMatch(of: #/UTC\s*(\d{3,4}Z)/#) {
            status.utcTime = String(match.1)
        }

        return status
    }
}
