import XCTest
@testable import BoskePulseCore

final class CoolifyMapperTests: XCTestCase {
    func testFlattenDomainsDedupesAndSorts() {
        let domains = CoolifyMapper.flattenDomains([
            CoolifyDomainGroup(ip: "1.2.3.4", domains: ["b.example", "a.example"]),
            CoolifyDomainGroup(ip: "1.2.3.4", domains: ["a.example", "c.example"])
        ])
        XCTAssertEqual(domains, ["a.example", "b.example", "c.example"])
    }

    func testEndpointsFromDomainsUsesHTTPSRoot() {
        let endpoints = CoolifyMapper.endpoints(from: ["app.example.dev"])
        XCTAssertEqual(endpoints.first?.url, "https://app.example.dev/")
        XCTAssertEqual(endpoints.first?.expectStatus, 200)
    }

    func testMapsRunningResourceToOk() {
        let tiles = CoolifyMapper.containers(from: [
            CoolifyResource(uuid: "1", name: "example-website", type: "application", status: "running"),
        ])
        XCTAssertEqual(tiles.first?.health, .ok)
    }

    func testMapsRunningUnknownToOk() {
        let parsed = CoolifyMapper.parseStatus("running:unknown")
        XCTAssertEqual(parsed.baseState, "running")
        XCTAssertEqual(parsed.healthDetail, "unknown")
        XCTAssertEqual(parsed.health, .ok)

        let tiles = CoolifyMapper.containers(from: [
            CoolifyResource(uuid: "1", name: "site", type: "application", status: "running:unknown")
        ])
        XCTAssertEqual(tiles.first?.health, .ok)
        XCTAssertEqual(tiles.first?.uncertainHealth, true)
    }

    func testMapsDegradedUnhealthyToWarn() {
        let parsed = CoolifyMapper.parseStatus("degraded:unhealthy")
        XCTAssertEqual(parsed.health, .warn)
    }

    func testMapsApplicationRunningUnknownToOk() {
        let parsed = CoolifyMapper.parseStatus("application running:unknown")
        XCTAssertEqual(parsed.baseState, "running")
        XCTAssertEqual(parsed.healthDetail, "unknown")
        XCTAssertEqual(parsed.health, .ok)

        let tiles = CoolifyMapper.containers(from: [
            CoolifyResource(uuid: "1", name: "portfolio", type: "application", status: "application running:unknown")
        ])
        XCTAssertEqual(tiles.first?.health, .ok)
        XCTAssertEqual(tiles.first?.uncertainHealth, true)
    }

    func testMapsServiceDegradedToWarn() {
        let parsed = CoolifyMapper.parseStatus("service degraded:unhealthy")
        XCTAssertEqual(parsed.baseState, "degraded")
        XCTAssertEqual(parsed.health, .warn)
    }

    func testMatchServerByName() {
        let match = CoolifyMapper.matchServer(
            configName: "example-llm-01",
            coolifyServers: [CoolifyServer(uuid: "u", name: "example-llm-01", isReachable: true, isUsable: true)]
        )
        XCTAssertEqual(match?.uuid, "u")
    }

    func testMergedResourcesIncludesAliasCoolifyServers() {
        let resourcesByUUID = [
            "primary": [CoolifyResource(uuid: "a", name: "api", type: "application", status: "running")],
            "alias": [
                CoolifyResource(uuid: "b", name: "postgres", type: "standalone-postgresql", status: "running:healthy"),
                CoolifyResource(uuid: "c", name: "redis", type: "standalone-redis", status: "running:healthy")
            ]
        ]
        let coolifyServers = [
            CoolifyServer(uuid: "primary", name: "example-app-01", ip: "203.0.113.10", isReachable: true, isUsable: true),
            CoolifyServer(uuid: "alias", name: "examp-app-01", ip: "203.0.113.10", isReachable: true, isUsable: true)
        ]

        let merged = CoolifyMapper.mergedResources(
            primaryUUID: "primary",
            serverName: "example-app-01",
            publicIPv4: "203.0.113.10",
            coolifyServers: coolifyServers,
            resourcesByUUID: resourcesByUUID
        )

        XCTAssertEqual(merged.map(\.uuid), ["a", "b", "c"])
    }

    func testSupplementalResourcesFiltersByServerDatabaseID() {
        let apps = [
            CoolifyResource(uuid: "1", name: "api", type: "application", status: "running", serverDatabaseID: 7),
            CoolifyResource(uuid: "2", name: "other", type: "application", status: "running", serverDatabaseID: 9)
        ]
        let services = [
            CoolifyResource(uuid: "3", name: "stack", type: "service", status: "running", serverDatabaseID: 7)
        ]

        let matched = CoolifyMapper.supplementalResources(databaseID: 7, applications: apps, services: services)
        XCTAssertEqual(matched.map(\.uuid), ["1", "3"])
    }

    func testManualContainersLinksEndpointHealthToAPI() {
        let tiles = CoolifyMapper.manualContainers(
            from: [
                ManualStackService(name: "example-app-api", role: "api", linkedEndpointID: "app"),
                ManualStackService(name: "example-app-redis", role: "redis")
            ],
            endpointChecks: [
                EndpointCheckResult(id: "app", label: "app.example.dev", status: .ok, latencyMs: 42)
            ]
        )
        XCTAssertEqual(tiles.first?.health, .ok)
        XCTAssertEqual(tiles.first?.state, "running")
        XCTAssertEqual(tiles.last?.health, .skipped)
        XCTAssertEqual(tiles.last?.state, "compose")
    }

    func testMatchCoolifyServerByHetznerIP() {
        let servers = [
            CoolifyServer(uuid: "s", name: "example-search-01", ip: "203.0.113.34", isReachable: true, isUsable: true)
        ]
        let match = CoolifyMapper.matchCoolifyServer(
            hetznerName: "example-search-01",
            publicIPv4: "203.0.113.34",
            coolifyServers: servers
        )
        XCTAssertEqual(match?.uuid, "s")
    }
}

final class CoolifyJSONTests: XCTestCase {
    func testDecodesEnvelopeWrappedResources() throws {
        let json = """
        {"data":[{"uuid":"u1","name":"api","type":"application","status":"running:healthy"}]}
        """
        let resources = CoolifyJSON.decodeResources(from: Data(json.utf8))
        XCTAssertEqual(resources.count, 1)
        XCTAssertEqual(resources.first?.name, "api")
    }

    func testLossyDecodeSkipsInvalidEntriesAndKeepsValidOnes() throws {
        let json = """
        [
          {"uuid":"good","name":"api","type":"application","status":"running"},
          {"name":"missing-uuid"},
          {"uuid":"nullable","name":"db","type":"standalone-postgresql","status":null}
        ]
        """
        let resources = CoolifyJSON.decodeResources(from: Data(json.utf8))
        XCTAssertEqual(resources.count, 2)
        XCTAssertEqual(resources.map(\.uuid), ["good", "nullable"])
        XCTAssertEqual(resources.last?.status, "unknown")
    }

    func testLossyDecodeExtractsServerIDFromDestination() throws {
        let json = """
        [{"uuid":"app","name":"cloud-api","status":"running","destination":{"server_id":42}}]
        """
        let resources = CoolifyJSON.decodeResources(from: Data(json.utf8), defaultType: "application")
        XCTAssertEqual(resources.first?.serverDatabaseID, 42)
    }
}
