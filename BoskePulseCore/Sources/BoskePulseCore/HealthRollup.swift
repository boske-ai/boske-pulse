import Foundation

public enum HealthRollup {
    /// Roll up check statuses into a single server/overall health.
    public static func overall(from statuses: [CheckStatus]) -> OverallHealth {
        let active = statuses.filter { $0 != .skipped }
        if active.contains(.fail) {
            return .down
        }
        if active.contains(.warn) {
            return .degraded
        }
        if active.isEmpty {
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
        let publicStatuses = endpointChecks.map(\.status)
        let hasPublicChecks = !endpointChecks.isEmpty
        let publicOverall = hasPublicChecks ? overall(from: publicStatuses) : .unknown

        var infraStatuses: [CheckStatus] = []
        for probe in privateProbes where probe.status != .skipped {
            infraStatuses.append(probe.status)
        }
        if let coolifyReachable {
            infraStatuses.append(coolifyReachable ? .ok : .warn)
        }
        infraStatuses += containers.map(\.health).filter { $0 != .skipped }

        // Hosts without public smoke (data, etc.) — infra warnings are notes, not host-down.
        let infraOverall = hasPublicChecks
            ? overall(from: infraStatuses)
            : overallIgnoringInfraWarnings(from: infraStatuses)
        let serverOverall = combineServerHealth(public: publicOverall, infra: infraOverall)

        let running = containers.filter(isContainerRunning).count

        return ServerSnapshot(
            id: config.id,
            name: config.name,
            overall: serverOverall,
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
        let publicOverall = overall(from: servers.flatMap { server in
            server.endpointChecks.map(\.status)
        })
        let serverOverall = overall(from: servers.map { snapshot in
            switch snapshot.overall {
            case .healthy: return .ok
            case .degraded: return .warn
            case .down: return .fail
            case .unknown: return .skipped
            }
        })
        let overallStatus = combineProductionHealth(public: publicOverall, servers: serverOverall)

        let smokeSummary = smokeSummary(
            publicOverall: publicOverall,
            productionOverall: overallStatus,
            tailscaleConnected: tailscaleConnected
        )

        return ProductionSnapshot(
            overall: overallStatus,
            tailscaleConnected: tailscaleConnected,
            servers: servers,
            lastSync: now,
            smokeSummary: smokeSummary
        )
    }

    /// Public smoke is customer-facing; infra issues cap at degraded unless public is down.
    static func combineServerHealth(public publicOverall: OverallHealth, infra infraOverall: OverallHealth) -> OverallHealth {
        if publicOverall == .down {
            return .down
        }
        if infraOverall == .down {
            return .degraded
        }
        if publicOverall == .degraded || infraOverall == .degraded {
            return .degraded
        }
        if publicOverall == .unknown && infraOverall == .unknown {
            return .unknown
        }
        return .healthy
    }

    static func combineProductionHealth(public publicOverall: OverallHealth, servers serverOverall: OverallHealth) -> OverallHealth {
        if publicOverall == .down {
            return .down
        }
        if serverOverall == .down {
            return .degraded
        }
        if publicOverall == .degraded || serverOverall == .degraded {
            return .degraded
        }
        if publicOverall == .unknown && serverOverall == .unknown {
            return .unknown
        }
        return .healthy
    }

    static func smokeSummary(
        publicOverall: OverallHealth,
        productionOverall: OverallHealth,
        tailscaleConnected: Bool
    ) -> String {
        switch publicOverall {
        case .healthy:
            if productionOverall == .healthy {
                return "PASS: public smoke OK"
            }
            return "PASS: public smoke OK — infra warnings"
        case .degraded:
            return "WARN: public smoke degraded"
        case .down:
            return "FAIL: public smoke down"
        case .unknown:
            if productionOverall == .healthy {
                return "PASS: monitored hosts OK"
            }
            if productionOverall == .degraded {
                return "WARN: infra warnings"
            }
            return "UNKNOWN: awaiting public probes"
        }
    }

    /// Infra-only hosts: only hard failures affect overall health.
    static func overallIgnoringInfraWarnings(from statuses: [CheckStatus]) -> OverallHealth {
        let active = statuses.filter { $0 != .skipped }
        if active.contains(.fail) {
            return .down
        }
        if active.isEmpty {
            return .unknown
        }
        return .healthy
    }

    private static func isContainerRunning(_ container: ContainerTile) -> Bool {
        if container.health == .fail { return false }
        let base = parseContainerBaseState(container.state).lowercased()
        if base == "running" || base.contains("running") {
            return true
        }
        return container.state == "compose"
    }

    private static func parseContainerBaseState(_ state: String) -> String {
        state.split(separator: ":", maxSplits: 1).first.map(String.init) ?? state
    }
}
