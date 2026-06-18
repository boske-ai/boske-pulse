import XCTest
@testable import BoskePulseCore

final class HetznerMetricsParserTests: XCTestCase {
    func testNormalizesFractionalCPU() {
        XCTAssertEqual(HetznerMetricsParser.normalizeCPU(0.42), 42, accuracy: 0.01)
        XCTAssertEqual(HetznerMetricsParser.normalizeCPU(42), 42, accuracy: 0.01)
    }

    func testClampsCPUToPercentRange() {
        XCTAssertEqual(HetznerMetricsParser.normalizeCPU(120), 100, accuracy: 0.01)
        XCTAssertEqual(HetznerMetricsParser.normalizeCPU(-5), 0, accuracy: 0.01)
    }

    func testAveragesRecentCPUSamples() {
        XCTAssertEqual(HetznerMetricsParser.averagedCPU(from: [10, 20, 30]) ?? -1, 20, accuracy: 0.01)
        XCTAssertEqual(HetznerMetricsParser.averagedCPU(from: [0.1, 0.2, 0.3]) ?? -1, 20, accuracy: 0.01)
        XCTAssertNil(HetznerMetricsParser.averagedCPU(from: []))
    }
}
