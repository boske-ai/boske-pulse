import Foundation

public enum HealthRollup {
    /// Roll up check statuses into a single server/overall health.
    public static func overall(from statuses: [CheckStatus]) -> OverallHealth {
        if statuses.contains(.fail) {
            return .down
        }
        if statuses.contains(.warn) {
            return .degraded
        }
        if statuses.isEmpty || statuses.allSatisfy({ $0 == .skipped }) {
            return .unknown
        }
        return .healthy
    }

    public static func serverSnapshot(
        config: ServerConfig,
        endpointChecks: [EndpointCheckResult],
        privateProbes: [PrivateProbeResult],
        coolifyReachable: Bool?,
        containers: [ContainerTile]
    ) -> ServerSnapshot {
        var statuses = endpointChecks.map(\.status) + privateProbes.map(\.status)

        if let coolifyReachable {
            statuses.append(coolifyReachable ? .ok : .fail)
        }

        for container in containers where container.state != "running" {
            statuses.append(.fail)
        }
        for container in containers where container.health == .fail {
            statuses.append(.fail)
        }
        for container in containers where container.health == .warn {
            statuses.append(.warn)
        }

        let running = containers.filter { $0.state == "running" }.count

        return ServerSnapshot(
            id: config.id,
            name: config.name,
            overall: overall(from: statuses),
            coolifyReachable: coolifyReachable,
            containersRunning: running,
            containersTotal: containers.count,
            endpointChecks: endpointChecks,
            privateProbes: privateProbes,
            containers: containers
        )
    }

    public static func production(
        servers: [ServerSnapshot],
        tailscaleConnected: Bool,
        now: Date = Date()
    ) -> ProductionSnapshot {
        let overallStatus = overall(from: servers.map { snapshot in
            switch snapshot.overall {
            case .healthy: return .ok
            case .degraded: return .warn
            case .down: return .fail
            case .unknown: return .skipped
            }
        })

        let smokeSummary: String
        switch overallStatus {
        case .healthy:
            smokeSummary = "PASS: infra smoke OK"
        case .degraded:
            smokeSummary = "WARN: degraded production"
        case .down:
            smokeSummary = "FAIL: production down"
        case .unknown:
            smokeSummary = "UNKNOWN: awaiting probes"
        }

        return ProductionSnapshot(
            overall: overallStatus,
            tailscaleConnected: tailscaleConnected,
            servers: servers,
            lastSync: now,
            smokeSummary: smokeSummary
        )
    }
}
