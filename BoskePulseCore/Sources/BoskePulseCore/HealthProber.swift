import Foundation

public struct HTTPProbeResult: Sendable, Equatable {
    public let statusCode: Int?
    public let body: String?
    public let latencyMs: Int
    public let errorMessage: String?
}

public protocol HTTPClient: Sendable {
    func get(url: URL, timeoutSeconds: TimeInterval) async throws -> HTTPProbeResult
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get(url: URL, timeoutSeconds: TimeInterval) async throws -> HTTPProbeResult {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = timeoutSeconds
        let started = Date()
        do {
            let (data, response) = try await session.data(for: request)
            let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
            let statusCode = (response as? HTTPURLResponse)?.statusCode
            let body = String(data: data, encoding: .utf8)
            return HTTPProbeResult(statusCode: statusCode, body: body, latencyMs: latencyMs, errorMessage: nil)
        } catch {
            let latencyMs = Int(Date().timeIntervalSince(started) * 1000)
            return HTTPProbeResult(statusCode: nil, body: nil, latencyMs: latencyMs, errorMessage: error.localizedDescription)
        }
    }
}

public struct HealthProber: Sendable {
    private let client: HTTPClient

    public init(client: HTTPClient = URLSessionHTTPClient()) {
        self.client = client
    }

    public func probe(endpoint: EndpointProbe, timeoutSeconds: TimeInterval = 10) async -> EndpointCheckResult {
        guard let url = URL(string: endpoint.url) else {
            return EndpointCheckResult(
                id: endpoint.id,
                label: endpoint.label,
                status: .fail,
                message: "invalid URL"
            )
        }

        let result = try? await client.get(url: url, timeoutSeconds: timeoutSeconds)
        guard let result else {
            return EndpointCheckResult(
                id: endpoint.id,
                label: endpoint.label,
                status: .fail,
                message: "request failed"
            )
        }

        if let errorMessage = result.errorMessage {
            return EndpointCheckResult(
                id: endpoint.id,
                label: endpoint.label,
                status: .fail,
                latencyMs: result.latencyMs,
                message: errorMessage
            )
        }

        guard let statusCode = result.statusCode else {
            return EndpointCheckResult(
                id: endpoint.id,
                label: endpoint.label,
                status: .fail,
                latencyMs: result.latencyMs,
                message: "no HTTP status"
            )
        }

        let accepted = Set(endpoint.resolvedAcceptStatuses)
        if !accepted.contains(statusCode) {
            if (401 ... 403).contains(statusCode), accepted.contains(200) {
                return EndpointCheckResult(
                    id: endpoint.id,
                    label: endpoint.label,
                    status: .warn,
                    httpStatus: statusCode,
                    latencyMs: result.latencyMs,
                    message: "HTTP \(statusCode) — reachable, access restricted"
                )
            }
            return EndpointCheckResult(
                id: endpoint.id,
                label: endpoint.label,
                status: .fail,
                httpStatus: statusCode,
                latencyMs: result.latencyMs,
                message: "expected HTTP \(endpoint.expectStatus)"
            )
        }

        if let expected = endpoint.expectBodyContains {
            guard let body = result.body, body.contains(expected) else {
                return EndpointCheckResult(
                    id: endpoint.id,
                    label: endpoint.label,
                    status: .fail,
                    httpStatus: result.statusCode,
                    latencyMs: result.latencyMs,
                    message: "body missing \(expected)"
                )
            }
        }

        let warn = (result.latencyMs > 2000) ? CheckStatus.warn : CheckStatus.ok
        return EndpointCheckResult(
            id: endpoint.id,
            label: endpoint.label,
            status: warn,
            httpStatus: result.statusCode,
            latencyMs: result.latencyMs
        )
    }
}
