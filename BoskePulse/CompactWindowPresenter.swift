import AppKit
import SwiftUI

/// Pinned small dashboard window (420px). Fully interactive — not a non-activating panel.
@MainActor
enum CompactWindowPresenter {
    private static var window: NSWindow?

    static var windowReference: NSWindow? { window }

    static func show(model: AppModel) {
        let dashboard = CompactDashboardRootView(model: model)
        if let window {
            window.contentViewController = NSHostingController(rootView: dashboard)
            present(window)
            return
        }

        let hosting = NSHostingController(rootView: dashboard)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Boske Pulse"
        window.backgroundColor = NSColor(red: 0.055, green: 0.065, blue: 0.08, alpha: 1)
        window.titlebarAppearsTransparent = true
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.minSize = NSSize(width: PulseLayout.popoverWidth, height: 420)
        window.maxSize = NSSize(width: PulseLayout.popoverWidth, height: 900)
        window.setContentSize(NSSize(width: PulseLayout.popoverWidth, height: 720))
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

struct CompactDashboardRootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ProductionDashboardView(model: model, style: .menuBar, surface: .pinnedWindow)
            .frame(width: PulseLayout.popoverWidth, height: 720)
            .background(BoskeTheme.background)
            .preferredColorScheme(.dark)
    }
}
