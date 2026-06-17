import XCTest
@testable import BoskePulseCore

final class HealthProberTests: XCTestCase {
    func testProbeFailsOnWrongStatus() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 500, body: "err", latencyMs: 10, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(id: "web", label: "boske.dev", url: "https://boske.dev/", expectStatus: 200)
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .fail)
    }

    func testProbeOkWithBodyMatch() async {
        let client = MockHTTPClient(result: HTTPProbeResult(statusCode: 200, body: #"{"ok":true}"#, latencyMs: 50, errorMessage: nil))
        let prober = HealthProber(client: client)
        let endpoint = EndpointProbe(
            id: "llm",
            label: "llm",
            url: "https://llm.boske.dev/healthz",
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
        let endpoint = EndpointProbe(id: "web", label: "boske.dev", url: "https://boske.dev/", expectStatus: 200)
        let result = await prober.probe(endpoint: endpoint)
        XCTAssertEqual(result.status, .warn)
    }
}

private struct MockHTTPClient: HTTPClient {
    let result: HTTPProbeResult

    func get(url: URL, timeoutSeconds: TimeInterval) async throws -> HTTPProbeResult {
        result
    }
}
