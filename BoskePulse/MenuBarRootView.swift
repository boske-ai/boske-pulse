import BoskePulseCore
import SwiftUI

struct MenuBarRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let configError = model.configError {
                Text(configError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            if !model.operatorHints.messages.isEmpty {
                hintsBanner
            }
            Divider()
            if let servers = model.snapshot?.servers {
                ForEach(servers) { server in
                    ServerRowView(
                        server: server,
                        role: model.serverConfig(for: server.id)?.role
                    )
                    .contextMenu {
                        Button("Copy SSH") { model.copySSH(for: server.id) }
                        Button("Open Hetzner") { model.openHetzner(for: server.id) }
                        if model.serverConfig(for: server.id)?.coolifyManaged == true {
                            Button("Open Coolify") { model.openCoolify(for: server.id) }
                        }
                        if !server.endpointChecks.isEmpty {
                            Divider()
                            ForEach(server.endpointChecks) { check in
                                if let url = model.serverConfig(for: server.id)?
                                    .publicEndpoints.first(where: { $0.id == check.id })?.url
                                {
                                    Button("Open \(check.label)") {
                                        model.openEndpoint(url)
                                    }
                                }
                            }
                        }
                    }
                }
            } else if model.configError == nil {
                Text(model.isRefreshing ? "Refreshing…" : "Syncing…")
                    .foregroundStyle(.secondary)
            }
            Divider()
            HStack {
                Button("Refresh") {
                    Task { await model.refreshNow() }
                }
                .disabled(model.isRefreshing || model.config == nil)
                SettingsLink {
                    Text("Settings…")
                }
                .buttonStyle(.plain)
                Button("Coolify") { model.openCoolify() }
                Button("Hetzner") { model.openHetzner() }
                Spacer()
                Text(model.snapshot?.lastSync.formatted(date: .omitted, time: .standard) ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 400)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("PRODUCTION")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(model.snapshot?.smokeSummary ?? "Awaiting first sync")
                .font(.headline)
            if let snap = model.snapshot {
                Text(snap.tailscaleConnected ? "Tailscale connected" : "Tailscale offline — public checks only")
                    .font(.caption)
                    .foregroundStyle(snap.tailscaleConnected ? .green : .orange)
            }
        }
    }

    private var hintsBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(model.operatorHints.messages, id: \.self) { message in
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct ServerRowView: View {
    let server: ServerSnapshot
    let role: String?

    var body: some View {
        HStack(alignment: .top) {
            statusDot
            VStack(alignment: .leading, spacing: 3) {
                Text(server.name)
                    .font(.system(.body, design: .monospaced))
                if let role {
                    Text(role)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ForEach(server.endpointChecks) { check in
                    HStack(spacing: 4) {
                        checkDot(check.status)
                        Text(check.label)
                        if let latency = check.latencyMs {
                            Text("\(latency)ms")
                                .foregroundStyle(.secondary)
                        }
                        Text(check.status.rawValue)
                            .foregroundStyle(checkColor(check.status))
                    }
                    .font(.caption2)
                }
                ForEach(server.privateProbes) { probe in
                    HStack(spacing: 4) {
                        checkDot(probe.status)
                        Text(probe.label)
                        Text(probe.status.rawValue)
                            .foregroundStyle(checkColor(probe.status))
                    }
                    .font(.caption2)
                }
                if server.containersTotal > 0 {
                    Text("\(server.containersRunning)/\(server.containersTotal) containers")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(server.containers) { container in
                        HStack(spacing: 4) {
                            checkDot(container.health)
                            Text(container.name)
                            Text(container.state)
                                .foregroundStyle(checkColor(container.health))
                        }
                        .font(.caption2)
                    }
                }
                if let cpu = server.cpuPercent, let ram = server.ramPercent {
                    Text(String(format: "CPU %.0f%% · RAM %.0f%%", cpu, ram))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if let cpu = server.cpuPercent {
                    Text(String(format: "CPU %.0f%%", cpu))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(server.overall.rawValue)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
        }
    }

    private var statusDot: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .padding(.top, 5)
    }

    private var color: Color {
        overallColor(server.overall)
    }

    private func checkDot(_ status: CheckStatus) -> some View {
        Circle()
            .fill(checkColor(status))
            .frame(width: 5, height: 5)
    }

    private func checkColor(_ status: CheckStatus) -> Color {
        switch status {
        case .ok: return .green
        case .warn: return .yellow
        case .fail: return .red
        case .skipped: return .gray
        }
    }

    private func overallColor(_ health: OverallHealth) -> Color {
        switch health {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
