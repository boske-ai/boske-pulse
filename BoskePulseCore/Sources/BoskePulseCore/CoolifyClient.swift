import Foundation

public struct ParsedCoolifyStatus: Sendable, Equatable {
    public let baseState: String
    public let healthDetail: String?
    public let health: CheckStatus
}

public struct CoolifyMapper {
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
}

public protocol CoolifyClient: Sendable {
    func listServers() async throws -> [CoolifyServer]
    func listResources(serverUUID: String) async throws -> [CoolifyResource]
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
        try await get(path: "/servers/\(serverUUID)/resources")
    }

    private func get<T: Decodable>(path: String) async throws -> T {
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
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(CoolifyListEnvelope<T>.self, from: data) {
            return envelope.data
        }
        return try decoder.decode(T.self, from: data)
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
