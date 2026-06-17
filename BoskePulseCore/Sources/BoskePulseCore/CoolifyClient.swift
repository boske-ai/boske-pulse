import Foundation

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

public struct CoolifyMapper {
    public static func containers(from resources: [CoolifyResource]) -> [ContainerTile] {
        resources.map { resource in
            let health: CheckStatus
            switch resource.status.lowercased() {
            case "running", "healthy", "started":
                health = .ok
            case "degraded", "starting", "restarting":
                health = .warn
            default:
                health = .fail
            }
            return ContainerTile(
                id: resource.uuid,
                name: resource.name,
                state: resource.status,
                image: resource.type,
                health: health
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
