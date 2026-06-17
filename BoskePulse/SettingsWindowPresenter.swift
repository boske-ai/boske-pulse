import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPresenter {
    private static var window: NSWindow?

    static func show(model: AppModel) {
        let settingsView = SettingsView(model: model)
        if let window {
            window.contentViewController = NSHostingController(rootView: settingsView)
            present(window)
            return
        }

        let hosting = NSHostingController(rootView: settingsView)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Boske Pulse Settings"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.setContentSize(NSSize(width: 520, height: 480))
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window
        present(window)
    }

    private static func present(_ window: NSWindow) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
