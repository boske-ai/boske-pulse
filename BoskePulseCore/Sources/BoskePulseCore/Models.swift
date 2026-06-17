import Foundation

public enum OverallHealth: String, Codable, Sendable, Equatable {
    case healthy
    case degraded
    case down
    case unknown

    public var sortOrder: Int {
        switch self {
        case .healthy: return 0
        case .unknown: return 1
        case .degraded: return 2
        case .down: return 3
        }
    }
}

public enum CheckStatus: String, Codable, Sendable, Equatable {
    case ok
    case warn
    case fail
    case skipped
}

public struct EndpointProbe: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let url: String
    public let expectStatus: Int
    public let expectBodyContains: String?

    public init(
        id: String,
        label: String,
        url: String,
        expectStatus: Int,
        expectBodyContains: String? = nil
    ) {
        self.id = id
        self.label = label
        self.url = url
        self.expectStatus = expectStatus
        self.expectBodyContains = expectBodyContains
    }
}

public struct PrivateProbe: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let host: String
    public let port: Int

    public init(id: String, label: String, host: String, port: Int) {
        self.id = id
        self.label = label
        self.host = host
        self.port = port
    }
}

public struct ServerLinks: Codable, Sendable, Equatable {
    public let hetzner: String
    public let ssh: String
    public let coolify: String?

    public init(hetzner: String, ssh: String, coolify: String? = nil) {
        self.hetzner = hetzner
        self.ssh = ssh
        self.coolify = coolify
    }
}

public struct ServerConfig: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let role: String
    public let hetznerServerName: String
    public let publicIPv4: String
    public let privateIP: String
    public let region: String
    public let coolifyManaged: Bool
    public let publicEndpoints: [EndpointProbe]
    public let privateProbes: [PrivateProbe]
    public let links: ServerLinks

    public init(
        id: String,
        name: String,
        role: String,
        hetznerServerName: String,
        publicIPv4: String,
        privateIP: String,
        region: String,
        coolifyManaged: Bool,
        publicEndpoints: [EndpointProbe] = [],
        privateProbes: [PrivateProbe] = [],
        links: ServerLinks
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.hetznerServerName = hetznerServerName
        self.publicIPv4 = publicIPv4
        self.privateIP = privateIP
        self.region = region
        self.coolifyManaged = coolifyManaged
        self.publicEndpoints = publicEndpoints
        self.privateProbes = privateProbes
        self.links = links
    }

    enum CodingKeys: String, CodingKey {
        case id, name, role, hetznerServerName, publicIPv4, privateIP, region
        case coolifyManaged, publicEndpoints, privateProbes, links
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(String.self, forKey: .role)
        hetznerServerName = try container.decode(String.self, forKey: .hetznerServerName)
        publicIPv4 = try container.decode(String.self, forKey: .publicIPv4)
        privateIP = try container.decode(String.self, forKey: .privateIP)
        region = try container.decode(String.self, forKey: .region)
        coolifyManaged = try container.decode(Bool.self, forKey: .coolifyManaged)
        publicEndpoints = try container.decodeIfPresent([EndpointProbe].self, forKey: .publicEndpoints) ?? []
        privateProbes = try container.decodeIfPresent([PrivateProbe].self, forKey: .privateProbes) ?? []
        links = try container.decode(ServerLinks.self, forKey: .links)
    }
}

public struct PollingConfig: Codable, Sendable, Equatable {
    public let publicHealthSeconds: Int
    public let coolifySeconds: Int
    public let hetznerSeconds: Int
    public let privateProbeSeconds: Int

    public static let `default` = PollingConfig(
        publicHealthSeconds: 30,
        coolifySeconds: 60,
        hetznerSeconds: 120,
        privateProbeSeconds: 60
    )
}

public struct AlertConfig: Codable, Sendable, Equatable {
    public let debounceSeconds: Int
    public let flapIgnoreSeconds: Int
    public let telegramEnabled: Bool

    public static let `default` = AlertConfig(
        debounceSeconds: 300,
        flapIgnoreSeconds: 120,
        telegramEnabled: true
    )
}

public struct CoolifyConfig: Codable, Sendable, Equatable {
    public let dashboardPath: String
    public let apiPath: String

    public init(dashboardPath: String, apiPath: String) {
        self.dashboardPath = dashboardPath
        self.apiPath = apiPath
    }

    public static let `default` = CoolifyConfig(dashboardPath: "/", apiPath: "/api/v1")

    public func apiBaseURL(host: URL) -> URL {
        URL(string: apiPath, relativeTo: host) ?? host
    }
}

public struct ProductionConfig: Codable, Sendable, Equatable {
    public let version: Int
    public let privateNetwork: String
    public let privateNetworkCIDR: String
    public let appGroupIdentifier: String
    public let servers: [ServerConfig]
    public let coolify: CoolifyConfig
    public let alerts: AlertConfig
    public let polling: PollingConfig
}

public struct EndpointCheckResult: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let status: CheckStatus
    public let httpStatus: Int?
    public let latencyMs: Int?
    public let message: String?

    public init(
        id: String,
        label: String,
        status: CheckStatus,
        httpStatus: Int? = nil,
        latencyMs: Int? = nil,
        message: String? = nil
    ) {
        self.id = id
        self.label = label
        self.status = status
        self.httpStatus = httpStatus
        self.latencyMs = latencyMs
        self.message = message
    }
}

public struct PrivateProbeResult: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let label: String
    public let status: CheckStatus
    public let message: String?

    public init(id: String, label: String, status: CheckStatus, message: String? = nil) {
        self.id = id
        self.label = label
        self.status = status
        self.message = message
    }
}

public struct ContainerTile: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let state: String
    public let image: String?
    public let health: CheckStatus

    public init(id: String, name: String, state: String, image: String? = nil, health: CheckStatus) {
        self.id = id
        self.name = name
        self.state = state
        self.image = image
        self.health = health
    }
}

public struct ServerSnapshot: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let overall: OverallHealth
    public let coolifyReachable: Bool?
    public let containersRunning: Int
    public let containersTotal: Int
    public let cpuPercent: Double?
    public let ramPercent: Double?
    public let endpointChecks: [EndpointCheckResult]
    public let privateProbes: [PrivateProbeResult]
    public let containers: [ContainerTile]

    public init(
        id: String,
        name: String,
        overall: OverallHealth,
        coolifyReachable: Bool? = nil,
        containersRunning: Int = 0,
        containersTotal: Int = 0,
        cpuPercent: Double? = nil,
        ramPercent: Double? = nil,
        endpointChecks: [EndpointCheckResult] = [],
        privateProbes: [PrivateProbeResult] = [],
        containers: [ContainerTile] = []
    ) {
        self.id = id
        self.name = name
        self.overall = overall
        self.coolifyReachable = coolifyReachable
        self.containersRunning = containersRunning
        self.containersTotal = containersTotal
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.endpointChecks = endpointChecks
        self.privateProbes = privateProbes
        self.containers = containers
    }
}

public struct ProductionSnapshot: Codable, Sendable, Equatable {
    public let overall: OverallHealth
    public let tailscaleConnected: Bool
    public let servers: [ServerSnapshot]
    public let lastSync: Date
    public let smokeSummary: String

    public init(
        overall: OverallHealth,
        tailscaleConnected: Bool,
        servers: [ServerSnapshot],
        lastSync: Date,
        smokeSummary: String
    ) {
        self.overall = overall
        self.tailscaleConnected = tailscaleConnected
        self.servers = servers
        self.lastSync = lastSync
        self.smokeSummary = smokeSummary
    }
}

public struct CoolifyServer: Codable, Sendable, Equatable, Identifiable {
    public let uuid: String
    public let name: String
    public let isReachable: Bool
    public let isUsable: Bool

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case isReachable = "is_reachable"
        case isUsable = "is_usable"
    }
}

public struct CoolifyResource: Codable, Sendable, Equatable, Identifiable {
    public let uuid: String
    public let name: String
    public let type: String
    public let status: String

    public var id: String { uuid }
}
