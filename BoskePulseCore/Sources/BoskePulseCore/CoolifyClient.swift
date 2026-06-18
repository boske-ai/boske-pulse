import Foundation

public struct ParsedCoolifyStatus: Sendable, Equatable {
    public let baseState: String
    public let healthDetail: String?
    public let health: CheckStatus
}

public struct CoolifyMapper {
    public static func flattenDomains(_ groups: [CoolifyDomainGroup]) -> [String] {
        Array(Set(groups.flatMap(\.domains))).sorted()
    }

    public static func endpoints(from domains: [String]) -> [EndpointProbe] {
        domains.map { domain in
            EndpointProbe(
                id: "coolify:\(domain)",
                label: domain,
                url: "https://\(domain)/",
                expectStatus: 200
            )
        }
    }

    public static func parseStatus(_ rawStatus: String) -> ParsedCoolifyStatus {
        let normalized = rawStatus.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let parts = normalized.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let baseState = String(parts.first ?? Substring(normalized))
        let healthDetail = parts.count > 1 ? String(parts[1]) : nil

        let health: CheckStatus
        switch baseState {
        case "running", "healthy", "started":
            switch healthDetail {
            case "healthy", nil, "":
                health = .ok
            case "unknown", "starting":
                health = .warn
            case "unhealthy":
                health = .fail
            default:
                health = .warn
            }
        case "degraded", "starting", "restarting":
            health = .warn
        case "stopped", "exited", "dead", "failed", "error":
            health = .fail
        default:
            health = .fail
        }

        return ParsedCoolifyStatus(baseState: baseState, healthDetail: healthDetail, health: health)
    }

    public static func containers(from resources: [CoolifyResource]) -> [ContainerTile] {
        resources.map { resource in
            let parsed = parseStatus(resource.status)
            return ContainerTile(
                id: resource.uuid,
                name: resource.name,
                state: parsed.healthDetail.map { "\(parsed.baseState):\($0)" } ?? parsed.baseState,
                image: resource.type,
                health: parsed.health
            )
        }
    }

    public static func matchServer(
        configName: String,
        coolifyServers: [CoolifyServer]
    ) -> CoolifyServer? {
        coolifyServers.first { $0.name == configName || $0.name.contains(configName) }
    }

    /// Merges resources from alias Coolify server records that point at the same host.
    public static func mergedResources(
        primaryUUID: String,
        serverName: String,
        publicIPv4: String,
        coolifyServers: [CoolifyServer],
        resourcesByUUID: [String: [CoolifyResource]]
    ) -> [CoolifyResource] {
        var merged = resourcesByUUID[primaryUUID] ?? []
        var seen = Set(merged.map(\.uuid))

        for coolify in coolifyServers where coolify.uuid != primaryUUID {
            let sameHost = ServerDiscovery.namesMatch(coolify.name, serverName)
                || (!publicIPv4.isEmpty && coolify.ip == publicIPv4)
            guard sameHost else { continue }
            for resource in resourcesByUUID[coolify.uuid] ?? [] where !seen.contains(resource.uuid) {
                merged.append(resource)
                seen.insert(resource.uuid)
            }
        }

        return merged
    }

    public static func supplementalResources(
        databaseID: Int,
        applications: [CoolifyResource],
        services: [CoolifyResource]
    ) -> [CoolifyResource] {
        let matched = applications.filter { $0.serverDatabaseID == databaseID }
            + services.filter { $0.serverDatabaseID == databaseID }
        var seen = Set<String>()
        return matched.filter { seen.insert($0.uuid).inserted }
    }

    public static func manualContainers(
        from stack: [ManualStackService],
        endpointChecks: [EndpointCheckResult]
    ) -> [ContainerTile] {
        stack.map { service in
            let check = service.linkedEndpointID.flatMap { id in
                endpointChecks.first { $0.id == id }
            }
            let health = check?.status ?? .skipped
            let state: String
            switch health {
            case .ok:
                state = "running"
            case .warn:
                state = "running:degraded"
            case .fail:
                state = "exited"
            case .skipped:
                state = "compose"
            }
            return ContainerTile(
                id: "manual:\(service.name)",
                name: service.name,
                state: state,
                image: service.role ?? "compose",
                health: health
            )
        }
    }
}

public protocol CoolifyClient: Sendable {
    func listServers() async throws -> [CoolifyServer]
    func listResources(serverUUID: String) async throws -> [CoolifyResource]
    func listApplications() async throws -> [CoolifyResource]
    func listServices() async throws -> [CoolifyResource]
    func listDomains(serverUUID: String) async throws -> [CoolifyDomainGroup]
}

public struct LiveCoolifyClient: CoolifyClient {
    private let baseURL: URL
    private let token: String
    private let session: URLSession

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
    }

    public func listServers() async throws -> [CoolifyServer] {
        try await get(path: "/servers")
    }

    public func listResources(serverUUID: String) async throws -> [CoolifyResource] {
        let data = try await fetchData(path: "/servers/\(serverUUID)/resources")
        return CoolifyJSON.decodeResources(from: data)
    }

    public func listApplications() async throws -> [CoolifyResource] {
        let data = try await fetchData(path: "/applications")
        return CoolifyJSON.decodeResources(from: data, defaultType: "application")
    }

    public func listServices() async throws -> [CoolifyResource] {
        let data = try await fetchData(path: "/services")
        return CoolifyJSON.decodeResources(from: data, defaultType: "service")
    }

    public func listDomains(serverUUID: String) async throws -> [CoolifyDomainGroup] {
        try await get(path: "/servers/\(serverUUID)/domains")
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let data = try await fetchData(path: path)
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(CoolifyListEnvelope<T>.self, from: data) {
            return envelope.data
        }
        return try decoder.decode(T.self, from: data)
    }

    private func fetchData(path: String) async throws -> Data {
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appendingPathComponent(trimmed)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw CoolifyError.httpStatus(code)
        }
        return data
    }
}

enum CoolifyJSON {
    static func decodeResources(from data: Data, defaultType: String = "resource") -> [CoolifyResource] {
        if let json = try? JSONSerialization.jsonObject(with: data), containsResourceArray(json) {
            return decodeResourcesLossy(from: data, defaultType: defaultType)
        }

        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(CoolifyListEnvelope<[CoolifyResource]>.self, from: data) {
            return envelope.data
        }
        if let resources = try? decoder.decode([CoolifyResource].self, from: data) {
            return resources
        }
        return decodeResourcesLossy(from: data, defaultType: defaultType)
    }

    private static func containsResourceArray(_ json: Any) -> Bool {
        if json is [[String: Any]] { return true }
        if let object = json as? [String: Any], object["data"] is [[String: Any]] { return true }
        return false
    }

    private static func decodeResourcesLossy(from data: Data, defaultType: String) -> [CoolifyResource] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let items: [[String: Any]]
        switch json {
        case let array as [[String: Any]]:
            items = array
        case let object as [String: Any]:
            if let array = object["data"] as? [[String: Any]] {
                items = array
            } else {
                return []
            }
        default:
            return []
        }

        var resources: [CoolifyResource] = []
        for item in items {
            guard let uuid = item["uuid"] as? String else { continue }
            let name = item["name"] as? String ?? "unknown"
            let type = item["type"] as? String
                ?? item["build_pack"] as? String
                ?? item["service_type"] as? String
                ?? defaultType
            let status = item["status"] as? String ?? "unknown"
            let serverDatabaseID = serverDatabaseID(from: item)
            resources.append(
                CoolifyResource(
                    uuid: uuid,
                    name: name,
                    type: type,
                    status: status,
                    serverDatabaseID: serverDatabaseID
                )
            )
        }
        return resources
    }

    private static func serverDatabaseID(from item: [String: Any]) -> Int? {
        if let id = item["server_id"] as? Int { return id }
        if let destination = item["destination"] as? [String: Any] {
            if let id = destination["server_id"] as? Int { return id }
            if let server = destination["server"] as? [String: Any], let id = server["id"] as? Int {
                return id
            }
        }
        return nil
    }
}

private struct CoolifyListEnvelope<T: Decodable>: Decodable {
    let data: T
}

public enum CoolifyError: Error, Equatable, LocalizedError {
    case httpStatus(Int)
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "HTTP \(code)"
        case .notConfigured:
            return "Coolify not configured"
        }
    }
}
