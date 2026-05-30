import Foundation

/// Minimum-spacing rate limiter that keeps the app from flooding the node with commands
/// (Konzeptdokument §2). Used to pace sends rather than drop them.
///
/// A value type with an injectable "now", so its behaviour is deterministic in tests.
public struct RateLimiter: Sendable {
    public let minimumInterval: TimeInterval
    public private(set) var lastEventAt: Date?

    public init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    /// How long the caller should wait before the next event is allowed (0 if allowed now).
    public func retryDelay(at now: Date) -> TimeInterval {
        guard let last = lastEventAt else { return 0 }
        return max(0, minimumInterval - now.timeIntervalSince(last))
    }

    /// Record an event at `now` (call after any wait, when the event actually happens).
    public mutating func record(at now: Date) {
        lastEventAt = now
    }

    /// Convenience: allow-and-record if enough time has passed, otherwise deny without recording.
    @discardableResult
    public mutating func allows(at now: Date) -> Bool {
        guard retryDelay(at: now) == 0 else { return false }
        record(at: now)
        return true
    }
}
