import AppKit
import BoskePulseCore
import SwiftUI

/// Renders the pulse mark for MenuBarExtra — SwiftUI shapes alone often don't appear in the label.
enum MenuBarIconRenderer {
    @MainActor
    static func image(for health: OverallHealth, tailscaleUp: Bool) -> NSImage {
        let color = nsColor(for: health, tailscaleUp: tailscaleUp)
        let size: CGFloat = 18
        let content = PulseMenuBarIcon(color: Color(color))
            .frame(width: size, height: size)
            .padding(2)

        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        renderer.isOpaque = false

        guard let cgImage = renderer.cgImage else {
            return fallbackImage(color: color, size: size)
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: size + 4, height: size + 4))
        image.isTemplate = false
        return image
    }

    private static func nsColor(for health: OverallHealth, tailscaleUp: Bool) -> NSColor {
        switch health {
        case .healthy: return .systemGreen
        case .degraded: return .systemYellow
        case .down: return .systemRed
        case .unknown: return tailscaleUp ? .labelColor : .systemOrange
        }
    }

    private static func fallbackImage(color: NSColor, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: size * 0.35, y: size * 0.35, width: size * 0.3, height: size * 0.3)).fill()
        image.unlockFocus()
        return image
    }
}

struct StatusMenuBarLabel: View {
    let overall: OverallHealth
    let tailscaleUp: Bool

    var body: some View {
        Image(nsImage: MenuBarIconRenderer.image(for: overall, tailscaleUp: tailscaleUp))
            .id("\(overall.rawValue)-\(tailscaleUp)")
            .accessibilityLabel("Boske Pulse")
            .help("Boske Pulse — \(overall.rawValue)")
    }
}

/// Pulse rings for menu bar bitmap + in-app headers (dark backgrounds).
struct PulseMenuBarIcon: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: 1.75)
                .opacity(0.4)
                .frame(width: 17, height: 17)
            Circle()
                .stroke(color, lineWidth: 1.75)
                .opacity(0.75)
                .frame(width: 11, height: 11)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
        .frame(width: 18, height: 18)
    }
}
