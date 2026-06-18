import XCTest
@testable import BoskePulseCore

final class ConfigLoaderTests: XCTestCase {
    func testDecodesProductionExampleJSON() throws {
        let url = exampleConfigURL()
        let config = try ConfigLoader.load(from: url)
        XCTAssertEqual(config.version, 1)
        XCTAssertTrue(config.discovery.enabled)
        XCTAssertEqual(config.servers.count, 0)
        XCTAssertEqual(config.serverOverlays.count, 6)
        XCTAssertEqual(config.serverOverlays[0].match.coolifyName, "portfolio-sites")
        XCTAssertTrue(config.serverOverlays[0].publicEndpoints.isEmpty)
        let websiteOverlay = config.serverOverlays.first { $0.match.coolifyName == "example-website" }
        XCTAssertEqual(websiteOverlay?.publicEndpoints.count, 1)
        let appOverlay = config.serverOverlays.first { $0.match.coolifyName == "example-app-01" }
        XCTAssertEqual(appOverlay?.match.hetznerName, "examp-app-01")
        XCTAssertEqual(appOverlay?.publicEndpoints.count, 1)
        let dataOverlay = config.serverOverlays.first { $0.match.hetznerName == "example-data-01" }
        XCTAssertEqual(dataOverlay?.privateProbes.count, 1)
    }

    func testDecodesLegacyStaticServersWhenDiscoveryDisabled() throws {
        let url = staticFixtureURL()
        let config = try ConfigLoader.load(from: url)
        XCTAssertFalse(config.discovery.enabled)
        XCTAssertEqual(config.servers.count, 1)
        XCTAssertEqual(config.servers.first?.id, "example-website")
    }

    func testDefaultConfigURLFindsExampleInPackageResources() {
        XCTAssertNotNil(ConfigLoader.defaultConfigURL(bundle: Bundle(for: ConfigLoaderTests.self)))
    }

    func testExampleJSONHasOptionalFieldsOmitted() throws {
        let url = exampleConfigURL()
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let overlays = object?["serverOverlays"] as? [[String: Any]]
        let first = overlays?.first
        XCTAssertFalse(first?.keys.contains("privateProbes") ?? true)
    }

    private func staticFixtureURL() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/boske-production-static.json")
    }

    private func exampleConfigURL() -> URL {
        var directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        return directory.appendingPathComponent("Config/boske-production.example.json")
    }
}
