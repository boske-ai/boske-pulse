import Foundation

public struct DiscoveryConfig: Codable, Sendable, Equatable {
    public let enabled: Bool
    /// When true, list Coolify servers first and enrich with Hetzner. When false, Hetzner-only list.
    public let preferCoolify: Bool
    /// Include Hetzner boxes not registered in Coolify.
    public let includeUnmatchedHetzner: Bool

    public init(
        enabled: Bool = false,
        preferCoolify: Bool = true,
        includeUnmatchedHetzner: Bool = true
    ) {
        self.enabled = enabled
        self.preferCoolify = preferCoolify
        self.includeUnmatchedHetzner = includeUnmatchedHetzner
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        preferCoolify = try container.decodeIfPresent(Bool.self, forKey: .preferCoolify) ?? true
        includeUnmatchedHetzner = try container.decodeIfPresent(Bool.self, forKey: .includeUnmatchedHetzner) ?? true
    }

    public static let auto = DiscoveryConfig(enabled: true, preferCoolify: true, includeUnmatchedHetzner: true)

    enum CodingKeys: String, CodingKey {
        case enabled, preferCoolify, includeUnmatchedHetzner
    }
}

public struct ServerMatch: Codable, Sendable, Equatable {
    public let coolifyName: String?
    public let hetznerName: String?

    public init(coolifyName: String? = nil, hetznerName: String? = nil) {
        self.coolifyName = coolifyName
        self.hetznerName = hetznerName
    }
}

/// Optional health/metadata overlay matched onto discovered hosts.
public struct ServerOverlay: Codable, Sendable, Equatable, Identifiable {
    public let match: ServerMatch
    public let role: String?
    public let publicEndpoints: [EndpointProbe]
    public let privateProbes: [PrivateProbe]
    public let manualStack: [ManualStackService]

    public var id: String {
        match.coolifyName ?? match.hetznerName ?? "overlay"
    }

    public init(
        match: ServerMatch,
        role: String? = nil,
        publicEndpoints: [EndpointProbe] = [],
        privateProbes: [PrivateProbe] = [],
        manualStack: [ManualStackService] = []
    ) {
        self.match = match
        self.role = role
        self.publicEndpoints = publicEndpoints
        self.privateProbes = privateProbes
        self.manualStack = manualStack
    }

    enum CodingKeys: String, CodingKey {
        case match, role, publicEndpoints, privateProbes, manualStack
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        match = try container.decode(ServerMatch.self, forKey: .match)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        publicEndpoints = try container.decodeIfPresent([EndpointProbe].self, forKey: .publicEndpoints) ?? []
        privateProbes = try container.decodeIfPresent([PrivateProbe].self, forKey: .privateProbes) ?? []
        manualStack = try container.decodeIfPresent([ManualStackService].self, forKey: .manualStack) ?? []
    }
}

public struct HetznerHostInfo: Sendable, Equatable, Identifiable {
    public let id: Int
    public let name: String
    public let publicIPv4: String?
    public let privateIP: String?
    public let region: String?

    public init(id: Int, name: String, publicIPv4: String?, privateIP: String?, region: String?) {
        self.id = id
        self.name = name
        self.publicIPv4 = publicIPv4
        self.privateIP = privateIP
        self.region = region
    }
}

/// Runtime host row used by PulseEngine (static config or discovered).
public struct ResolvedServer: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let role: String
    public let hetznerServerName: String?
    public let coolifyUUID: String?
    public let coolifyServerName: String?
    public let publicIPv4: String
    public let privateIP: String
    public let region: String
    public let coolifyManaged: Bool
    public let publicEndpoints: [EndpointProbe]
    public let privateProbes: [PrivateProbe]
    public let manualStack: [ManualStackService]
    public let links: ServerLinks
    public let discoveredOnly: Bool

    public func asServerConfig() -> ServerConfig {
        ServerConfig(
            id: id,
            name: name,
            role: role,
            hetznerServerName: hetznerServerName ?? name,
            publicIPv4: publicIPv4,
            privateIP: privateIP,
            region: region,
            coolifyManaged: coolifyManaged,
            publicEndpoints: publicEndpoints,
            privateProbes: privateProbes,
            links: links
        )
    }

    public var cacheKey: String { id }

    func withID(_ newID: String) -> ResolvedServer {
        ResolvedServer(
            id: newID,
            name: name,
            role: role,
            hetznerServerName: hetznerServerName,
            coolifyUUID: coolifyUUID,
            coolifyServerName: coolifyServerName,
            publicIPv4: publicIPv4,
            privateIP: privateIP,
            region: region,
            coolifyManaged: coolifyManaged,
            publicEndpoints: publicEndpoints,
            privateProbes: privateProbes,
            manualStack: manualStack,
            links: links,
            discoveredOnly: discoveredOnly
        )
    }
}

public enum ServerDiscovery {
    public static func resolve(
        config: ProductionConfig,
        coolifyServers: [CoolifyServer],
        hetznerHosts: [HetznerHostInfo]
    ) -> [ResolvedServer] {
        if config.discovery.enabled {
            return discover(
                coolifyServers: coolifyServers,
                hetznerHosts: hetznerHosts,
                overlays: config.serverOverlays,
                settings: config.discovery
            )
        }
        return config.servers.map { staticServer in
            ResolvedServer(
                id: staticServer.id,
                name: staticServer.name,
                role: staticServer.role,
                hetznerServerName: staticServer.hetznerServerName,
                coolifyUUID: nil,
                coolifyServerName: nil,
                publicIPv4: staticServer.publicIPv4,
                privateIP: staticServer.privateIP,
                region: staticServer.region,
                coolifyManaged: staticServer.coolifyManaged,
                publicEndpoints: staticServer.publicEndpoints,
                privateProbes: staticServer.privateProbes,
                manualStack: [],
                links: staticServer.links,
                discoveredOnly: false
            )
        }
    }

    static func discover(
        coolifyServers: [CoolifyServer],
        hetznerHosts: [HetznerHostInfo],
        overlays: [ServerOverlay],
        settings: DiscoveryConfig
    ) -> [ResolvedServer] {
        var resolved: [ResolvedServer] = []
        var usedHetzner = Set<String>()

        if settings.preferCoolify {
            for coolify in coolifyServers {
                let overlay = matchOverlay(coolifyName: coolify.name, hetznerName: nil, overlays: overlays)
                let hetzner = matchHetzner(
                    forCoolifyName: coolify.name,
                    hetznerAlias: overlay?.match.hetznerName,
                    hosts: hetznerHosts
                )
                if let hetzner { usedHetzner.insert(hetzner.name) }
                resolved.append(makeResolved(coolify: coolify, hetzner: hetzner, overlay: overlay))
            }
        }

        if settings.includeUnmatchedHetzner || !settings.preferCoolify {
            for host in hetznerHosts where !usedHetzner.contains(host.name) {
                if !settings.preferCoolify || settings.includeUnmatchedHetzner {
                    let coolify = matchCoolify(forHetznerName: host.name, servers: coolifyServers)
                    if coolify != nil { continue }
                    let overlay = matchOverlay(coolifyName: nil, hetznerName: host.name, overlays: overlays)
                    resolved.append(makeResolved(coolify: nil, hetzner: host, overlay: overlay))
                }
            }
        }

        if !settings.preferCoolify {
            resolved = hetznerHosts.map { host in
                let coolify = matchCoolify(forHetznerName: host.name, servers: coolifyServers)
                let overlay = matchOverlay(coolifyName: coolify?.name, hetznerName: host.name, overlays: overlays)
                return makeResolved(coolify: coolify, hetzner: host, overlay: overlay)
            }
        }

        return assignUniqueIDs(
            resolved.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        )
    }

    static func assignUniqueIDs(_ servers: [ResolvedServer]) -> [ResolvedServer] {
        var seen = Set<String>()
        return servers.map { server in
            var id = server.id
            var suffix = 2
            while seen.contains(id) {
                id = "\(server.id)#\(suffix)"
                suffix += 1
            }
            seen.insert(id)
            return id == server.id ? server : server.withID(id)
        }
    }

    /// Normalizes known host naming drift (e.g. Hetzner typo `boska-app-01`).
    static func normalizedHostName(_ name: String) -> String {
        name.lowercased().replacingOccurrences(of: "boska-", with: "boske-")
    }

    static func namesMatch(_ a: String, _ b: String) -> Bool {
        let left = normalizedHostName(a)
        let right = normalizedHostName(b)
        if left == right { return true }
        // e.g. boske-app-01 ↔ app-01
        return left.hasSuffix("-\(right)") || right.hasSuffix("-\(left)")
    }

    static func matchHetzner(
        forCoolifyName name: String,
        hetznerAlias: String? = nil,
        hosts: [HetznerHostInfo]
    ) -> HetznerHostInfo? {
        if let hetznerAlias, let exact = hosts.first(where: { $0.name == hetznerAlias }) {
            return exact
        }
        return hosts.first { namesMatch($0.name, name) }
    }

    static func matchCoolify(forHetznerName name: String, servers: [CoolifyServer]) -> CoolifyServer? {
        servers.first { namesMatch($0.name, name) }
    }

    static func matchOverlay(
        coolifyName: String?,
        hetznerName: String?,
        overlays: [ServerOverlay]
    ) -> ServerOverlay? {
        overlays.first { overlay in
            if let coolify = overlay.match.coolifyName, let coolifyName, namesMatch(coolify, coolifyName) {
                return true
            }
            if let hetzner = overlay.match.hetznerName, let hetznerName, namesMatch(hetzner, hetznerName) {
                return true
            }
            // Coolify Cloud often registers servers under Hetzner hostnames — only for hetzner-only overlays.
            if overlay.match.coolifyName == nil,
               let hetzner = overlay.match.hetznerName,
               let coolifyName,
               namesMatch(hetzner, coolifyName)
            {
                return true
            }
            return false
        }
    }

    static func makeResolved(
        coolify: CoolifyServer?,
        hetzner: HetznerHostInfo?,
        overlay: ServerOverlay?
    ) -> ResolvedServer {
        let displayName = coolify?.name ?? hetzner?.name ?? "unknown"
        let hetznerName = hetzner?.name
        let publicIP = hetzner?.publicIPv4 ?? coolify?.ip ?? ""
        let privateIP = hetzner?.privateIP ?? ""
        let region = hetzner?.region ?? ""
        let ssh = publicIP.isEmpty ? "" : "ssh root@\(publicIP)"
        let id: String
        if let coolify {
            id = "coolify:\(coolify.uuid):\(coolify.name)"
        } else if let hetzner {
            id = "hetzner:\(hetzner.id)"
        } else {
            id = "host:\(displayName)"
        }

        return ResolvedServer(
            id: id,
            name: displayName,
            role: overlay?.role ?? (coolify != nil ? "Coolify server" : "Hetzner server"),
            hetznerServerName: hetznerName,
            coolifyUUID: coolify?.uuid,
            coolifyServerName: coolify?.name,
            publicIPv4: publicIP,
            privateIP: privateIP,
            region: region,
            coolifyManaged: coolify != nil,
            publicEndpoints: overlay?.publicEndpoints ?? [],
            privateProbes: overlay?.privateProbes ?? [],
            manualStack: overlay?.manualStack ?? [],
            links: ServerLinks(
                hetzner: "https://console.hetzner.cloud/",
                ssh: ssh.isEmpty ? "ssh root@\(displayName)" : ssh
            ),
            discoveredOnly: overlay == nil
        )
    }
}
