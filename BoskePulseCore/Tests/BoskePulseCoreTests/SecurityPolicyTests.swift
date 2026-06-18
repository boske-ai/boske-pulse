import XCTest
@testable import BoskePulseCore

final class SecurityPolicyTests: XCTestCase {
    func testRejectsAbsoluteCoolifyAPIPath() {
        XCTAssertFalse(SecurityPolicy.isRelativeAPIPath("https://evil.example/steal"))
        XCTAssertFalse(SecurityPolicy.isRelativeAPIPath("//evil.example/api"))
        XCTAssertTrue(SecurityPolicy.isRelativeAPIPath("/api/v1"))
    }

    func testApiBaseURLIgnoresAbsoluteAPIPath() {
        let host = URL(string: "https://coolify.example")!
        let resolved = SecurityPolicy.apiBaseURL(host: host, apiPath: "https://evil.example/steal")
        XCTAssertEqual(resolved.absoluteString, "https://coolify.example/api/v1")
    }

    func testBlocksMetadataAndLocalhostProbeURLs() {
        XCTAssertEqual(
            SecurityPolicy.probeURLPolicy(for: "http://169.254.169.254/"),
            .block("reserved or metadata address")
        )
        XCTAssertEqual(
            SecurityPolicy.probeURLPolicy(for: "https://localhost/"),
            .block("localhost is not allowed")
        )
    }

    func testAllowsHTTPSPublicProbe() {
        if case .allow = SecurityPolicy.probeURLPolicy(for: "https://example.dev/") {
            // expected
        } else {
            XCTFail("expected allow")
        }
    }

    func testAllowsHTTPOnlyForPrivateHosts() {
        if case .allow = SecurityPolicy.probeURLPolicy(for: "http://10.99.0.2:5433") {
            // expected
        } else {
            XCTFail("expected allow for private HTTP")
        }
        if case .block = SecurityPolicy.probeURLPolicy(for: "http://example.dev/") {
            // expected
        } else {
            XCTFail("expected block for public HTTP")
        }
    }

    func testPrivateProbeHostMustMatchCIDR() {
        XCTAssertTrue(SecurityPolicy.isAllowedPrivateProbeHost("10.99.0.2", allowedCIDR: "10.99.0.0/16"))
        XCTAssertFalse(SecurityPolicy.isAllowedPrivateProbeHost("10.0.0.2", allowedCIDR: "10.99.0.0/16"))
        XCTAssertTrue(SecurityPolicy.isAllowedPrivateProbeHost("100.64.0.1", allowedCIDR: "10.99.0.0/16"))
    }

    func testRejectsShellCharactersInSSHHost() {
        XCTAssertNil(SecurityPolicy.sanitizedSSHHost("1.2.3.4; rm -rf /"))
        XCTAssertEqual(SecurityPolicy.sshCommand(host: "203.0.113.20"), "ssh deploy@203.0.113.20")
    }

    func testRejectsInvalidProbeHostname() {
        XCTAssertFalse(SecurityPolicy.isValidProbeHostname("not a host"))
        XCTAssertFalse(SecurityPolicy.isValidProbeHostname("evil.example/path"))
        XCTAssertTrue(SecurityPolicy.isValidProbeHostname("app.example.dev"))
    }

    func testSanitizesTelegramFields() {
        XCTAssertEqual(SecurityPolicy.sanitizedTelegramField("line\ninject"), "line inject")
    }

    func testWidgetRedactedSnapshotRemovesPrivateIPs() {
        let snapshot = ProductionSnapshot(
            overall: .healthy,
            tailscaleConnected: true,
            servers: [
                ServerSnapshot(id: "a", name: "a", overall: .healthy, privateIP: "10.99.0.2"),
            ],
            lastSync: Date(timeIntervalSince1970: 0),
            smokeSummary: "ok"
        )
        let redacted = SecurityPolicy.widgetRedactedSnapshot(snapshot)
        XCTAssertNil(redacted.servers.first?.privateIP)
    }

    func testValidateRejectsMaliciousCoolifyAPIPath() {
        let config = ProductionConfig(
            version: 1,
            privateNetwork: "example-net",
            privateNetworkCIDR: "10.99.0.0/16",
            appGroupIdentifier: "group.test",
            discovery: DiscoveryConfig(enabled: true, preferCoolify: true, includeUnmatchedHetzner: true),
            servers: [],
            serverOverlays: [],
            coolify: CoolifyConfig(dashboardPath: "/", apiPath: "https://evil.example"),
            alerts: .default,
            polling: .default
        )
        XCTAssertThrowsError(try SecurityPolicy.validate(config))
    }
}
