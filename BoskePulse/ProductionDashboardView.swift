import BoskePulseCore
import SwiftUI

struct ProductionDashboardView: View {
    enum Style {
        case menuBar
        case window
    }

    enum Surface {
        case menuBarPopover
        case pinnedWindow
    }

    @ObservedObject var model: AppModel
    let style: Style
    var surface: Surface = .menuBarPopover

    private var isWindow: Bool { style == .window }

    var body: some View {
        Group {
            if isWindow {
                windowLayout
            } else {
                menuBarLayout
            }
        }
    }

    private var windowLayout: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    dashboardHeader(expanded: true)
                    alertsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)

                serverGrid(columns: PulseLayout.windowColumns, compact: false)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(BoskeTheme.background)
        .preferredColorScheme(.dark)
    }

    private var menuBarLayout: some View {
        VStack(spacing: 0) {
            compactTopBar
            DividerLine()

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    alertsSection
                    serverGrid(columns: PulseLayout.menuBarColumns, compact: true)
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .frame(width: PulseLayout.popoverWidth - 24)
            }

            DividerLine()
            menuBarFooter
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(BoskeTheme.background)
        }
        .frame(width: PulseLayout.popoverWidth)
        .frame(minHeight: 440, maxHeight: 740)
        .background(BoskeTheme.background)
        .preferredColorScheme(.dark)
    }

    private var compactTopBar: some View {
        dashboardHeader(expanded: false)
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(BoskeTheme.background)
    }

    @ViewBuilder
    private func dashboardHeader(expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ProductionHeaderView(
                snapshot: model.snapshot,
                serverCount: model.snapshot?.servers.count ?? 0,
                isRefreshing: model.isRefreshing,
                expanded: expanded
            )
            if let summary = model.operatorHints.discoverySummary, isWindow {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(BoskeTheme.dim)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var alertsSection: some View {
        if let configError = model.configError {
            alertBanner(configError, tint: BoskeTheme.red)
        } else if model.operatorHints.messages.contains(where: { !isTailscaleNoise($0) }) {
            alertBanner(
                model.operatorHints.messages.first(where: { !isTailscaleNoise($0) }) ?? "",
                tint: BoskeTheme.amber
            )
        }
    }

    @ViewBuilder
    private func serverGrid(columns: Int, compact: Bool) -> some View {
        if let servers = model.snapshot?.servers, !servers.isEmpty {
            let gridItems = Array(repeating: GridItem(.flexible(), spacing: compact ? 10 : 12), count: columns)
            LazyVGrid(columns: gridItems, spacing: compact ? 10 : 12) {
                ForEach(servers) { server in
                    PulseServerTile(
                        server: server,
                        config: model.serverConfig(for: server.id),
                        compact: compact,
                        onOpenURL: { model.openEndpoint($0) }
                    )
                    .contextMenu { serverContextMenu(for: server) }
                }
            }
        } else if model.snapshot?.servers.isEmpty == true {
            emptyState(title: "No servers", subtitle: "Save credentials and refresh")
        } else if model.configError == nil {
            emptyState(
                title: model.isRefreshing ? "Refreshing…" : "Syncing",
                subtitle: "Connecting to Coolify and Hetzner"
            )
        }
    }

    private var menuBarFooter: some View {
        HStack(spacing: 14) {
            if surface == .menuBarPopover {
                footerLink("Pin") { DashboardPresentation.openCompactWindow(model: model) }
            }
            footerLink("Full") { DashboardPresentation.openMainWindow(model: model) }
            footerLink("Refresh") { Task { await model.refreshNow() } }
                .disabled(model.isRefreshing || model.config == nil)
            footerLink("Settings") { SettingsWindowPresenter.show(model: model) }
            Spacer()
        }
        .font(.caption)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(BoskeTheme.accent)
    }

    @ViewBuilder
    private func serverContextMenu(for server: ServerSnapshot) -> some View {
        Button("Copy server summary") { model.copyServerSummary(for: server.id) }
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
                    Button("Open \(check.label)") { model.openEndpoint(url) }
                }
            }
        }
        if !server.coolifyDomains.isEmpty {
            Divider()
            ForEach(server.coolifyDomains, id: \.self) { domain in
                Button("Open \(domain)") { model.openEndpoint("https://\(domain)/") }
            }
        }
    }

    private func isTailscaleNoise(_ message: String) -> Bool {
        message.localizedCaseInsensitiveContains("tailscale")
    }

    private func alertBanner(_ text: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            Text(text)
                .font(.caption)
                .lineLimit(isWindow ? 2 : 1)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func emptyState(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(BoskeTheme.text)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(BoskeTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}
