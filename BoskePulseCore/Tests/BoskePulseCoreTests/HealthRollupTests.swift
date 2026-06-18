import XCTest
@testable import BoskePulseCore

final class HealthRollupTests: XCTestCase {
    func testOverallDownWhenAnyFail() {
        XCTAssertEqual(HealthRollup.overall(from: [.ok, .warn, .fail]), .down)
    }

    func testOverallDegradedWhenWarnOnly() {
        XCTAssertEqual(HealthRollup.overall(from: [.ok, .warn]), .degraded)
    }

    func testOverallHealthyWhenAllOk() {
        XCTAssertEqual(HealthRollup.overall(from: [.ok, .ok]), .healthy)
    }

    func testProductionRollupDownBeatsDegraded() {
        let servers = [
            ServerSnapshot(
                id: "a",
                name: "a",
                overall: .healthy,
                endpointChecks: [
                    EndpointCheckResult(id: "web", label: "boske.dev", status: .ok, httpStatus: 200, latencyMs: 3),
                ]
            ),
            ServerSnapshot(
                id: "b",
                name: "b",
                overall: .down,
                endpointChecks: [
                    EndpointCheckResult(id: "llm", label: "llm.boske.dev", status: .fail, httpStatus: 503),
                ]
            ),
        ]
        let snapshot = HealthRollup.production(servers: servers, tailscaleConnected: true)
        XCTAssertEqual(snapshot.overall, .down)
        XCTAssertTrue(snapshot.smokeSummary.contains("FAIL"))
    }

    func testServerSnapshotMarksCoolifyUnreachableAsDegradedWhenPublicOk() {
        let config = ServerConfig(
            id: "boske-llm-01",
            name: "boske-llm-01",
            role: "llm",
            hetznerServerName: "boske-llm-01",
            publicIPv4: "1.2.3.4",
            privateIP: "10.0.0.5",
            region: "fsn1",
            coolifyManaged: true,
            publicEndpoints: [
                EndpointProbe(id: "llm", label: "llm.boske.dev", url: "https://llm.boske.dev/healthz", expectStatus: 200),
            ],
            links: ServerLinks(hetzner: "https://hetzner.cloud", ssh: "ssh root@1.2.3.4")
        )
        let snapshot = HealthRollup.serverSnapshot(
            config: config,
            endpointChecks: [
                EndpointCheckResult(id: "llm", label: "llm.boske.dev", status: .ok, httpStatus: 200, latencyMs: 10),
            ],
            privateProbes: [],
            coolifyReachable: false,
            containers: []
        )
        XCTAssertEqual(snapshot.overall, .degraded)
    }

    func testServerSnapshotPublicDownBeatsHealthyContainers() {
        let snapshot = HealthRollup.serverSnapshot(
            config: sampleConfig(),
            endpointChecks: [
                EndpointCheckResult(id: "web", label: "boske.dev", status: .fail, httpStatus: 503),
            ],
            privateProbes: [],
            coolifyReachable: true,
            containers: [
                ContainerTile(id: "1", name: "app", state: "running", health: .ok),
            ]
        )
        XCTAssertEqual(snapshot.overall, .down)
    }

    func testProductionSmokePassWhenPublicOkButInfraWarns() {
        let servers = [
            ServerSnapshot(
                id: "website",
                name: "boske-website",
                overall: .degraded,
                endpointChecks: [
                    EndpointCheckResult(id: "web", label: "boske.dev", status: .ok, httpStatus: 200, latencyMs: 3),
                ],
                containers: [
                    ContainerTile(id: "1", name: "boske-website", state: "running:unknown", health: .warn),
                ]
            ),
            ServerSnapshot(
                id: "llm",
                name: "boske-llm-01",
                overall: .healthy,
                endpointChecks: [
                    EndpointCheckResult(id: "llm", label: "llm.boske.dev", status: .ok, httpStatus: 200, latencyMs: 10),
                ]
            ),
        ]
        let snapshot = HealthRollup.production(servers: servers, tailscaleConnected: false)
        XCTAssertEqual(snapshot.overall, .degraded)
        XCTAssertEqual(snapshot.smokeSummary, "PASS: public smoke OK — infra warnings")
    }

    func testRunningUnknownContainerRollsUpHealthy() {
        let snapshot = HealthRollup.serverSnapshot(
            config: sampleConfig(),
            endpointChecks: [
                EndpointCheckResult(id: "web", label: "boske.dev", status: .ok, httpStatus: 200, latencyMs: 3),
            ],
            privateProbes: [],
            coolifyReachable: true,
            containers: [
                ContainerTile(id: "1", name: "boske-website", state: "running:unknown", health: .ok, uncertainHealth: true),
            ]
        )
        XCTAssertEqual(snapshot.overall, .healthy)
    }

    func testInfraOnlyHostIgnoresContainerWarnings() {
        let config = ServerConfig(
            id: "boske-data-01",
            name: "boske-data-01",
            role: "data",
            hetznerServerName: "boske-data-01",
            publicIPv4: "1.2.3.4",
            privateIP: "10.0.0.2",
            region: "hel1",
            coolifyManaged: true,
            publicEndpoints: [],
            links: ServerLinks(hetzner: "https://hetzner.cloud", ssh: "ssh root@1.2.3.4")
        )
        let snapshot = HealthRollup.serverSnapshot(
            config: config,
            endpointChecks: [],
            privateProbes: [],
            coolifyReachable: true,
            containers: [
                ContainerTile(id: "1", name: "licensing-pg", state: "degraded:unhealthy", health: .warn),
            ]
        )
        XCTAssertEqual(snapshot.overall, .healthy)
    }

    private func sampleConfig() -> ServerConfig {
        ServerConfig(
            id: "boske-website",
            name: "boske-website",
            role: "web",
            hetznerServerName: "boske-website",
            publicIPv4: "1.2.3.4",
            privateIP: "10.0.0.3",
            region: "hel1",
            coolifyManaged: true,
            links: ServerLinks(hetzner: "https://hetzner.cloud", ssh: "ssh root@1.2.3.4")
        )
    }
}
