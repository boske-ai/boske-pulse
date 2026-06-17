import Foundation

/// Decides when to fire macOS / Telegram alerts (debounce + flap suppression).
public struct AlertDebouncer: Sendable {
    public struct Decision: Equatable, Sendable {
        public let shouldNotify: Bool
        public let reason: String
    }

    private let debounceSeconds: TimeInterval
    private let flapIgnoreSeconds: TimeInterval
    private var lastOverall: OverallHealth?
    private var unhealthySince: Date?
    private var lastNotifiedAt: Date?

    public init(config: AlertConfig) {
        self.debounceSeconds = TimeInterval(config.debounceSeconds)
        self.flapIgnoreSeconds = TimeInterval(config.flapIgnoreSeconds)
    }

    public mutating func evaluate(
        overall: OverallHealth,
        now: Date = Date()
    ) -> Decision {
        defer { lastOverall = overall }

        guard overall == .degraded || overall == .down else {
            unhealthySince = nil
            return Decision(shouldNotify: false, reason: "healthy — no alert")
        }

        if lastOverall != overall {
            unhealthySince = now
        }
        unhealthySince = unhealthySince ?? now

        let unhealthyDuration = now.timeIntervalSince(unhealthySince!)
        if unhealthyDuration < flapIgnoreSeconds {
            return Decision(
                shouldNotify: false,
                reason: "flap ignore (\(Int(unhealthyDuration))s < \(Int(flapIgnoreSeconds))s)"
            )
        }

        if unhealthyDuration < debounceSeconds {
            return Decision(
                shouldNotify: false,
                reason: "debounce (\(Int(unhealthyDuration))s < \(Int(debounceSeconds))s)"
            )
        }

        if let lastNotifiedAt, now.timeIntervalSince(lastNotifiedAt) < debounceSeconds {
            return Decision(shouldNotify: false, reason: "already notified recently")
        }

        lastNotifiedAt = now
        return Decision(shouldNotify: true, reason: "sustained \(overall.rawValue)")
    }

    public mutating func acknowledge(until: Date) {
        lastNotifiedAt = until
    }
}
