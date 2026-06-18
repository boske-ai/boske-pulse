import AppKit
import SwiftUI

@MainActor
enum ProductionWindowPresenter {
    private static var window: NSWindow?

    static var windowReference: NSWindow? { window }

    static func show(model: AppModel) {
        let dashboard = ProductionMainWindowView(model: model)
        if let window {
            window.contentViewController = NSHostingController(rootView: dashboard)
            present(window)
            return
        }

        let hosting = NSHostingController(rootView: dashboard)
        let window = NSWindow(contentViewController: hosting)
        window.title = "boske/pulse · production"
        window.backgroundColor = NSColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.minSize = NSSize(width: 960, height: 620)
        window.setContentSize(NSSize(width: 1060, height: 760))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        present(window)
    }

    static func close() {
        window?.orderOut(nil)
    }

    private static func present(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct ProductionMainWindowView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ProductionDashboardView(model: model, style: .window)
            .frame(minWidth: 960, minHeight: 620)
            .background(BoskeTheme.background)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        Task { await model.refreshNow() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(model.isRefreshing || model.config == nil)

                    Button {
                        SettingsWindowPresenter.show(model: model)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }

                    Menu {
                        Button("Pin compact window") { DashboardPresentation.openCompactWindow(model: model) }
                        Button("Open Coolify") { model.openCoolify() }
                        Button("Open Hetzner") { model.openHetzner() }
                    } label: {
                        Label("Links", systemImage: "link")
                    }
                }
            }
    }
}
