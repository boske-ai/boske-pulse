import BoskePulseCore
import SwiftUI

@main
struct BoskePulseApp: App {
    @StateObject private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarRootView(model: appModel)
        } label: {
            StatusMenuBarLabel(
                overall: appModel.snapshot?.overall ?? .unknown,
                tailscaleUp: appModel.snapshot?.tailscaleConnected ?? false
            )
        }
        .menuBarExtraStyle(.window)
    }
}
