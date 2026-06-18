import Foundation

/// Central validation for outbound probes, config paths, clipboard, and shared snapshots.
public enum SecurityPolicy {
    public static let maxHTTPBodyBytes = 256 * 1024
    public static let pasteboardClearDelaySeconds: TimeInterval = 60
    public static let tailscaleCGNATCIDR = "100.64.0.0/10"

    private static let shellMetacharacters = CharacterSet(charactersIn: ";|&$`<>\"'\\(){}[]!#*?\n\r\t ")

    // MARK: - Coolify API path (P0)

    public static func isRelativeAPIPath(_ path: String) -> Bool {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/"), !trimmed.contains("://") else { return false }
        return !trimmed.contains("@")
    }

    public static func apiBaseURL(host: URL, apiPath: String) -> URL {
        guard isRelativeAPIPath(apiPath),
              let resolved = URL(string: apiPath, relativeTo: host),
              let scheme = resolved.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              resolved.host != nil
        else {
            return host.appendingPathComponent("api/v1")
        }
        return resolved
    }

    // MARK: - HTTP probe URLs (P1)

    public enum ProbeURLPolicy: Equatable {
        case allow
        case block(String)
    }

    public static func probeURLPolicy(for urlString: String) -> ProbeURLPolicy {
        guard let url = URL(string: urlString), let host = url.host, !host.isEmpty else {
            return .block("invalid URL")
        }
        guard let scheme = url.scheme?.lowercased() else {
            return .block("missing URL scheme")
        }

        let lowerHost = host.lowercased()
        if lowerHost == "localhost" || lowerHost.hasSuffix(".localhost") {
            return .block("localhost is not allowed")
        }

        if isBlockedProbeAddress(lowerHost) {
            return .block("reserved or metadata address")
        }

        switch scheme {
        case "https":
            return .allow
        case "http":
            if isPrivateOrTailscaleHost(lowerHost) {
                return .allow
            }
            return .block("public HTTP probes must use HTTPS")
        default:
            return .block("unsupported URL scheme")
        }
    }

    public static func isAllowedBrowserURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let scheme = url.scheme?.lowercased() else {
            return false
        }
        guard scheme == "https" || scheme == "http" else { return false }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return false }
        if host == "localhost" || host.hasSuffix(".localhost") { return false }
        if isBlockedProbeAddress(host) { return false }
        return true
    }

    public static func isAllowedCoolifyBaseURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return false
        }
        guard let host = url.host, !host.isEmpty else { return false }
        return !isBlockedProbeAddress(host.lowercased())
    }

    // MARK: - Coolify domains (P1)

    public static func isValidProbeHostname(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty, trimmed.count <= 253 else { return false }
        if trimmed.contains("@") || trimmed.contains("/") || trimmed.contains(":") { return false }
        let labels = trimmed.split(separator: ".")
        guard labels.count >= 2 else { return false }
        for label in labels {
            guard !label.isEmpty, label.count <= 63 else { return false }
            guard let first = label.first, first.isLetter || first.isNumber else { return false }
            guard let last = label.last, last.isLetter || last.isNumber else { return false }
            if label.rangeOfCharacter(from: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted) != nil {
                return false
            }
        }
        return true
    }

    // MARK: - Private TCP probes (P1)

    public static func isValidPrivateProbePort(_ port: Int) -> Bool {
        (1 ... 65_535).contains(port)
    }

    public static func isAllowedPrivateProbeHost(_ host: String, allowedCIDR: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.rangeOfCharacter(from: shellMetacharacters) != nil { return false }

        if let ipv4 = parseIPv4(trimmed) {
            return isIPv4(ipv4, inCIDR: allowedCIDR) || isIPv4(ipv4, inCIDR: tailscaleCGNATCIDR)
        }
        return isValidProbeHostname(trimmed)
    }

    // MARK: - SSH / clipboard (P0)

    public static func sanitizedSSHHost(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 253 else { return nil }
        if trimmed.rangeOfCharacter(from: shellMetacharacters) != nil { return nil }

        if let ipv4 = parseIPv4(trimmed) {
            return ipv4.map(String.init).joined(separator: ".")
        }

        if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
            let inner = String(trimmed.dropFirst().dropLast())
            guard !inner.isEmpty, inner.rangeOfCharacter(from: shellMetacharacters) == nil else { return nil }
            return "[\(inner)]"
        }

        guard isValidProbeHostname(trimmed) else { return nil }
        return trimmed
    }

    public static func sshCommand(user: String = "deploy", host: String) -> String? {
        guard let sanitizedHost = sanitizedSSHHost(host) else { return nil }
        let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUser.isEmpty,
              trimmedUser.rangeOfCharacter(from: shellMetacharacters) == nil
        else { return nil }
        return "ssh \(trimmedUser)@\(sanitizedHost)"
    }

    public static func sanitizedClipboardText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.rangeOfCharacter(from: CharacterSet.controlCharacters) != nil { return nil }
        if trimmed.contains("\0") { return nil }
        return trimmed
    }

    // MARK: - Telegram (P1)

    public static func sanitizedTelegramField(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func sanitizedTelegramMessage(_ message: String, maxLength: Int = 3_500) -> String {
        let flat = message
            .split(whereSeparator: \.isNewline)
            .map { sanitizedTelegramField(String($0)) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        if flat.count <= maxLength { return flat }
        return String(flat.prefix(maxLength))
    }

    // MARK: - Widget snapshot (P2)

    public static func widgetRedactedSnapshot(_ snapshot: ProductionSnapshot) -> ProductionSnapshot {
        ProductionSnapshot(
            overall: snapshot.overall,
            tailscaleConnected: snapshot.tailscaleConnected,
            servers: snapshot.servers.map { server in
                ServerSnapshot(
                    id: server.id,
                    name: server.name,
                    overall: server.overall,
                    coolifyReachable: server.coolifyReachable,
                    coolifyUsable: server.coolifyUsable,
                    hetznerHostName: server.hetznerHostName,
                    region: server.region,
                    privateIP: nil,
                    coolifyDomains: server.coolifyDomains,
                    containersRunning: server.containersRunning,
                    containersTotal: server.containersTotal,
                    cpuPercent: server.cpuPercent,
                    ramPercent: server.ramPercent,
                    diskMBps: server.diskMBps,
                    netInMbps: server.netInMbps,
                    endpointChecks: server.endpointChecks,
                    privateProbes: server.privateProbes,
                    containers: server.containers
                )
            },
            lastSync: snapshot.lastSync,
            smokeSummary: snapshot.smokeSummary
        )
    }

    // MARK: - Config validation

    public enum ConfigValidationError: Error, Equatable {
        case invalidCoolifyAPIPath(String)
        case invalidPrivateProbe(String)
    }

    public static func validate(_ config: ProductionConfig) throws {
        guard isRelativeAPIPath(config.coolify.apiPath) else {
            throw ConfigValidationError.invalidCoolifyAPIPath(config.coolify.apiPath)
        }

        for server in config.servers {
            try validateProbes(server.privateProbes, context: server.id)
        }
        for overlay in config.serverOverlays {
            let name = overlay.match.hetznerName ?? overlay.match.coolifyName ?? "overlay"
            try validateProbes(overlay.privateProbes, context: name)
        }
    }

    private static func validateProbes(_ probes: [PrivateProbe], context: String) throws {
        for probe in probes {
            guard isValidPrivateProbePort(probe.port) else {
                throw ConfigValidationError.invalidPrivateProbe("\(context): port \(probe.port)")
            }
            guard isAllowedPrivateProbeHost(probe.host, allowedCIDR: "0.0.0.0/0") || parseIPv4(probe.host) != nil || isValidProbeHostname(probe.host) else {
                throw ConfigValidationError.invalidPrivateProbe("\(context): host \(probe.host)")
            }
        }
    }

    // MARK: - IPv4 helpers

    private static func isBlockedProbeAddress(_ host: String) -> Bool {
        if host == "169.254.169.254" { return true }
        if let ipv4 = parseIPv4(host) {
            if ipv4[0] == 127 { return true }
            if ipv4[0] == 0 { return true }
            if ipv4[0] == 169 && ipv4[1] == 254 { return true }
        }
        return false
    }

    private static func isPrivateOrTailscaleHost(_ host: String) -> Bool {
        guard let ipv4 = parseIPv4(host) else { return false }
        if ipv4[0] == 10 { return true }
        if ipv4[0] == 172 && (16 ... 31).contains(ipv4[1]) { return true }
        if ipv4[0] == 192 && ipv4[1] == 168 { return true }
        if ipv4[0] == 100 && (64 ... 127).contains(ipv4[1]) { return true }
        return false
    }

    private static func parseIPv4(_ host: String) -> [UInt8]? {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var bytes: [UInt8] = []
        for part in parts {
            guard let value = UInt8(part) else { return nil }
            bytes.append(value)
        }
        return bytes
    }

    private static func isIPv4(_ bytes: [UInt8], inCIDR cidr: String) -> Bool {
        let parts = cidr.split(separator: "/")
        guard parts.count == 2,
              let network = parseIPv4(String(parts[0])),
              let prefix = Int(parts[1]),
              (0 ... 32).contains(prefix)
        else { return false }

        let address = (UInt32(bytes[0]) << 24) | (UInt32(bytes[1]) << 16) | (UInt32(bytes[2]) << 8) | UInt32(bytes[3])
        let networkValue = (UInt32(network[0]) << 24) | (UInt32(network[1]) << 16) | (UInt32(network[2]) << 8) | UInt32(network[3])
        let mask: UInt32 = prefix == 0 ? 0 : UInt32.max << (32 - prefix)
        return (address & mask) == (networkValue & mask)
    }
}
