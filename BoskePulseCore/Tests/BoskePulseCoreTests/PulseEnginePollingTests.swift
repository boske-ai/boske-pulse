import XCTest
@testable import BoskePulseCore

final class PulseRefreshTimingTests: XCTestCase {
    func testIsDueWhenNeverRefreshed() {
        let now = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(PulseRefreshTiming.isDue(lastRefresh: nil, intervalSeconds: 30, now: now, force: false))
    }

    func testIsNotDueBeforeInterval() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(
            PulseRefreshTiming.isDue(lastRefresh: start, intervalSeconds: 60, now: start.addingTimeInterval(30), force: false)
        )
    }

    func testIsDueAfterInterval() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(
            PulseRefreshTiming.isDue(lastRefresh: start, intervalSeconds: 60, now: start.addingTimeInterval(60), force: false)
        )
    }

    func testForceAlwaysDue() {
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(
            PulseRefreshTiming.isDue(lastRefresh: start, intervalSeconds: 120, now: start.addingTimeInterval(1), force: true)
        )
    }
}

final class PulseEnginePollingTests: XCTestCase {
    func testOperatorHintsWhenTailscaleOffline() async {
        let config = try! ConfigLoader.load(from: exampleConfigURL())
        let engine = PulseEngine(
            config: config,
            credentialsStore: InMemoryCredentialsStore(credentials: .empty),
            tailscale: StubTailscaleReachability(connected: false)
        )
        _ = await engine.refresh()
        let hints = await engine.operatorHints
        XCTAssertTrue(hints.messages.contains(where: { $0.contains("private probes paused") }))
    }

    func testCoolifyCloudReachableWithoutTailscale() {
        let cloud = URL(string: "https://app.coolify.io")!
        XCTAssertTrue(PulseEngine.coolifyReachableWithoutTailscale(baseURL: cloud))
        XCTAssertTrue(PulseEngine.canReachCoolify(baseURL: cloud, tailscaleUp: false))
    }

    func testSelfHostedCoolifyNeedsTailscale() {
        let selfHosted = URL(string: "http://100.64.0.1:8000")!
        XCTAssertFalse(PulseEngine.coolifyReachableWithoutTailscale(baseURL: selfHosted))
        XCTAssertFalse(PulseEngine.canReachCoolify(baseURL: selfHosted, tailscaleUp: false))
        XCTAssertTrue(PulseEngine.canReachCoolify(baseURL: selfHosted, tailscaleUp: true))
    }

    private func exampleConfigURL() -> URL {
        var directory = URL(fileURLWithPath: #file).deletingLastPathComponent()
        for _ in 0..<3 {
            directory.deleteLastPathComponent()
        }
        return directory.appendingPathComponent("Config/boske-production.example.json")
    }
}
