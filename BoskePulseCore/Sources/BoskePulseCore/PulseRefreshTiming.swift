import Foundation

public struct OperatorHints: Sendable, Equatable {
    public let messages: [String]

    public init(messages: [String]) {
        self.messages = messages
    }

    public static let none = OperatorHints(messages: [])
}

enum RefreshChannel: Sendable {
    case publicHealth
    case coolify
    case hetzner
    case privateProbes
}

struct PulseSourceCache: Sendable {
    var tailscaleConnected = false
    var endpointChecksByServer: [String: [EndpointCheckResult]] = [:]
    var privateProbesByServer: [String: [PrivateProbeResult]] = [:]
    var coolifyServers: [CoolifyServer] = []
    var containersByServerName: [String: [ContainerTile]] = [:]
    var metricsByServerName: [String: HetznerServerMetrics] = [:]

    var lastPublicRefresh: Date?
    var lastCoolifyRefresh: Date?
    var lastHetznerRefresh: Date?
    var lastPrivateRefresh: Date?
}

enum PulseRefreshTiming {
    static func isDue(
        lastRefresh: Date?,
        intervalSeconds: Int,
        now: Date,
        force: Bool
    ) -> Bool {
        if force { return true }
        guard let lastRefresh else { return true }
        return now.timeIntervalSince(lastRefresh) >= TimeInterval(intervalSeconds)
    }
}
