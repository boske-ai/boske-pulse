import XCTest
@testable import BoskePulseCore

final class AlertDebouncerTests: XCTestCase {
    func testNoAlertWhenHealthy() {
        var debouncer = AlertDebouncer(config: AlertConfig(debounceSeconds: 300, flapIgnoreSeconds: 120, telegramEnabled: true))
        let decision = debouncer.evaluate(overall: .healthy, now: Date())
        XCTAssertFalse(decision.shouldNotify)
    }

    func testFlapIgnorePreventsEarlyAlert() {
        var debouncer = AlertDebouncer(config: AlertConfig(debounceSeconds: 10, flapIgnoreSeconds: 120, telegramEnabled: true))
        let now = Date()
        let decision = debouncer.evaluate(overall: .down, now: now)
        XCTAssertFalse(decision.shouldNotify)
        XCTAssertTrue(decision.reason.contains("flap"))
    }

    func testSustainedDownTriggersAlert() {
        var debouncer = AlertDebouncer(config: AlertConfig(debounceSeconds: 60, flapIgnoreSeconds: 10, telegramEnabled: true))
        let start = Date()
        _ = debouncer.evaluate(overall: .down, now: start)
        let later = start.addingTimeInterval(61)
        let decision = debouncer.evaluate(overall: .down, now: later)
        XCTAssertTrue(decision.shouldNotify)
    }

    func testAcknowledgeSuppressesRepeat() {
        var debouncer = AlertDebouncer(config: AlertConfig(debounceSeconds: 1, flapIgnoreSeconds: 0, telegramEnabled: true))
        let start = Date()
        _ = debouncer.evaluate(overall: .down, now: start)
        let first = debouncer.evaluate(overall: .down, now: start.addingTimeInterval(5))
        XCTAssertTrue(first.shouldNotify)
        debouncer.acknowledge(until: start.addingTimeInterval(3600))
        let second = debouncer.evaluate(overall: .down, now: start.addingTimeInterval(10))
        XCTAssertFalse(second.shouldNotify)
    }
}
