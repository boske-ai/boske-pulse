import Foundation

public struct HetznerServerMetrics: Sendable, Equatable {
    public let cpuPercent: Double?
    /// Hetzner API has no RAM metric — kept for compatibility, always nil.
    public let ramPercent: Double?
    public let diskMBps: Double?
    public let netInMbps: Double?

    public init(
        cpuPercent: Double? = nil,
        ramPercent: Double? = nil,
        diskMBps: Double? = nil,
        netInMbps: Double? = nil
    ) {
        self.cpuPercent = cpuPercent
        self.ramPercent = ramPercent
        self.diskMBps = diskMBps
        self.netInMbps = netInMbps
    }
}

public protocol HetznerClient: Sendable {
    func metrics(forServerName name: String) async throws -> HetznerServerMetrics
    func metrics(forServerID id: Int) async throws -> HetznerServerMetrics
    func listServerNames() async throws -> [String]
    func listHosts() async throws -> [HetznerHostInfo]
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
        try await listAllServerRows().map(\.name)
    }

    public func listHosts() async throws -> [HetznerHostInfo] {
        let rows = try await listAllServerRows()
        return rows.map { row in
            HetznerHostInfo(
                id: row.id,
                name: row.name,
                publicIPv4: row.publicNet?.ipv4?.ip,
                privateIP: row.privateNet?.first?.ip,
                region: row.datacenter?.location?.name
            )
        }
    }

    public func metrics(forServerName name: String) async throws -> HetznerServerMetrics {
        let rows = try await listAllServerRows()
        guard let server = rows.first(where: { $0.name == name }) else {
            return HetznerServerMetrics()
        }
        return try await metrics(forServerID: server.id)
    }

    public func metrics(forServerID id: Int) async throws -> HetznerServerMetrics {
        let end = Date()
        let start = end.addingTimeInterval(-300)
        guard let url = metricsURL(serverID: id, start: start, end: end) else {
            return HetznerServerMetrics()
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw HetznerError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let metrics = try JSONDecoder().decode(HetznerMetricsResponse.self, from: data)
        return HetznerMetricsParser.parse(metrics)
    }

    private func metricsURL(serverID: Int, start: Date, end: Date) -> URL? {
        var url = projectBase
        url.appendPathComponent("servers")
        url.appendPathComponent(String(serverID))
        url.appendPathComponent("metrics")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "type", value: "cpu,disk,network"),
            URLQueryItem(name: "start", value: formatter.string(from: start)),
            URLQueryItem(name: "end", value: formatter.string(from: end)),
            URLQueryItem(name: "step", value: "60"),
        ]
        return components?.url
    }

    private func listAllServerRows() async throws -> [HetznerServerRow] {
        var all: [HetznerServerRow] = []
        var page = 1
        while true {
            let response: HetznerServersResponse = try await get(path: "servers?page=\(page)&per_page=50")
            all.append(contentsOf: response.servers)
            guard let next = response.meta?.pagination.nextPage, next > page else { break }
            page = next
        }
        return all
    }

    private func get<T: Decodable>(path: String) async throws -> T {
        guard let url = makeURL(path: path) else {
            throw HetznerError.httpStatus(-1)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw HetznerError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func makeURL(path: String) -> URL? {
        var pathPart = path
        var queryPart: String?
        if let queryIndex = path.firstIndex(of: "?") {
            pathPart = String(path[..<queryIndex])
            queryPart = String(path[path.index(after: queryIndex)...])
        }

        var url = projectBase
        for segment in pathPart.split(separator: "/") where !segment.isEmpty {
            url = url.appendingPathComponent(String(segment))
        }

        guard let queryPart else { return url }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.query = queryPart
        return components?.url
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
    let meta: HetznerMeta?
}

private struct HetznerMeta: Decodable {
    let pagination: HetznerPagination
}

private struct HetznerPagination: Decodable {
    let nextPage: Int?

    enum CodingKeys: String, CodingKey {
        case nextPage = "next_page"
    }
}

private struct HetznerServerRow: Decodable {
    let id: Int
    let name: String
    let publicNet: HetznerPublicNet?
    let privateNet: [HetznerPrivateNet]?
    let datacenter: HetznerDatacenter?

    enum CodingKeys: String, CodingKey {
        case id, name, datacenter
        case publicNet = "public_net"
        case privateNet = "private_net"
    }
}

private struct HetznerPublicNet: Decodable {
    let ipv4: HetznerIPv4?
}

private struct HetznerIPv4: Decodable {
    let ip: String?
}

private struct HetznerPrivateNet: Decodable {
    let ip: String?
}

private struct HetznerDatacenter: Decodable {
    let location: HetznerLocation?
}

private struct HetznerLocation: Decodable {
    let name: String
}

private struct HetznerMetricsResponse: Decodable {
    let metrics: HetznerMetricsBlock
}

private struct HetznerMetricsBlock: Decodable {
    let timeSeries: [String: HetznerSeries]

    enum CodingKeys: String, CodingKey {
        case timeSeries = "time_series"
    }
}

private struct HetznerSeries: Decodable {
    let values: [HetznerSample]
}

private struct HetznerSample: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        _ = try HetznerFlexibleNumber(from: &container)
        value = try HetznerFlexibleNumber(from: &container).value
    }
}

private struct HetznerFlexibleNumber: Decodable {
    let value: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
            return
        }
        if let integer = try? container.decode(Int.self) {
            value = Double(integer)
            return
        }
        if let text = try? container.decode(String.self), let parsed = Double(text) {
            value = parsed
            return
        }
        value = 0
    }

    init(from container: inout UnkeyedDecodingContainer) throws {
        if let number = try? container.decode(Double.self) {
            value = number
            return
        }
        if let integer = try? container.decode(Int.self) {
            value = Double(integer)
            return
        }
        if let text = try? container.decode(String.self), let parsed = Double(text) {
            value = parsed
            return
        }
        value = 0
    }
}

enum HetznerMetricsParser {
    fileprivate static func parse(_ response: HetznerMetricsResponse) -> HetznerServerMetrics {
        let series = response.metrics.timeSeries
        let cpuSeries = series["cpu"] ?? series.keys.first(where: { $0.hasPrefix("cpu") }).flatMap { series[$0] }
        let cpuPercent = cpuSeries.flatMap(cpuPercent(from:))

        let diskKey = series.keys.first { $0.contains("disk") && $0.contains("bandwidth") && $0.contains("read") }
        let diskBytesPerSec = diskKey.flatMap { averagedSample(from: series[$0]) }
        let diskMBps = diskBytesPerSec.map { $0 / 1_000_000 }

        let netKey = series.keys.first { $0.contains("network") && $0.contains("bandwidth") && $0.contains("in") }
        let netBytesPerSec = netKey.flatMap { averagedSample(from: series[$0]) }
        let netInMbps = netBytesPerSec.map { ($0 * 8) / 1_000_000 }

        return HetznerServerMetrics(
            cpuPercent: cpuPercent,
            ramPercent: nil,
            diskMBps: diskMBps,
            netInMbps: netInMbps
        )
    }

    private static func cpuPercent(from series: HetznerSeries) -> Double? {
        averagedCPU(from: recentSamples(from: series))
    }

    static func averagedCPU(from samples: [Double]) -> Double? {
        guard !samples.isEmpty else { return nil }
        let avg = samples.reduce(0, +) / Double(samples.count)
        return normalizeCPU(avg)
    }

    static func normalizeCPU(_ raw: Double) -> Double {
        let percent = raw <= 1.0 ? raw * 100 : raw
        return min(max(percent, 0), 100)
    }

    private static func recentSamples(from series: HetznerSeries, count: Int = 3) -> [Double] {
        series.values.suffix(count).map(\.value).filter { $0.isFinite && $0 >= 0 }
    }

    private static func averagedSample(from series: HetznerSeries?, count: Int = 3) -> Double? {
        guard let series else { return nil }
        let samples = recentSamples(from: series, count: count)
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }
}
