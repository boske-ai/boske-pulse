import BoskePulseCore
import SwiftUI

// MARK: - Layout & theme

enum PulseLayout {
    static let tileHeight: CGFloat = 236
    static let tileHeightCompactMin: CGFloat = 92
    static let tileCorner: CGFloat = 12
    static let windowColumns = 3
    static let menuBarColumns = 1
    static let popoverWidth: CGFloat = 400
}

enum PulseDisplayNames {
    static func container(_ name: String, compact: Bool) -> String {
        let maxLength = compact ? 18 : 28
        guard name.count > maxLength else { return name }
        if name.hasPrefix("service-"), name.count > 20 {
            return "service"
        }
        if compact {
            return String(name.prefix(maxLength - 1)) + "…"
        }
        let head = name.prefix(14)
        let tail = name.suffix(8)
        return "\(head)…\(tail)"
    }
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
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 10) {
                Circle()
                    .fill(snapshot.map { BoskeTheme.health($0.overall) } ?? BoskeTheme.muted)
                    .frame(width: 8, height: 8)
                Text("Boske Pulse")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(BoskeTheme.text)
                Spacer()
                Text("\(serverCount) hosts")
                    .font(.caption)
                    .foregroundStyle(BoskeTheme.muted)
            }
            Text(snapshot?.smokeSummary ?? (isRefreshing ? "Refreshing…" : "Awaiting sync"))
                .font(.caption2)
                .foregroundStyle(BoskeTheme.dim)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
    var mini: Bool = false

    var body: some View {
        Group {
            if mini {
                Text(miniLabel)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(BoskeTheme.health(health))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(BoskeTheme.health(health).opacity(0.15))
                    .clipShape(Capsule())
                    .fixedSize()
            } else {
                Text(BoskeTheme.healthLabel(health).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BoskeTheme.health(health))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BoskeTheme.health(health).opacity(0.15))
                    .clipShape(Capsule())
            }
        }
    }

    private var miniLabel: String {
        switch health {
        case .healthy: "OK"
        case .degraded: "WARN"
        case .down: "DOWN"
        case .unknown: "?"
        }
    }
}

// MARK: - Uniform server tile

private struct ExpandChevron: View {
    let isExpanded: Bool

    var body: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(BoskeTheme.dim)
            .frame(width: 14, height: 14)
    }
}

private struct FoldToggle: View {
    let isExpanded: Bool
    var moreCount: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(BoskeTheme.accent.opacity(0.9))
        }
        .buttonStyle(.plain)
        .help(isExpanded ? "Show less" : "Show more")
    }

    private var label: String {
        if isExpanded { return "Show less" }
        if let moreCount { return "+\(moreCount) more" }
        return "Show more"
    }
}

struct PulseServerTile: View {
    let server: ServerSnapshot
    let config: ServerConfig?
    var compact: Bool = false
    var onOpenURL: ((String) -> Void)? = nil

    @State private var detailsExpanded = false
    @State private var endpointsExpanded = false
    @State private var domainsExpanded = false
    @State private var containersExpanded = false

    private var isAnyExpanded: Bool {
        detailsExpanded || endpointsExpanded || domainsExpanded || containersExpanded
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            BoskeTheme.health(server.overall)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: compact ? 6 : 8) {
                header
                metaLine
                metricsRow
                endpointsSection
                if shouldShowDomains { domainsSection }
                containersSection
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 10 : 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: compact && !isAnyExpanded ? PulseLayout.tileHeightCompactMin : nil,
            alignment: .top
        )
        .background(BoskeTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: PulseLayout.tileCorner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PulseLayout.tileCorner, style: .continuous)
                .strokeBorder(BoskeTheme.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: compact ? 2 : 4, y: 2)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 6) {
            Text(server.name)
                .font(.system(compact ? .caption : .subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(BoskeTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(compact ? 0.75 : 0.85)
                .layoutPriority(1)
            if !compact, serverHasUncertainContainers {
                Text("?")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(BoskeTheme.amber)
                    .help("Coolify health detail unknown — host is running")
            }
            StatusBadge(health: server.overall, mini: compact)
            if hasExpandableDetail {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { toggleAllSections() }
                } label: {
                    ExpandChevron(isExpanded: isAnyExpanded)
                }
                .buttonStyle(.plain)
                .help(isAnyExpanded ? "Collapse all" : "Expand all")
            }
        }
    }

    private func toggleAllSections() {
        if isAnyExpanded {
            detailsExpanded = false
            endpointsExpanded = false
            domainsExpanded = false
            containersExpanded = false
        } else {
            if canExpandDetails { detailsExpanded = true }
            if canExpandEndpoints { endpointsExpanded = true }
            if canExpandDomains { domainsExpanded = true }
            if canExpandContainers { containersExpanded = true }
        }
    }

    private func toggleSection(_ expanded: inout Bool) {
        withAnimation(.easeOut(duration: 0.2)) { expanded.toggle() }
    }

    private var visibleContainerLimit: Int { compact ? 2 : 6 }

    private var canExpandDetails: Bool {
        (server.privateIP?.isEmpty == false)
            || (config?.links.ssh.isEmpty == false)
            || (compact && (server.netInMbps != nil || server.ramPercent != nil))
            || (!compact && server.ramPercent != nil)
    }

    private var canExpandEndpoints: Bool {
        server.endpointChecks.count > 1
            || !server.privateProbes.isEmpty
            || endpointChecksHaveURLs
    }

    private var canExpandDomains: Bool {
        server.coolifyDomains.count > domainPreviewCount
    }

    private var canExpandContainers: Bool {
        !server.containers.isEmpty && displayedContainers.count > visibleContainerLimit
    }

    private var hasExpandableDetail: Bool {
        canExpandDetails || canExpandEndpoints || canExpandDomains || canExpandContainers
    }

    private var endpointChecksHaveURLs: Bool {
        server.endpointChecks.contains { endpointURL(for: $0) != nil }
    }

    private var shouldShowDomains: Bool {
        guard !server.coolifyDomains.isEmpty else { return false }
        if !compact { return true }
        return server.endpointChecks.isEmpty || server.coolifyDomains.count > 1
    }

    private var serverHasUncertainContainers: Bool {
        server.containers.contains(where: \.uncertainHealth)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            if let region = server.region, !region.isEmpty {
                Text(region.uppercased())
                    .foregroundStyle(BoskeTheme.dim)
            }
            if let ip = config?.publicIPv4, !ip.isEmpty {
                if server.region != nil { Text("·").foregroundStyle(BoskeTheme.dim) }
                CopyableValue(text: ip)
            }
            if detailsExpanded, let privateIP = server.privateIP, !privateIP.isEmpty {
                Text("·").foregroundStyle(BoskeTheme.dim)
                CopyableValue(text: privateIP, color: BoskeTheme.dim)
            }
            if detailsExpanded, let ssh = config?.links.ssh, !ssh.isEmpty {
                Text("·").foregroundStyle(BoskeTheme.dim)
                CopyableValue(text: ssh, color: BoskeTheme.dim)
            }
            if canExpandDetails {
                Button {
                    toggleSection(&detailsExpanded)
                } label: {
                    ExpandChevron(isExpanded: detailsExpanded)
                }
                .buttonStyle(.plain)
                .help(detailsExpanded ? "Hide details" : "Show details")
            }
        }
        .font(.caption2)
        .lineLimit(detailsExpanded ? nil : 1)
    }

    private var metricsRow: some View {
        Group {
            if compact {
                HStack(spacing: 14) {
                    compactMetric(label: "CPU", value: server.cpuPercent.map { String(format: "%.0f%%", $0) } ?? "—")
                    compactMetric(label: "Disk", value: diskLabel)
                    if detailsExpanded {
                        compactMetric(
                            label: "Net",
                            value: server.netInMbps.map { String(format: "%.1f Mb/s", $0) } ?? "—"
                        )
                        if let ram = server.ramPercent {
                            compactMetric(label: "RAM", value: String(format: "%.0f%%", ram))
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    LiveMetricChip(label: "CPU", value: server.cpuPercent, format: .percent)
                    LiveMetricChip(label: "Disk", value: server.diskMBps, format: .throughput(unit: "MB/s"))
                    LiveMetricChip(label: "Net", value: server.netInMbps, format: .throughput(unit: "Mb/s"))
                    if detailsExpanded, let ram = server.ramPercent {
                        LiveMetricChip(label: "RAM", value: ram, format: .percent)
                    }
                }
            }
        }
    }

    private var diskLabel: String {
        guard let disk = server.diskMBps else { return "—" }
        return disk <= 0.005 ? "idle" : String(format: "%.1f MB/s", disk)
    }

    private func compactMetric(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .foregroundStyle(BoskeTheme.dim)
            Text(value)
                .foregroundStyle(BoskeTheme.text)
                .monospacedDigit()
        }
        .font(.caption2)
    }

    @ViewBuilder
    private var endpointsSection: some View {
        if !server.endpointChecks.isEmpty || !server.privateProbes.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if endpointsExpanded {
                    ForEach(server.endpointChecks) { check in
                        expandedEndpointRow(check)
                    }
                    ForEach(server.privateProbes) { probe in
                        expandedPrivateProbeRow(probe)
                    }
                    if canExpandEndpoints {
                        FoldToggle(isExpanded: true) {
                            toggleSection(&endpointsExpanded)
                        }
                    }
                } else {
                    if let check = server.endpointChecks.first {
                        collapsedEndpointRow(check)
                    } else if let probe = server.privateProbes.first {
                        collapsedPrivateProbeRow(probe)
                    }
                    if canExpandEndpoints {
                        let hidden = server.endpointChecks.count + server.privateProbes.count - 1
                        FoldToggle(isExpanded: false, moreCount: hidden > 0 ? hidden : nil) {
                            toggleSection(&endpointsExpanded)
                        }
                    }
                }
            }
        }
    }

    private func collapsedEndpointRow(_ check: EndpointCheckResult) -> some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if canExpandEndpoints {
                toggleSection(&endpointsExpanded)
            }
        }
    }

    private func expandedEndpointRow(_ check: EndpointCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(BoskeTheme.check(check.status))
                    .frame(width: 6, height: 6)
                Text(check.label)
                    .foregroundStyle(BoskeTheme.text)
                Spacer(minLength: 0)
                if let http = check.httpStatus {
                    Text("\(http)")
                        .foregroundStyle(BoskeTheme.dim)
                }
                if let ms = check.latencyMs {
                    Text("\(ms)ms")
                        .foregroundStyle(BoskeTheme.muted)
                }
            }
            .font(.caption2)
            if let url = endpointURL(for: check) {
                endpointURLRow(url)
            }
            if let message = check.message, !message.isEmpty {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(BoskeTheme.dim)
                    .lineLimit(2)
            }
        }
    }

    private func collapsedPrivateProbeRow(_ probe: PrivateProbeResult) -> some View {
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
        .contentShape(Rectangle())
        .onTapGesture {
            if canExpandEndpoints {
                toggleSection(&endpointsExpanded)
            }
        }
    }

    private func expandedPrivateProbeRow(_ probe: PrivateProbeResult) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(BoskeTheme.check(probe.status))
                .frame(width: 6, height: 6)
            Text(probe.label)
                .foregroundStyle(BoskeTheme.text)
            Spacer()
            Text(probe.message ?? "private")
                .foregroundStyle(BoskeTheme.dim)
                .lineLimit(2)
        }
        .font(.caption2)
    }

    private func endpointURLRow(_ url: String) -> some View {
        HStack(spacing: 6) {
            CopyableValue(text: url, color: BoskeTheme.dim)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if onOpenURL != nil {
                Button {
                    onOpenURL?(url)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.caption2)
                        .foregroundStyle(BoskeTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Open in browser")
            }
        }
    }

    private func endpointURL(for check: EndpointCheckResult) -> String? {
        guard let url = config?.publicEndpoints.first(where: { $0.id == check.id })?.url,
              !url.isEmpty else { return nil }
        return url
    }

    private var domainPreviewCount: Int { compact ? 2 : 3 }

    @ViewBuilder
    private var domainsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if domainsExpanded {
                ForEach(server.coolifyDomains, id: \.self) { domain in
                    domainRow(domain)
                }
                if canExpandDomains {
                    FoldToggle(isExpanded: true) {
                        toggleSection(&domainsExpanded)
                    }
                }
            } else {
                HStack(spacing: 6) {
                    Text("domains")
                        .foregroundStyle(BoskeTheme.dim)
                    Text(server.coolifyDomains.prefix(domainPreviewCount).joined(separator: ", "))
                        .foregroundStyle(BoskeTheme.muted)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    if canExpandDomains {
                        FoldToggle(
                            isExpanded: false,
                            moreCount: server.coolifyDomains.count - domainPreviewCount
                        ) {
                            toggleSection(&domainsExpanded)
                        }
                    }
                }
                .font(.caption2)
                .contentShape(Rectangle())
                .onTapGesture {
                    if canExpandDomains {
                        toggleSection(&domainsExpanded)
                    }
                }
            }
        }
    }

    private func domainRow(_ domain: String) -> some View {
        HStack(spacing: 6) {
            CopyableValue(text: domain)
                .lineLimit(1)
            Spacer(minLength: 0)
            if onOpenURL != nil {
                Button {
                    onOpenURL?("https://\(domain)")
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                        .font(.caption2)
                        .foregroundStyle(BoskeTheme.accent)
                }
                .buttonStyle(.plain)
                .help("Open https://\(domain)")
            }
        }
        .font(.caption2)
    }

    @ViewBuilder
    private var containersSection: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 6) {
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

            if server.containers.isEmpty {
                Text(emptyContainersLabel)
                    .font(.caption2)
                    .foregroundStyle(BoskeTheme.dim)
                    .lineLimit(containersExpanded ? nil : (compact ? 2 : 3))
            } else if containersExpanded {
                ForEach(displayedContainers) { container in
                    ContainerRow(container: container, compact: compact, showFullDetails: true)
                }
                if canExpandContainers {
                    FoldToggle(isExpanded: true) {
                        toggleSection(&containersExpanded)
                    }
                }
            } else {
                ForEach(visibleContainers) { container in
                    ContainerRow(container: container, compact: compact, showFullDetails: false)
                }
                if canExpandContainers {
                    FoldToggle(isExpanded: false, moreCount: hiddenContainerCount) {
                        toggleSection(&containersExpanded)
                    }
                }
            }
        }
    }

    private var displayedContainers: [ContainerTile] {
        let source = compact
            ? server.containers.filter { $0.health != .skipped }
            : server.containers
        return source.sorted { lhs, rhs in
            if lhs.uncertainHealth != rhs.uncertainHealth { return lhs.uncertainHealth }
            if lhs.state.contains("degraded") != rhs.state.contains("degraded") {
                return lhs.state.contains("degraded")
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private var visibleContainers: [ContainerTile] {
        Array(displayedContainers.prefix(visibleContainerLimit))
    }

    private var hiddenContainerCount: Int {
        max(0, displayedContainers.count - visibleContainers.count)
    }

    private var emptyContainersLabel: String {
        if let role = config?.role, !role.isEmpty {
            return role
        }
        if config?.coolifyManaged == true {
            return "no Coolify services on this host"
        }
        return "compose stack (not in Coolify)"
    }
}

struct ContainerRow: View {
    let container: ContainerTile
    var compact: Bool = false
    var showFullDetails: Bool = false

    var body: some View {
        if showFullDetails {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(BoskeTheme.check(container.health))
                        .frame(width: 6, height: 6)
                    Text(container.name)
                        .font(.system(size: compact ? 10 : 11, design: .monospaced))
                        .foregroundStyle(BoskeTheme.text)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if container.uncertainHealth {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: compact ? 8 : 9))
                            .foregroundStyle(BoskeTheme.amber.opacity(0.85))
                            .help("Coolify health unknown")
                    } else if container.state.contains("degraded") {
                        Text("!")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(BoskeTheme.amber)
                    }
                    Spacer(minLength: 4)
                    Text(container.state)
                        .font(.caption2)
                        .foregroundStyle(BoskeTheme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
                if let type = container.image, !type.isEmpty {
                    Text(type)
                        .font(.caption2)
                        .foregroundStyle(BoskeTheme.dim)
                        .lineLimit(1)
                        .padding(.leading, 12)
                }
            }
        } else {
            HStack(spacing: 6) {
                Circle()
                    .fill(BoskeTheme.check(container.health))
                    .frame(width: 6, height: 6)
                Text(PulseDisplayNames.container(container.name, compact: compact))
                    .font(.system(size: compact ? 10 : 11, design: .monospaced))
                    .foregroundStyle(BoskeTheme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                    .help(container.name)
                if container.uncertainHealth {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: compact ? 8 : 9))
                        .foregroundStyle(BoskeTheme.amber.opacity(0.85))
                        .help("Coolify health unknown")
                } else if container.state.contains("degraded") {
                    Text("!")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(BoskeTheme.amber)
                        .help("Coolify service needs attention")
                }
                Spacer(minLength: 4)
                if !compact, let type = container.image, !type.isEmpty {
                    Text(type)
                        .font(.caption2)
                        .foregroundStyle(BoskeTheme.dim)
                        .lineLimit(1)
                        .frame(maxWidth: 72, alignment: .trailing)
                }
                Text(displayState(container.state))
                    .font(.caption2)
                    .foregroundStyle(BoskeTheme.muted)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }

    private func displayState(_ state: String) -> String {
        if state.hasSuffix(":unknown") { return "running" }
        if compact {
            if state.contains("degraded") { return "degraded" }
            if state == "compose" { return "compose" }
            if state.hasPrefix("running") { return "running" }
        }
        if state.count <= 16 { return state }
        return String(state.prefix(16))
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
            if value <= 0.005 { return "idle" }
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
            if value <= 0.005 { return 0.04 }
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
            if value <= 0.005 { return BoskeTheme.dim.opacity(0.5) }
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
