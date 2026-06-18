import XCTest
@testable import BoskePulseCore

final class ServerDiscoveryTests: XCTestCase {
    func testDiscoversCoolifyServersWithOverlays() {
        let config = discoveryConfig(overlays: [
            ServerOverlay(
                match: ServerMatch(coolifyName: "app-01", hetznerName: "example-app-01"),
                role: "Cloud API",
                publicEndpoints: [
                    EndpointProbe(id: "app", label: "app", url: "https://app.example.dev/api/health", expectStatus: 200)
                ]
            ),
            ServerOverlay(
                match: ServerMatch(coolifyName: "portfolio-sites", hetznerName: "example-website"),
                role: "Websites"
            )
        ], includeUnmatchedHetzner: false)
        let coolify = [
            CoolifyServer(uuid: "c1", name: "app-01", isReachable: true, isUsable: true),
            CoolifyServer(uuid: "c2", name: "portfolio-sites", isReachable: true, isUsable: true)
        ]
        let hetzner = [
            HetznerHostInfo(id: 1, name: "example-app-01", publicIPv4: "203.0.113.10", privateIP: "10.99.0.6", region: "hel1"),
            HetznerHostInfo(id: 2, name: "example-website", publicIPv4: "203.0.113.20", privateIP: "10.99.0.3", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)

        XCTAssertEqual(resolved.count, 2)
        let app = resolved.first { $0.coolifyServerName == "app-01" }
        XCTAssertEqual(app?.role, "Cloud API")
        XCTAssertEqual(app?.publicEndpoints.count, 1)
        XCTAssertEqual(app?.hetznerServerName, "example-app-01")
        XCTAssertEqual(app?.publicIPv4, "203.0.113.10")
        XCTAssertFalse(app?.discoveredOnly ?? true)

        let websites = resolved.first { $0.coolifyServerName == "portfolio-sites" }
        XCTAssertEqual(websites?.hetznerServerName, "example-website")
        XCTAssertEqual(websites?.role, "Websites")
        XCTAssertFalse(websites?.discoveredOnly ?? true)
    }

    func testIncludesUnmatchedHetznerWhenEnabled() {
        let config = discoveryConfig(overlays: [], includeUnmatchedHetzner: true)
        let coolify = [CoolifyServer(uuid: "c1", name: "app-01", isReachable: true, isUsable: true)]
        let hetzner = [
            HetznerHostInfo(id: 1, name: "example-app-01", publicIPv4: "1.2.3.4", privateIP: "10.99.0.6", region: "hel1"),
            HetznerHostInfo(id: 2, name: "example-data-01", publicIPv4: "5.6.7.8", privateIP: "10.99.0.2", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)

        XCTAssertEqual(resolved.count, 2)
        XCTAssertTrue(resolved.contains { $0.hetznerServerName == "example-data-01" })
    }

    func testStaticConfigWhenDiscoveryDisabled() {
        let config = try! ConfigLoader.load(from: staticConfigURL())
        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: [], hetznerHosts: [])

        XCTAssertFalse(config.discovery.enabled)
        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.id, "example-website")
        XCTAssertEqual(resolved.first?.publicEndpoints.count, 1)
    }

    func testResolvedServerIDsAreUnique() {
        let config = discoveryConfig(overlays: [
            ServerOverlay(match: ServerMatch(coolifyName: "app-01", hetznerName: "example-app-01"), role: "API"),
            ServerOverlay(match: ServerMatch(coolifyName: "portfolio-sites", hetznerName: "example-website"), role: "Web")
        ], includeUnmatchedHetzner: true)
        let coolify = [
            CoolifyServer(uuid: "shared", name: "app-01", isReachable: true, isUsable: true),
            CoolifyServer(uuid: "shared", name: "portfolio-sites", isReachable: true, isUsable: true)
        ]
        let hetzner = [
            HetznerHostInfo(id: 1, name: "example-app-01", publicIPv4: "1.1.1.1", privateIP: "10.99.0.6", region: "hel1"),
            HetznerHostInfo(id: 2, name: "example-website", publicIPv4: "2.2.2.2", privateIP: "10.99.0.3", region: "hel1"),
            HetznerHostInfo(id: 3, name: "example-data-01", publicIPv4: "3.3.3.3", privateIP: "10.99.0.2", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)
        let ids = resolved.map(\.id)

        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertTrue(ids.allSatisfy { $0.contains(":") })
    }

    func testNamesMatchUsesTokenBoundaries() {
        XCTAssertTrue(ServerDiscovery.namesMatch("example-app-01", "app-01"))
        XCTAssertTrue(ServerDiscovery.namesMatch("examp-app-01", "example-app-01"))
        XCTAssertFalse(ServerDiscovery.namesMatch("example-search-01", "boske"))
        XCTAssertFalse(ServerDiscovery.namesMatch("portfolio-sites", "example-website"))
    }

    func testOverlayDoesNotCrossAssignEndpointsBetweenCoolifyServers() {
        let config = discoveryConfig(overlays: [
            ServerOverlay(
                match: ServerMatch(coolifyName: "portfolio-sites", hetznerName: "example-website"),
                role: "Canopy",
                publicEndpoints: [
                    EndpointProbe(id: "canopy", label: "canopy.example", url: "https://canopy.example/", expectStatus: 200)
                ]
            ),
            ServerOverlay(
                match: ServerMatch(coolifyName: "example-website", hetznerName: "example-website"),
                role: "Boske site"
            )
        ])
        let coolify = [
            CoolifyServer(uuid: "c1", name: "portfolio-sites", isReachable: true, isUsable: true),
            CoolifyServer(uuid: "c2", name: "example-website", isReachable: true, isUsable: true)
        ]
        let hetzner = [
            HetznerHostInfo(id: 1, name: "example-website", publicIPv4: "203.0.113.20", privateIP: "10.99.0.3", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)

        let canopy = resolved.first { $0.coolifyServerName == "portfolio-sites" }
        let website = resolved.first { $0.coolifyServerName == "example-website" }
        XCTAssertEqual(canopy?.publicEndpoints.count, 1)
        XCTAssertEqual(canopy?.publicEndpoints.first?.label, "canopy.example")
        XCTAssertTrue(website?.publicEndpoints.isEmpty ?? false)
    }

    func testBoskaHetznerHostMatchesBoskeAppCoolifyServer() {
        let config = discoveryConfig(overlays: [
            ServerOverlay(
                match: ServerMatch(coolifyName: "example-app-01", hetznerName: "examp-app-01"),
                role: "Cloud API",
                publicEndpoints: [
                    EndpointProbe(id: "app", label: "app", url: "https://app.example.dev/api/health", expectStatus: 200)
                ]
            )
        ], includeUnmatchedHetzner: true)
        let coolify = [CoolifyServer(uuid: "c1", name: "example-app-01", isReachable: true, isUsable: true)]
        let hetzner = [
            HetznerHostInfo(id: 1, name: "examp-app-01", publicIPv4: "203.0.113.10", privateIP: "10.99.0.6", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.name, "example-app-01")
        XCTAssertEqual(resolved.first?.hetznerServerName, "examp-app-01")
        XCTAssertEqual(resolved.first?.publicIPv4, "203.0.113.10")
    }

    func testOverlayMatchesCoolifyHostnamesToHetznerOverlay() {
        let config = discoveryConfig(overlays: [
            ServerOverlay(
                match: ServerMatch(hetznerName: "example-data-01"),
                role: "Data",
                privateProbes: [PrivateProbe(id: "pg", label: "PG", host: "10.99.0.2", port: 5433)]
            )
        ])
        let coolify = [CoolifyServer(uuid: "c1", name: "example-data-01", isReachable: true, isUsable: true)]
        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: [])

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.role, "Data")
        XCTAssertEqual(resolved.first?.privateProbes.count, 1)
    }

    func testOverlayLinksMismatchedCoolifyAndHetznerNames() {
        let config = discoveryConfig(overlays: [
            ServerOverlay(
                match: ServerMatch(coolifyName: "portfolio-sites", hetznerName: "example-website"),
                role: "Websites"
            )
        ])
        let coolify = [CoolifyServer(uuid: "c1", name: "portfolio-sites", isReachable: true, isUsable: true)]
        let hetzner = [
            HetznerHostInfo(id: 1, name: "example-website", publicIPv4: "203.0.113.20", privateIP: "10.99.0.3", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)

        XCTAssertEqual(resolved.count, 1)
        XCTAssertEqual(resolved.first?.hetznerServerName, "example-website")
        XCTAssertEqual(resolved.first?.role, "Websites")
        XCTAssertEqual(resolved.first?.publicIPv4, "203.0.113.20")
    }

    private func discoveryConfig(
        overlays: [ServerOverlay],
        includeUnmatchedHetzner: Bool = true
    ) -> ProductionConfig {
        ProductionConfig(
            version: 1,
            privateNetwork: "example-net",
            privateNetworkCIDR: "10.99.0.0/16",
            appGroupIdentifier: "group.test",
            discovery: DiscoveryConfig(enabled: true, preferCoolify: true, includeUnmatchedHetzner: includeUnmatchedHetzner),
            servers: [],
            serverOverlays: overlays
        )
    }

    func testResolvesUserProductionTopology() {
        let config = try! ConfigLoader.load(from: exampleConfigURL())
        let coolify = [
            "example-app-01", "example-data-01", "example-llm-01", "example-search-01", "example-website", "portfolio-sites"
        ].enumerated().map { index, name in
            CoolifyServer(uuid: "c\(index)", name: name, isReachable: true, isUsable: true)
        }
        let hetzner = [
            HetznerHostInfo(id: 1, name: "examp-app-01", publicIPv4: "1.1.1.1", privateIP: "10.99.0.6", region: "hel1"),
            HetznerHostInfo(id: 2, name: "example-data-01", publicIPv4: "2.2.2.2", privateIP: "10.99.0.2", region: "hel1"),
            HetznerHostInfo(id: 3, name: "example-llm-01", publicIPv4: "3.3.3.3", privateIP: "10.99.0.5", region: "fsn1"),
            HetznerHostInfo(id: 4, name: "example-search-01", publicIPv4: "4.4.4.4", privateIP: "10.99.0.4", region: "nbg1"),
            HetznerHostInfo(id: 5, name: "example-website", publicIPv4: "5.5.5.5", privateIP: "10.99.0.3", region: "hel1")
        ]

        let resolved = ServerDiscovery.resolve(config: config, coolifyServers: coolify, hetznerHosts: hetzner)
        let ids = resolved.map(\.id)

        XCTAssertEqual(resolved.count, 6)
        XCTAssertEqual(ids.count, Set(ids).count)
        XCTAssertFalse(resolved.contains { $0.name == "examp-app-01" })
        let app = resolved.first { $0.name == "example-app-01" }
        XCTAssertEqual(app?.hetznerServerName, "examp-app-01")
    }

    private func exampleConfigURL() -> URL {
        var directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        return directory.appendingPathComponent("Config/boske-production.example.json")
    }

    private func staticConfigURL() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/boske-production-static.json")
    }
}
