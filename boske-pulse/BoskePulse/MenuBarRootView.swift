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
            Divider()
            if let servers = model.snapshot?.servers {
                ForEach(servers) { server in
                    ServerRowView(server: server)
                        .contextMenu {
                            Button("Copy SSH") { model.copySSH(for: server.id) }
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
                Button("Coolify") { model.openCoolify() }
                Button("Hetzner") { model.openHetzner() }
                Spacer()
                Text(model.snapshot?.lastSync.formatted(date: .omitted, time: .standard) ?? "—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 380)
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
}

struct ServerRowView: View {
    let server: ServerSnapshot

    var body: some View {
        HStack(alignment: .top) {
            statusDot
            VStack(alignment: .leading, spacing: 2) {
                Text(server.name)
                    .font(.system(.body, design: .monospaced))
                if server.containersTotal > 0 {
                    Text("\(server.containersRunning)/\(server.containersTotal) containers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let latency = server.endpointChecks.first?.latencyMs {
                    Text("\(latency)ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let cpu = server.cpuPercent {
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
        switch server.overall {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return .gray
        }
    }
}
