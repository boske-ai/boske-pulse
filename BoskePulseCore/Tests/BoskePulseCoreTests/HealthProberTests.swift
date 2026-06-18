import XCTest
@testable import BoskePulseCore

final class HealthProberTests: XCTestCase {
    func testProbeFailsOnWrongStatus() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 500, body: "err", latencyMs: 10, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(id: "web", label: "example.dev", url: "https://example.dev/", expectStatus: 200)
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .fail)
    }

    func testProbeOkWithBodyMatch() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 200, body: #"{"ok":true}"#, latencyMs: 50, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(
            id: "llm",
            label: "llm",
            url: "https://llm.example.dev/healthz",
            expectStatus: 200,
            expectBodyContains: "\"ok\":true"
        )
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .ok)
        XCTAssertEqual(result.latencyMs, 50)
    }

    func testProbeWarnWhenSlow() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 200, body: "ok", latencyMs: 2500, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(id: "web", label: "example.dev", url: "https://example.dev/", expectStatus: 200)
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .warn)
    }

    func testProbeAcceptsConfiguredAlternateStatus() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 403, body: "Forbidden", latencyMs: 40, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(
            id: "search",
            label: "search.example.dev",
            url: "https://search.example.dev/",
            expectStatus: 200,
            acceptStatuses: [200, 403]
        )
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .ok)
        XCTAssertEqual(result.httpStatus, 403)
    }

    func testProbe403WithoutAcceptStatusesIsWarnNotFail() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 403, body: "Forbidden", latencyMs: 40, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(id: "web", label: "example.dev", url: "https://example.dev/", expectStatus: 200)
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .warn)
        XCTAssertEqual(result.httpStatus, 403)
    }
}

private struct MockHTTPClient: HTTPClient {
    let result: HTTPProbeResult

    func get(url: URL, timeoutSeconds: TimeInterval) async throws -> HTTPProbeResult {
        result
    }
}
