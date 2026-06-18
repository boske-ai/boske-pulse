import AppKit
import SwiftUI

/// Keeps the menu bar popover, pinned compact window, and main dashboard from staying open together.
@MainActor
enum DashboardPresentation {
    static func openCompactWindow(model: AppModel) {
        closeMainWindow()
        dismissMenuBarPopover()
        CompactWindowPresenter.show(model: model)
    }

    static func openMainWindow(model: AppModel) {
        closeCompactWindow()
        dismissMenuBarPopover()
        ProductionWindowPresenter.show(model: model)
    }

    static func menuBarPopoverDidOpen() {
        closeMainWindow()
        closeCompactWindow()
    }

    static func closeCompactWindow() {
        CompactWindowPresenter.close()
    }

    static func closeMainWindow() {
        ProductionWindowPresenter.close()
    }

    static func dismissMenuBarPopover() {
        let owned: [NSWindow?] = [
            ProductionWindowPresenter.windowReference,
            CompactWindowPresenter.windowReference
        ]
        for window in NSApp.windows where window.isVisible && !owned.contains(where: { $0 === window }) && isMenuBarPopover(window) {
            window.orderOut(nil)
        }
    }

    private static func isMenuBarPopover(_ window: NSWindow) -> Bool {
        if window === CompactWindowPresenter.windowReference { return false }
        if window === ProductionWindowPresenter.windowReference { return false }
        if window.className.localizedCaseInsensitiveContains("Popover") { return true }
        if window.className.localizedCaseInsensitiveContains("StatusBar") { return true }
        let width = window.frame.width
        // MenuBarExtra popover is ~380px wide and not user-resizable.
        return width >= 370 && width <= 420 && !window.styleMask.contains(.resizable)
    }
}
