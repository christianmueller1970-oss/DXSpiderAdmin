import Foundation

/// The node's vital signs, assembled from `show/cluster`, `show/version` and `show/time`.
///
/// Every field is optional: the info screen shows a dash for whatever a given build did not
/// report, rather than hiding the whole tile.
public struct NodeStatus: Equatable, Sendable {
    /// Nodes currently connected, and the configured maximum.
    public var nodesConnected: Int?
    public var nodesMax: Int?
    /// Users on this node, and users known across the whole cluster.
    public var usersLocal: Int?
    public var usersCluster: Int?
    /// Day's peak for the same two counters.
    public var peakUsersLocal: Int?
    public var peakUsersCluster: Int?
    /// Uptime as the node prints it, e.g. `8d 22h 19m`.
    public var uptime: String?
    /// DXSpider version (`1.55`), its build number (`823`) and the Perl underneath.
    public var version: String?
    public var build: String?
    public var perlVersion: String?
    /// Node clock: local date/time and the UTC time (`1658Z`).
    public var localTime: String?
    public var utcTime: String?

    public init() {}

    /// Whether nothing at all could be read — used to decide between tiles and a placeholder.
    public var isEmpty: Bool {
        self == NodeStatus()
    }

    /// Compact version label, e.g. `v1.55 (build 823)`.
    public var versionSummary: String? {
        guard let version else { return nil }
        guard let build else { return "v\(version)" }
        return "v\(version) (build \(build))"
    }

    /// Compact user label, e.g. `4 lokal / 5154 im Netz`.
    public var usersSummary: String? {
        guard let usersLocal else { return nil }
        guard let usersCluster else { return "\(usersLocal) lokal" }
        return "\(usersLocal) lokal / \(usersCluster) im Netz"
    }

    /// Compact node label, e.g. `3 von 400`.
    public var nodesSummary: String? {
        guard let nodesConnected else { return nil }
        guard let nodesMax else { return "\(nodesConnected)" }
        return "\(nodesConnected) von \(nodesMax)"
    }
}
