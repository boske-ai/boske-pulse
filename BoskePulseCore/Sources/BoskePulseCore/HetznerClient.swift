import Foundation

public struct HetznerServerMetrics: Sendable, Equatable {
    public let cpuPercent: Double?
    public let ramPercent: Double?
}

public protocol HetznerClient: Sendable {
    func metrics(forServerName name: String) async throws -> HetznerServerMetrics
    func listServerNames() async throws -> [String]
}

/// Minimal Hetzner Cloud API client — resolves server by name, reads metrics time series.
public struct LiveHetznerClient: HetznerClient {
    private let token: String
    private let session: URLSession
    private let projectBase = URL(string: "https://api.hetzner.cloud/v1")!

    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    public func listServerNames() async throws -> [String] {
        let servers: HetznerServersResponse = try await get(path: "servers")
        return servers.servers.map(\.name)
    }

    public func metrics(forServerName name: String) async throws -> HetznerServerMetrics {
        let servers: HetznerServersResponse = try await get(path: "servers")
        guard let server = servers.servers.first(where: { $0.name == name }) else {
            return HetznerServerMetrics(cpuPercent: nil, ramPercent: nil)
        }
        let metrics: HetznerMetricsResponse = try await get(path: "servers/\(server.id)/metrics?type=cpu,disk,network")
        let cpu = metrics.metrics.timeSeries.cpu?.values.last?.value
        let ram = metrics.metrics.timeSeries.memory?.values.last?.value
        return HetznerServerMetrics(cpuPercent: cpu, ramPercent: ram)
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        let url = projectBase.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw HetznerError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

public enum HetznerError: Error, Equatable, LocalizedError {
    case httpStatus(Int)
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "HTTP \(code)"
        case .notConfigured:
            return "Hetzner not configured"
        }
    }
}

// MARK: - API response shapes (subset)

private struct HetznerServersResponse: Decodable {
    let servers: [HetznerServerRow]
}

private struct HetznerServerRow: Decodable {
    let id: Int
    let name: String
}

private struct HetznerMetricsResponse: Decodable {
    let metrics: HetznerMetricsBlock
}

private struct HetznerMetricsBlock: Decodable {
    let timeSeries: HetznerTimeSeries
}

private struct HetznerTimeSeries: Decodable {
    let cpu: HetznerSeries?
    let memory: HetznerSeries?
}

private struct HetznerSeries: Decodable {
    let values: [HetznerSample]
}

private struct HetznerSample: Decodable {
    let value: Double
}
