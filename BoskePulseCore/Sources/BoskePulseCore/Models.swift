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

/// Declared docker-compose services for hosts not registered as Coolify resources.
public struct ManualStackService: Codable, Sendable, Equatable, Identifiable {
    public let name: String
    public let role: String?
    /// When set, container health follows this public endpoint check id.
    public let linkedEndpointID: String?

    public var id: String { name }

    public init(name: String, role: String? = nil, linkedEndpointID: String? = nil) {
        self.name = name
        self.role = role
        self.linkedEndpointID = linkedEndpointID
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
    public let discovery: DiscoveryConfig
    public let servers: [ServerConfig]
    public let serverOverlays: [ServerOverlay]
    public let coolify: CoolifyConfig
    public let alerts: AlertConfig
    public let polling: PollingConfig

    enum CodingKeys: String, CodingKey {
        case version, privateNetwork, privateNetworkCIDR, appGroupIdentifier
        case discovery, servers, serverOverlays, coolify, alerts, polling
    }

    public init(
        version: Int,
        privateNetwork: String,
        privateNetworkCIDR: String,
        appGroupIdentifier: String,
        discovery: DiscoveryConfig = DiscoveryConfig(),
        servers: [ServerConfig] = [],
        serverOverlays: [ServerOverlay] = [],
        coolify: CoolifyConfig = .default,
        alerts: AlertConfig = .default,
        polling: PollingConfig = .default
    ) {
        self.version = version
        self.privateNetwork = privateNetwork
        self.privateNetworkCIDR = privateNetworkCIDR
        self.appGroupIdentifier = appGroupIdentifier
        self.discovery = discovery
        self.servers = servers
        self.serverOverlays = serverOverlays
        self.coolify = coolify
        self.alerts = alerts
        self.polling = polling
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        privateNetwork = try container.decode(String.self, forKey: .privateNetwork)
        privateNetworkCIDR = try container.decode(String.self, forKey: .privateNetworkCIDR)
        appGroupIdentifier = try container.decode(String.self, forKey: .appGroupIdentifier)
        servers = try container.decodeIfPresent([ServerConfig].self, forKey: .servers) ?? []
        serverOverlays = try container.decodeIfPresent([ServerOverlay].self, forKey: .serverOverlays) ?? []
        var resolvedDiscovery = try container.decodeIfPresent(DiscoveryConfig.self, forKey: .discovery) ?? DiscoveryConfig()
        if servers.isEmpty, !serverOverlays.isEmpty, !resolvedDiscovery.enabled {
            resolvedDiscovery = DiscoveryConfig(enabled: true, preferCoolify: true, includeUnmatchedHetzner: true)
        }
        discovery = resolvedDiscovery
        coolify = try container.decodeIfPresent(CoolifyConfig.self, forKey: .coolify) ?? .default
        alerts = try container.decodeIfPresent(AlertConfig.self, forKey: .alerts) ?? .default
        polling = try container.decodeIfPresent(PollingConfig.self, forKey: .polling) ?? .default
    }
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
    public let coolifyUsable: Bool?
    public let hetznerHostName: String?
    public let region: String?
    public let privateIP: String?
    public let coolifyDomains: [String]
    public let containersRunning: Int
    public let containersTotal: Int
    public let cpuPercent: Double?
    public let ramPercent: Double?
    public let diskMBps: Double?
    public let netInMbps: Double?
    public let endpointChecks: [EndpointCheckResult]
    public let privateProbes: [PrivateProbeResult]
    public let containers: [ContainerTile]

    public init(
        id: String,
        name: String,
        overall: OverallHealth,
        coolifyReachable: Bool? = nil,
        coolifyUsable: Bool? = nil,
        hetznerHostName: String? = nil,
        region: String? = nil,
        privateIP: String? = nil,
        coolifyDomains: [String] = [],
        containersRunning: Int = 0,
        containersTotal: Int = 0,
        cpuPercent: Double? = nil,
        ramPercent: Double? = nil,
        diskMBps: Double? = nil,
        netInMbps: Double? = nil,
        endpointChecks: [EndpointCheckResult] = [],
        privateProbes: [PrivateProbeResult] = [],
        containers: [ContainerTile] = []
    ) {
        self.id = id
        self.name = name
        self.overall = overall
        self.coolifyReachable = coolifyReachable
        self.coolifyUsable = coolifyUsable
        self.hetznerHostName = hetznerHostName
        self.region = region
        self.privateIP = privateIP
        self.coolifyDomains = coolifyDomains
        self.containersRunning = containersRunning
        self.containersTotal = containersTotal
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.diskMBps = diskMBps
        self.netInMbps = netInMbps
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
    public let databaseID: Int?
    public let uuid: String
    public let name: String
    public let ip: String?
    public let description: String?
    public let isReachable: Bool
    public let isUsable: Bool

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case databaseID = "id"
        case uuid
        case name
        case ip
        case description
        case isReachable = "is_reachable"
        case isUsable = "is_usable"
    }

    public init(
        databaseID: Int? = nil,
        uuid: String,
        name: String,
        ip: String? = nil,
        description: String? = nil,
        isReachable: Bool,
        isUsable: Bool
    ) {
        self.databaseID = databaseID
        self.uuid = uuid
        self.name = name
        self.ip = ip
        self.description = description
        self.isReachable = isReachable
        self.isUsable = isUsable
    }
}

public struct CoolifyDomainGroup: Codable, Sendable, Equatable {
    public let ip: String
    public let domains: [String]

    public init(ip: String, domains: [String]) {
        self.ip = ip
        self.domains = domains
    }
}

public struct CoolifyResource: Codable, Sendable, Equatable, Identifiable {
    public let uuid: String
    public let name: String
    public let type: String
    public let status: String
    public let serverDatabaseID: Int?

    public var id: String { uuid }

    enum CodingKeys: String, CodingKey {
        case uuid
        case name
        case type
        case status
        case serverDatabaseID = "server_id"
    }

    public init(
        uuid: String,
        name: String,
        type: String,
        status: String,
        serverDatabaseID: Int? = nil
    ) {
        self.uuid = uuid
        self.name = name
        self.type = type
        self.status = status
        self.serverDatabaseID = serverDatabaseID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard let uuid = try container.decodeIfPresent(String.self, forKey: .uuid) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Coolify resource missing uuid")
            )
        }
        self.uuid = uuid
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "unknown"
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "resource"
        if let statusString = try container.decodeIfPresent(String.self, forKey: .status) {
            status = statusString
        } else {
            status = "unknown"
        }
        serverDatabaseID = try container.decodeIfPresent(Int.self, forKey: .serverDatabaseID)
    }
}
