import Foundation

/// One read-only info/diagnostics query from the catalogue.
///
/// Every entry was sent once against the live node (HB9HJI-2, DXSpider **v1.55** build 823,
/// 13-Aug-2026) and only the ones that actually answered were kept — see `docs/NodeQueries.md`
/// for the full probe, including the commands that this build does *not* have.
///
/// The catalogue is data, not UI: the info screen renders its picker, argument field and
/// favourites straight from ``NodeQuery/all``, so adding a query is one entry here.
public struct NodeQuery: Identifiable, Hashable, Sendable {
    /// Sidebar-level grouping, used for the picker's sections.
    public enum Group: String, CaseIterable, Identifiable, Sendable {
        case runtime
        case usersNodes
        case config
        case logs
        case operations

        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .runtime: "Laufzeit & System"
            case .usersNodes: "User & Nodes"
            case .config: "Konfiguration"
            case .logs: "Logs & Statistik"
            case .operations: "Betriebsdaten"
            }
        }
    }

    /// What the query expects in the argument field — drives placeholder and validation.
    public enum Argument: Hashable, Sendable {
        /// No argument; the field stays hidden.
        case none
        /// A station callsign (uppercased, checked against ``Callsign/isLikely(_:)``).
        case callsign
        /// A node callsign — same check, different wording.
        case node
        /// A DXCC/callsign prefix such as `HB` or `HB9`.
        case prefix
        /// A Maidenhead locator such as `JN47PN`.
        case locator
        /// A line/record count such as the `5` in `show/dx 5`.
        case count
    }

    public let id: String
    public let title: String
    public let group: Group
    /// The command line without its argument, e.g. `show/log`.
    public let base: String
    public let argument: Argument
    /// Whether the argument must be filled before the query can run.
    public let argumentRequired: Bool
    /// Pre-filled value for the argument field (empty when there is no sensible default).
    public let defaultArgument: String
    /// German one-liner shown under the picker — what the query returns, and any caveat.
    public let note: String

    public init(
        id: String,
        title: String,
        group: Group,
        base: String,
        argument: Argument = .none,
        argumentRequired: Bool = false,
        defaultArgument: String = "",
        note: String
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.base = base
        self.argument = argument
        self.argumentRequired = argumentRequired
        self.defaultArgument = defaultArgument
        self.note = note
    }

    /// The exact line to send, with `raw` normalised for this argument type.
    /// An empty (and optional) argument yields the bare ``base``.
    public func line(argument raw: String) -> String {
        let value = normalize(raw)
        guard !value.isEmpty else { return base }
        return "\(base) \(value)"
    }

    /// Whether `raw` is acceptable for this query — an empty value passes unless required.
    public func isValid(argument raw: String) -> Bool {
        if case .none = argument {
            // Stray text for an argument-less query is ignored rather than rejected.
            return true
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return !argumentRequired }
        let value = normalize(raw)
        // Something was typed but nothing usable survived normalising (e.g. "abc" for a
        // count) — reject it instead of silently sending the bare command.
        guard !value.isEmpty else { return false }
        switch argument {
        case .none:
            return true
        case .callsign, .node:
            return Callsign.isLikely(value)
        case .prefix:
            return value.count <= 8 && value.allSatisfy { $0.isLetter || $0.isNumber || $0 == "/" }
        case .locator:
            return Self.isLikelyLocator(value)
        case .count:
            guard let number = Int(value) else { return false }
            return number > 0 && number <= 9999
        }
    }

    /// Placeholder for the argument field (empty when the query takes none).
    public var placeholder: String {
        switch argument {
        case .none: ""
        case .callsign: argumentRequired ? "Rufzeichen" : "Rufzeichen (optional)"
        case .node: argumentRequired ? "Node-Rufzeichen" : "Node-Rufzeichen (optional)"
        case .prefix: argumentRequired ? "Präfix, z. B. HB9" : "Präfix (optional)"
        case .locator: argumentRequired ? "Locator, z. B. JN47PN" : "Locator (optional)"
        case .count: "Anzahl"
        }
    }

    /// Trim and canonicalise a typed argument for this query's type.
    private func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        switch argument {
        case .none: return ""
        case .count: return trimmed.filter(\.isNumber)
        case .callsign, .node, .prefix, .locator: return trimmed.uppercased()
        }
    }

    /// Maidenhead check: two letters, two digits, optionally two more letters (`JN47`, `JN47PN`).
    static func isLikelyLocator(_ value: String) -> Bool {
        let chars = Array(value.uppercased())
        guard chars.count == 4 || chars.count == 6 else { return false }
        guard chars[0].isLetter, chars[1].isLetter, chars[2].isNumber, chars[3].isNumber else { return false }
        if chars.count == 6 { return chars[4].isLetter && chars[5].isLetter }
        return true
    }
}

// MARK: - The verified catalogue

extension NodeQuery {
    /// Every query the live node answered, in display order.
    public static let all: [NodeQuery] = runtimeQueries + userNodeQueries + configQueries
        + logQueries + operationQueries

    /// Queries shown as one-click buttons above the picker.
    public static let favouriteIDs = ["show/cluster", "show/connect", "show/log", "show/dx", "show/node"]

    public static var favourites: [NodeQuery] {
        favouriteIDs.compactMap { id in all.first { $0.id == id } }
    }

    public static func query(id: String) -> NodeQuery? {
        all.first { $0.id == id }
    }

    public static func queries(in group: Group) -> [NodeQuery] {
        all.filter { $0.group == group }
    }

    /// The three queries the status tiles are assembled from (see ``NodeStatusParser``).
    public static let clusterStatus = NodeQuery(
        id: "show/cluster", title: "Cluster-Status & Uptime", group: .runtime,
        base: "show/cluster",
        note: "Verbundene Nodes und User, Tageshöchstwerte und Laufzeit des Node.")
    public static let softwareVersion = NodeQuery(
        id: "show/version", title: "Software-Version", group: .runtime,
        base: "show/version",
        note: "DXSpider-Version, Build und Perl. Bei einer Git-Installation stammt die Nummer aus „git describe\" — also letzter Tag plus Commits danach, nicht die installierte Release-Version.")
    public static let nodeTime = NodeQuery(
        id: "show/time", title: "Node-Zeit", group: .runtime,
        base: "show/time", argument: .prefix,
        note: "Lokalzeit und UTC des Node; mit Präfix zusätzlich die Ortszeit dort.")

    private static let runtimeQueries: [NodeQuery] = [
        clusterStatus,
        softwareVersion,
        nodeTime,
        NodeQuery(id: "show/motd", title: "Begrüssungstext (MOTD)", group: .runtime,
                  base: "show/motd",
                  note: "Der Text, den jeder User beim Verbinden sieht."),
        NodeQuery(id: "show/connect", title: "Offene Verbindungen", group: .runtime,
                  base: "show/connect",
                  note: "Alle Kanäle mit IP, Port, Richtung und Typ — der Node ignoriert hier ein Rufzeichen."),
        NodeQuery(id: "stat/channel", title: "Kanal-Details (eigener Zugang)", group: .runtime,
                  base: "stat/channel",
                  note: "Sehr ausführlicher Dump des eigenen Console-Kanals inkl. DXUser-Datensatz."),
        NodeQuery(id: "show/program", title: "Geladene Perl-Module", group: .runtime,
                  base: "show/program",
                  note: "Pfade aller geladenen Module — nützlich, um Patches zu verorten."),
        NodeQuery(id: "show/debug", title: "Debug-Level", group: .runtime,
                  base: "show/debug",
                  note: "Welche Debug-Kanäle im Log mitgeschrieben werden."),
        NodeQuery(id: "stat/msg", title: "Message-Queue", group: .runtime,
                  base: "stat/msg",
                  note: "Work- und Busy-Queue des Node; im Normalbetrieb leer."),
    ]

    private static let userNodeQueries: [NodeQuery] = [
        NodeQuery(id: "stat/user", title: "User-Datensatz (komplett)", group: .usersNodes,
                  base: "stat/user", argument: .callsign, argumentRequired: true,
                  note: "Alle DB-Felder: Name, QTH, Locator, Priv, Homenode, letzte Verbindungen."),
        NodeQuery(id: "show/station", title: "User-Kurzprofil", group: .usersNodes,
                  base: "show/station", argument: .callsign, argumentRequired: true,
                  note: "Kompakte Sicht: Name, QTH, Locator, letzte Verbindung, Homenode."),
        NodeQuery(id: "stat/route_user", title: "Routing-Eintrag (User)", group: .usersNodes,
                  base: "stat/route_user", argument: .callsign, argumentRequired: true,
                  note: "Über welchen Parent-Node der User erreicht wird, samt IP und Zonen."),
        NodeQuery(id: "stat/route_node", title: "Routing-Eintrag (Node)", group: .usersNodes,
                  base: "stat/route_node", argument: .node, argumentRequired: true,
                  note: "Nachbarn, Obscount und der letzte PC92C-Frame dieses Node."),
        NodeQuery(id: "show/node", title: "Nodes mit Version", group: .usersNodes,
                  base: "show/node",
                  note: "Bekannte Nodes mit Sort und DXSpider-Build — kompakter als show/configuration."),
        NodeQuery(id: "show/isolate", title: "Isolierte Nodes", group: .usersNodes,
                  base: "show/isolate",
                  note: "Nodes, die vom Routing abgekoppelt sind; normalerweise „0 records“."),
        NodeQuery(id: "show/hops", title: "Hop-Count", group: .usersNodes,
                  base: "show/hops", argument: .node, argumentRequired: true,
                  note: "Wie weit Spots zu diesem Node weitergereicht werden."),
        NodeQuery(id: "ping", title: "Laufzeit zum Nachbarnode", group: .usersNodes,
                  base: "ping", argument: .node, argumentRequired: true,
                  note: "Misst die Antwortzeit zum Nachbarnode — sendet ein Ping-Paket dorthin."),
    ]

    private static let configQueries: [NodeQuery] = [
        NodeQuery(id: "show/configuration", title: "Konfiguration (Nodes & User)", group: .config,
                  base: "show/configuration",
                  note: "Die klassische Sicht: Nodes mit den daran hängenden Usern."),
        NodeQuery(id: "show/configuration/nodes", title: "Konfiguration (nur Nodes)", group: .config,
                  base: "show/configuration/nodes",
                  note: "Nur die Node-Ebene, ohne die User-Listen darunter."),
        NodeQuery(id: "show/newconfiguration", title: "Netz-Baum (gross)", group: .config,
                  base: "show/newconfiguration",
                  note: "Der komplette Cluster als Baum — auf HB9HJI-2 rund 500 Zeilen."),
        NodeQuery(id: "show/filter", title: "Eigene Filter", group: .config,
                  base: "show/filter",
                  note: "Die für den eigenen Zugang gesetzten Spot-Filter."),
    ]

    private static let logQueries: [NodeQuery] = [
        NodeQuery(id: "show/log", title: "Systemlog (letzte Zeilen)", group: .logs,
                  base: "show/log", argument: .count, defaultArgument: "20",
                  note: "Die letzten n Zeilen des Node-Logs — Connects, Befehle, Routing."),
        NodeQuery(id: "show/log-call", title: "Systemlog (nach Rufzeichen)", group: .logs,
                  base: "show/log", argument: .callsign, argumentRequired: true,
                  note: "Alle Logzeilen zu einem Rufzeichen — was hat diese Station getan."),
        NodeQuery(id: "show/dxstats", title: "Spot-Statistik (31 Tage)", group: .logs,
                  base: "show/dxstats",
                  note: "DX-Spots pro Tag über den letzten Monat."),
        NodeQuery(id: "show/hfstats", title: "HF-Statistik pro Band", group: .logs,
                  base: "show/hfstats",
                  note: "Spots pro Tag und HF-Band, 160 m bis 10 m."),
        NodeQuery(id: "show/vhfstats", title: "VHF+-Statistik pro Band", group: .logs,
                  base: "show/vhfstats",
                  note: "Spots pro Tag von 6 m bis 12 mm."),
        NodeQuery(id: "show/hftable", title: "Top-Spotter HF", group: .logs,
                  base: "show/hftable",
                  note: "Rangliste der aktivsten HF-Spotter im eigenen DXCC."),
        NodeQuery(id: "show/vhftable", title: "Top-Spotter VHF+", group: .logs,
                  base: "show/vhftable",
                  note: "Rangliste der aktivsten VHF+-Spotter im eigenen DXCC."),
    ]

    private static let operationQueries: [NodeQuery] = [
        NodeQuery(id: "show/dx", title: "Letzte Spots", group: .operations,
                  base: "show/dx", argument: .count, defaultArgument: "20",
                  note: "Die letzten n DX-Spots, wie sie im Cluster ankamen."),
        NodeQuery(id: "show/announce", title: "Letzte Announcements", group: .operations,
                  base: "show/announce", argument: .count, defaultArgument: "10",
                  note: "Die letzten Ansagen anderer Nodes und Stationen."),
        NodeQuery(id: "show/chat", title: "Chat-Verkehr", group: .operations,
                  base: "show/chat", argument: .count, defaultArgument: "10",
                  note: "Die letzten Chat-Zeilen in den Gruppen."),
        NodeQuery(id: "show/wwv", title: "WWV-Daten", group: .operations,
                  base: "show/wwv", argument: .count, defaultArgument: "5",
                  note: "SFI, A- und K-Index samt Sturmprognose."),
        NodeQuery(id: "show/wcy", title: "WCY-Daten", group: .operations,
                  base: "show/wcy", argument: .count, defaultArgument: "5",
                  note: "Wie WWV, zusätzlich mit Aurora- und GMF-Angabe."),
        NodeQuery(id: "show/muf", title: "MUF-Vorhersage", group: .operations,
                  base: "show/muf", argument: .prefix, argumentRequired: true, defaultArgument: "HB9",
                  note: "Nutzbare Frequenzen und Signalstärken zum Zielgebiet."),
        NodeQuery(id: "show/dxcc", title: "Spots eines DXCC", group: .operations,
                  base: "show/dxcc", argument: .prefix, argumentRequired: true, defaultArgument: "HB",
                  note: "Die letzten Spots für alle Rufzeichen dieses Landes."),
        NodeQuery(id: "show/prefix", title: "Präfix-Auskunft", group: .operations,
                  base: "show/prefix", argument: .callsign, argumentRequired: true,
                  note: "Land, CQ- und ITU-Zone sowie Locator zu einem Rufzeichen."),
        NodeQuery(id: "show/qra", title: "Locator-Rechner", group: .operations,
                  base: "show/qra", argument: .locator, argumentRequired: true, defaultArgument: "JN47PN",
                  note: "Entfernung und Richtung vom eigenen Standort zum Locator."),
        NodeQuery(id: "show/sun", title: "Sonnenauf-/-untergang", group: .operations,
                  base: "show/sun", argument: .callsign, argumentRequired: true,
                  note: "Auf- und Untergang samt Azimut und Elevation für den Standort."),
        NodeQuery(id: "show/moon", title: "Mondauf-/-untergang", group: .operations,
                  base: "show/moon", argument: .callsign, argumentRequired: true,
                  note: "Mondzeiten, Azimut, Elevation und beleuchteter Anteil (EME)."),
    ]
}
