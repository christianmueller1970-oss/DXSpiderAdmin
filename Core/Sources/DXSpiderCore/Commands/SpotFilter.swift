import Foundation

/// Builds a DXSpider spot-filter rule from structured input, keeping the filter grammar in one
/// tested place.
///
/// PROVISIONAL: the exact `accept/reject/spots` syntax varies by DXSpider version and still has
/// to be verified against HB9HJI-2 (Konzeptdokument §10). This maps the common documented forms;
/// the generated line is always previewed before sending (§2), so a wrong mapping is visible.
public struct SpotFilter: Sendable, Equatable {
    public enum Action: String, CaseIterable, Sendable, Identifiable {
        case accept, reject
        public var id: String { rawValue }
    }

    public enum Band: String, CaseIterable, Sendable, Identifiable {
        case hf, vhf, uhf
        public var id: String { rawValue }
        public var displayName: String { rawValue.uppercased() }
    }

    public var action: Action
    public var slot: Int
    public var bands: [Band]
    public var spotterCalls: [String]
    public var originCalls: [String]

    public init(
        action: Action = .accept,
        slot: Int = 0,
        bands: [Band] = [],
        spotterCalls: [String] = [],
        originCalls: [String] = []
    ) {
        self.action = action
        self.slot = slot
        self.bands = bands
        self.spotterCalls = spotterCalls
        self.originCalls = originCalls
    }

    /// The composed rule string, or `nil` if no criteria were given.
    public var rule: String? {
        let clauses = [bandClause, spotterClause, originClause].compactMap { $0 }
        guard !clauses.isEmpty else { return nil }
        return clauses.joined(separator: " and ")
    }

    /// The full command (`accept/spots` or `reject/spots`), or `nil` if there is no rule.
    public var command: DXCommand? {
        guard let rule else { return nil }
        switch action {
        case .accept: return .acceptSpots(slot: slot, rule: rule)
        case .reject: return .rejectSpots(slot: slot, rule: rule)
        }
    }

    /// Clears the entire slot, regardless of the composed rule.
    public var clearCommand: DXCommand { .clearSpots(slot: slot) }

    private var bandClause: String? {
        guard !bands.isEmpty else { return nil }
        let parts = bands.map { "on \($0.rawValue)" }
        return parts.count == 1 ? parts[0] : "(" + parts.joined(separator: " or ") + ")"
    }
    private var spotterClause: String? {
        guard !spotterCalls.isEmpty else { return nil }
        return "by " + spotterCalls.joined(separator: ",")
    }
    private var originClause: String? {
        guard !originCalls.isEmpty else { return nil }
        return "origin " + originCalls.joined(separator: ",")
    }

    /// Split free text (comma/space/newline separated) into normalised callsign tokens.
    public static func tokens(from text: String) -> [String] {
        text.split(whereSeparator: { $0 == "," || $0 == " " || $0 == "\t" || $0.isNewline })
            .map { Callsign.normalize(String($0)) }
            .filter { !$0.isEmpty }
    }
}
