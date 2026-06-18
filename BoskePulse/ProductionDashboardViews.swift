import BoskePulseCore
import SwiftUI

// MARK: - Layout & theme

enum PulseLayout {
    static let tileHeight: CGFloat = 228
    static let tileHeightCompact: CGFloat = 132
    static let tileCorner: CGFloat = 12
    static let windowColumns = 3
    static let menuBarColumns = 2
}

enum BoskeDensity {
    case window
    case menuBar

    var isWindow: Bool { self == .window }
}

private struct BoskeDensityKey: EnvironmentKey {
    static let defaultValue: BoskeDensity = .window
}

extension EnvironmentValues {
    var boskeDensity: BoskeDensity {
        get { self[BoskeDensityKey.self] }
        set { self[BoskeDensityKey.self] = newValue }
    }
}

enum BoskeTheme {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let surface = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let surfaceRaised = Color(red: 0.13, green: 0.14, blue: 0.17)
    static let border = Color.white.opacity(0.10)
    static let text = Color(red: 0.94, green: 0.95, blue: 0.97)
    static let muted = Color(red: 0.58, green: 0.61, blue: 0.66)
    static let dim = Color(red: 0.42, green: 0.44, blue: 0.48)
    static let accent = Color(red: 0.22, green: 0.84, blue: 0.60)
    static let amber = Color(red: 0.96, green: 0.74, blue: 0.28)
    static let red = Color(red: 0.95, green: 0.35, blue: 0.35)

    static func health(_ health: OverallHealth) -> Color {
        switch health {
        case .healthy: accent
        case .degraded: amber
        case .down: red
        case .unknown: muted
        }
    }

    static func check(_ status: CheckStatus) -> Color {
        switch status {
        case .ok: accent
        case .warn: amber
        case .fail: red
        case .skipped: dim
        }
    }

    static func healthLabel(_ health: OverallHealth) -> String {
        switch health {
        case .healthy: "Healthy"
        case .degraded: "Degraded"
        case .down: "Down"
        case .unknown: "Unknown"
        }
    }
}

enum PulseTheme {
    static func healthColor(_ health: OverallHealth) -> Color { BoskeTheme.health(health) }
    static func checkColor(_ status: CheckStatus) -> Color { BoskeTheme.check(status) }
    static let cardBackground = BoskeTheme.surface
    static let cardStroke = BoskeTheme.border
}

// MARK: - Compact dashboard header

struct ProductionHeaderView: View {
    let snapshot: ProductionSnapshot?
    let serverCount: Int
    let isRefreshing: Bool
    var expanded: Bool = false

    var body: some View {
        if expanded {
            windowHeader
        } else {
            menuBarHeader
        }
    }

    private var windowHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(snapshot.map { BoskeTheme.health($0.overall) } ?? BoskeTheme.muted)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Boske Pulse")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .foregroundStyle(BoskeTheme.text)
                    Text(snapshot?.smokeSummary ?? (isRefreshing ? "Refreshing…" : "Awaiting sync"))
                        .font(.caption)
                        .foregroundStyle(BoskeTheme.muted)
                        .lineLimit(1)
                        .copyOnClick(snapshot?.smokeSummary ?? "")
                }
            }

            Spacer()

            HStack(spacing: 20) {
                statPill(title: "Hosts", value: "\(serverCount)")
                statPill(title: "Sync", value: syncLabel)
            }
        }
        .padding(.horizontal, 4)
    }

    private var menuBarHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(snapshot.map { BoskeTheme.health($0.overall) } ?? BoskeTheme.muted)
                .frame(width: 8, height: 8)
            Text("Boske Pulse")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            Spacer()
            Text("\(serverCount) hosts")
                .font(.caption)
                .foregroundStyle(BoskeTheme.muted)
        }
    }

    private func statPill(title: String, value: String, tint: Color = BoskeTheme.text) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(BoskeTheme.dim)
            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.medium))
                .foregroundStyle(tint)
        }
    }

    private var syncLabel: String {
        if isRefreshing { return "…" }
        guard let lastSync = snapshot?.lastSync else { return "—" }
        return lastSync.formatted(date: .omitted, time: .shortened)
    }
}

struct TopologyStrip: View {
    let servers: [ServerSnapshot]
    var expanded: Bool = false
    var body: some View { EmptyView() }
}

struct StatusBadge: View {
    let health: OverallHealth
    var style: Style = .compact
    enum Style { case compact, prominent, hero }

    var body: some View {
        Text(BoskeTheme.healthLabel(health).uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(BoskeTheme.health(health))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(BoskeTheme.health(health).opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Uniform server tile

struct PulseServerTile: View {
    let server: ServerSnapshot
    let config: ServerConfig?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            BoskeTheme.health(server.overall)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: compact ? 5 : 6) {
                header
                if !compact { metaLine }
                metricsRow
                if !server.endpointChecks.isEmpty { probeLine }
                if !server.coolifyDomains.isEmpty { domainsLine }
                containersBlock
            }
            .padding(compact ? 10 : 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? PulseLayout.tileHeightCompact : PulseLayout.tileHeight)
        .background(BoskeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseLayout.tileCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseLayout.tileCorner, style: .continuous)
                .strokeBorder(BoskeTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: compact ? 2 : 4, y: 2)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(server.name)
                .font(.system(compact ? .caption : .subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(BoskeTheme.text)
                .lineLimit(1)
                .copyOnClick(server.name)
            Spacer(minLength: 4)
            StatusBadge(health: server.overall)
                .copyOnClick(server.overall.rawValue)
        }
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            if let region = server.region, !region.isEmpty {
                Text(region.uppercased())
                    .foregroundStyle(BoskeTheme.dim)
            }
            if let ip = config?.publicIPv4, !ip.isEmpty {
                if server.region != nil { Text("·").foregroundStyle(BoskeTheme.dim) }
                Text(ip)
                    .foregroundStyle(BoskeTheme.muted)
            }
        }
        .font(.caption2)
        .lineLimit(1)
        .copyOnClick(metaCopyText)
    }

    private var metaCopyText: String {
        [server.region?.uppercased(), config?.publicIPv4].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }.joined(separator: " · ")
    }

    private var metricsRow: some View {
        HStack(spacing: compact ? 8 : 12) {
            LiveMetricChip(label: "CPU", value: server.cpuPercent, format: .percent)
            LiveMetricChip(label: "Disk", value: server.diskMBps, format: .throughput(unit: "MB/s"))
            if !compact {
                LiveMetricChip(label: "Net", value: server.netInMbps, format: .throughput(unit: "Mb/s"))
            }
        }
        .copyOnClick(metricsCopyText)
    }

    private var metricsCopyText: String {
        var parts: [String] = []
        if let cpu = server.cpuPercent {
            parts.append(String(format: "CPU %.0f%%", cpu))
        }
        if let disk = server.diskMBps {
            parts.append(String(format: "Disk %.2f MB/s", disk))
        }
        if let net = server.netInMbps {
            parts.append(String(format: "Net %.2f Mb/s", net))
        }
        return parts.joined(separator: " · ")
    }

    private var probeLine: some View {
        Group {
            if let check = server.endpointChecks.first {
                HStack(spacing: 6) {
                    Circle()
                        .fill(BoskeTheme.check(check.status))
                        .frame(width: 6, height: 6)
                    Text(check.label)
                        .foregroundStyle(BoskeTheme.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if let ms = check.latencyMs {
                        Text("\(ms)ms")
                            .foregroundStyle(BoskeTheme.muted)
                    }
                }
                .font(.caption2)
                .copyOnClick(probeCopyText(for: check))
            } else if let probe = server.privateProbes.first {
                HStack(spacing: 6) {
                    Circle()
                        .fill(BoskeTheme.check(probe.status))
                        .frame(width: 6, height: 6)
                    Text(probe.label)
                        .foregroundStyle(BoskeTheme.text)
                        .lineLimit(1)
                    Spacer()
                    Text(probe.message ?? "private")
                        .foregroundStyle(BoskeTheme.dim)
                        .lineLimit(1)
                }
                .font(.caption2)
                .copyOnClick("\(probe.label) \(probe.message ?? "private")")
            }
        }
    }

    private func probeCopyText(for check: EndpointCheckResult) -> String {
        if let ms = check.latencyMs {
            return "\(check.label) \(ms)ms"
        }
        return check.label
    }

    private var domainsLine: some View {
        HStack(spacing: 6) {
            Text("domains")
                .foregroundStyle(BoskeTheme.dim)
            Text(server.coolifyDomains.prefix(compact ? 2 : 3).joined(separator: ", "))
                .foregroundStyle(BoskeTheme.muted)
                .lineLimit(1)
            if server.coolifyDomains.count > (compact ? 2 : 3) {
                Text("+\(server.coolifyDomains.count - (compact ? 2 : 3))")
                    .foregroundStyle(BoskeTheme.dim)
            }
        }
        .font(.caption2)
        .copyOnClick(server.coolifyDomains.joined(separator: ", "))
    }

    private var containersBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(
                    server.containersTotal > 0
                        ? "Containers \(server.containersRunning)/\(server.containersTotal)"
                        : "Containers",
                    systemImage: "shippingbox"
                )
                .font(.system(size: compact ? 9 : 10, weight: .semibold))
                .foregroundStyle(BoskeTheme.dim)
                Spacer()
                if let coolify = server.coolifyReachable {
                    Text(coolify ? "CF ok" : "CF down")
                        .font(.caption2)
                        .foregroundStyle(coolify ? BoskeTheme.accent : BoskeTheme.amber)
                }
            }
            .copyOnClick(containersCopyText)

            if server.containers.isEmpty {
                Text("no services reported")
                    .font(.caption2)
                    .foregroundStyle(BoskeTheme.dim)
                    .copyOnClick("no services reported")
            } else {
                ForEach(visibleContainers) { container in
                    ContainerRow(container: container, compact: compact)
                }
                if hiddenContainerCount > 0 {
                    Text("+\(hiddenContainerCount) more")
                        .font(.caption2)
                        .foregroundStyle(BoskeTheme.dim)
                        .copyOnClick(hiddenContainersCopyText)
                }
            }
        }
    }

    private var containersCopyText: String {
        guard !server.containers.isEmpty else { return "containers: none" }
        return server.containers
            .map { "\($0.name)\t\($0.state)\t\($0.image ?? "")" }
            .joined(separator: "\n")
    }

    private var hiddenContainersCopyText: String {
        server.containers.dropFirst(visibleContainers.count)
            .map(\.name)
            .joined(separator: "\n")
    }

    private var visibleContainers: [ContainerTile] {
        let limit = compact ? 3 : 6
        return Array(server.containers.prefix(limit))
    }

    private var hiddenContainerCount: Int {
        max(0, server.containers.count - visibleContainers.count)
    }
}

struct ContainerRow: View {
    let container: ContainerTile
    var compact: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BoskeTheme.check(container.health))
                .frame(width: 6, height: 6)
            Text(container.name)
                .font(.system(size: compact ? 10 : 11, design: .monospaced))
                .foregroundStyle(BoskeTheme.text)
                .lineLimit(1)
            Spacer(minLength: 0)
            if !compact, let type = container.image, !type.isEmpty {
                Text(type)
                    .font(.caption2)
                    .foregroundStyle(BoskeTheme.dim)
                    .lineLimit(1)
                    .frame(maxWidth: 64, alignment: .trailing)
            }
            Text(shortState(container.state))
                .font(.caption2)
                .foregroundStyle(BoskeTheme.muted)
                .lineLimit(1)
        }
        .copyOnClick(copyText)
    }

    private var copyText: String {
        [container.name, container.state, container.image].compactMap { $0 }.joined(separator: " ")
    }

    private func shortState(_ state: String) -> String {
        if state.count <= 14 { return state }
        return String(state.prefix(14))
    }
}

struct LiveMetricChip: View {
    enum Format {
        case percent
        case throughput(unit: String)
    }

    let label: String
    let value: Double?
    let format: Format

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(BoskeTheme.dim)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(value == nil ? BoskeTheme.dim : BoskeTheme.text)
                    .animation(.easeOut(duration: 0.25), value: value)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(barColor.gradient)
                        .frame(width: max(4, geo.size.width * barFill))
                        .animation(.easeOut(duration: 0.35), value: value)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var displayValue: String {
        guard let value else { return "—" }
        switch format {
        case .percent:
            return String(format: "%.0f%%", min(value, 999))
        case .throughput(let unit):
            if value >= 100 { return String(format: "%.0f%@", value, unit) }
            if value >= 10 { return String(format: "%.1f%@", value, unit) }
            return String(format: "%.2f%@", value, unit)
        }
    }

    private var barFill: CGFloat {
        guard let value else { return 0 }
        switch format {
        case .percent:
            return CGFloat(min(value, 100) / 100)
        case .throughput:
            return CGFloat(min(value / 50.0, 1.0))
        }
    }

    private var barColor: Color {
        guard let value else { return BoskeTheme.dim }
        switch format {
        case .percent:
            if value >= 85 { return BoskeTheme.red }
            if value >= 70 { return BoskeTheme.amber }
            return BoskeTheme.accent
        case .throughput:
            return BoskeTheme.accent.opacity(0.85)
        }
    }
}

// Legacy aliases used elsewhere

struct ServerCardView: View {
    let server: ServerSnapshot
    let config: ServerConfig?
    var expanded: Bool = false

    var body: some View {
        PulseServerTile(server: server, config: config, compact: !expanded)
    }
}

struct MenuBarServerRow: View {
    let server: ServerSnapshot
    let config: ServerConfig?

    var body: some View {
        PulseServerTile(server: server, config: config, compact: true)
    }
}

struct DividerLine: View {
    var body: some View {
        Rectangle().fill(BoskeTheme.border).frame(height: 1)
    }
}

struct DomainChip: View {
    let domain: String
    var body: some View {
        Text(domain).font(.caption2).foregroundStyle(BoskeTheme.muted)
    }
}

struct CheckChip: View {
    let label: String
    let status: CheckStatus
    let detail: String?
    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(BoskeTheme.check(status)).frame(width: 5, height: 5)
            Text(label).font(.caption2)
            if let detail { Text(detail).font(.caption2).foregroundStyle(BoskeTheme.dim) }
        }
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    let tint: Color
    var body: some View {
        Label(text, systemImage: icon).font(.caption2).foregroundStyle(tint)
    }
}

struct MetricBar: View {
    let label: String
    let value: Double
    let tint: Color
    var body: some View {
        LiveMetricChip(label: label, value: value, format: .percent)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 0, height: 0)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {}
}

struct TerminalGauge: View {
    let label: String
    let percent: Double?
    var body: some View { LiveMetricChip(label: label, value: percent, format: .percent) }
}

struct TerminalThroughput: View {
    let label: String
    let value: Double?
    let unit: String
    var body: some View { LiveMetricChip(label: label, value: value, format: .throughput(unit: unit)) }
}

struct ProbeLine: View {
    let check: EndpointCheckResult
    var body: some View { CheckChip(label: check.label, status: check.status, detail: check.latencyMs.map { "\($0)ms" }) }
}

struct PrivateProbeLine: View {
    let probe: PrivateProbeResult
    var body: some View { CheckChip(label: probe.label, status: probe.status, detail: probe.message) }
}

struct DomainLine: View {
    let domain: String
    var body: some View { DomainChip(domain: domain) }
}

struct ContainerLine: View {
    let container: ContainerTile
    var body: some View {
        Text(container.name).font(.caption2).foregroundStyle(BoskeTheme.muted)
    }
}
