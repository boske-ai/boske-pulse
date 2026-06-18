import XCTest
@testable import BoskePulseCore

final class HetznerMetricsParserTests: XCTestCase {
    func testNormalizesFractionalCPU() {
        XCTAssertEqual(HetznerMetricsParser.normalizeCPU(0.42), 42, accuracy: 0.01)
        XCTAssertEqual(HetznerMetricsParser.normalizeCPU(42), 42, accuracy: 0.01)
    }
}
