import XCTest
@testable import BoskePulseCore

final class ConfigLoaderTests: XCTestCase {
    func testDecodesProductionExampleJSON() throws {
        let url = exampleConfigURL()
        let config = try ConfigLoader.load(from: url)
        XCTAssertEqual(config.version, 1)
        XCTAssertEqual(config.servers.count, 4)
        XCTAssertEqual(config.servers.first?.id, "boske-website")
        XCTAssertEqual(config.servers[1].privateProbes.count, 1)
        XCTAssertEqual(config.servers[0].publicEndpoints.count, 2)
        XCTAssertEqual(config.servers[2].publicEndpoints.count, 1)
    }

    func testExampleJSONHasOptionalFieldsOmitted() throws {
        let url = exampleConfigURL()
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let servers = object?["servers"] as? [[String: Any]]
        XCTAssertFalse(servers?.first?.keys.contains("privateProbes") ?? true)
    }

    private func exampleConfigURL() -> URL {
        var directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        return directory.appendingPathComponent("Config/boske-production.example.json")
    }
}
