import BoskePulseCore
import Foundation

enum ServerCopyFormatter {
    static func text(for server: ServerSnapshot, config: ServerConfig?) -> String {
        var lines: [String] = []
        lines.append("\(server.name) — \(server.overall.rawValue)")
        if let region = server.region, !region.isEmpty {
            lines.append("region \(region)")
        }
        if let ip = config?.publicIPv4, !ip.isEmpty {
            lines.append("ip \(ip)")
        }
        if let ssh = config?.links.ssh, !ssh.isEmpty {
            lines.append(ssh)
        }
        if let cpu = server.cpuPercent {
            lines.append(String(format: "cpu %.0f%%", cpu))
        }
        if let disk = server.diskMBps {
            lines.append(String(format: "disk %.2f MB/s", disk))
        }
        if let net = server.netInMbps {
            lines.append(String(format: "net %.2f Mb/s", net))
        }
        for check in server.endpointChecks {
            let latency = check.latencyMs.map { " \($0)ms" } ?? ""
            lines.append("\(check.label) \(check.status.rawValue)\(latency)")
        }
        if !server.coolifyDomains.isEmpty {
            lines.append("domains \(server.coolifyDomains.joined(separator: ", "))")
        }
        if !server.containers.isEmpty {
            lines.append("containers \(server.containersRunning)/\(server.containersTotal)")
            for container in server.containers {
                lines.append("  \(container.name) \(container.state) \(container.image ?? "")")
            }
        }
        return lines.joined(separator: "\n")
    }
}
