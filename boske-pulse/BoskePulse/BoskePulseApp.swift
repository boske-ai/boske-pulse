import BoskePulseCore
import SwiftUI

@main
struct BoskePulseApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(model: appModel)
        } label: {
            StatusMenuBarLabel(overall: appModel.snapshot?.overall ?? .unknown, tailscaleUp: appModel.snapshot?.tailscaleConnected ?? false)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: appModel)
        }
    }
}

struct StatusMenuBarLabel: View {
    let overall: OverallHealth
    let tailscaleUp: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("Boske")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .help(tailscaleUp ? "Tailscale connected" : "Tailscale offline — public checks only")
    }

    private var color: Color {
        switch overall {
        case .healthy: return .green
        case .degraded: return .yellow
        case .down: return .red
        case .unknown: return tailscaleUp ? .gray : .orange
        }
    }
}
