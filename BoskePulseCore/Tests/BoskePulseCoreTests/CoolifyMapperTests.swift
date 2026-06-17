import XCTest
@testable import BoskePulseCore

final class CoolifyMapperTests: XCTestCase {
    func testMapsRunningResourceToOk() {
        let tiles = CoolifyMapper.containers(from: [
            CoolifyResource(uuid: "1", name: "example-website", type: "application", status: "running"),
        ])
        XCTAssertEqual(tiles.first?.health, .ok)
    }

    func testMatchServerByName() {
        let match = CoolifyMapper.matchServer(
            configName: "example-llm-01",
            coolifyServers: [CoolifyServer(uuid: "u", name: "example-llm-01", isReachable: true, isUsable: true)]
        )
        XCTAssertEqual(match?.uuid, "u")
    }
}
