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
            ServerSnapshot(id: "a", name: "a", overall: .healthy),
            ServerSnapshot(id: "b", name: "b", overall: .down),
        ]
        let snapshot = HealthRollup.production(servers: servers, tailscaleConnected: true)
        XCTAssertEqual(snapshot.overall, .down)
        XCTAssertTrue(snapshot.smokeSummary.contains("FAIL"))
    }

    func testServerSnapshotMarksCoolifyUnreachableAsDown() {
        let config = ServerConfig(
            id: "boske-llm-01",
            name: "boske-llm-01",
            role: "llm",
            hetznerServerName: "boske-llm-01",
            publicIPv4: "1.2.3.4",
            privateIP: "10.0.0.5",
            region: "fsn1",
            coolifyManaged: true,
            links: ServerLinks(hetzner: "https://hetzner.cloud", ssh: "ssh root@1.2.3.4")
        )
        let snapshot = HealthRollup.serverSnapshot(
            config: config,
            endpointChecks: [],
            privateProbes: [],
            coolifyReachable: false,
            containers: []
        )
        XCTAssertEqual(snapshot.overall, .down)
    }
}
