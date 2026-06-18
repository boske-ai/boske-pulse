import AppKit
import BoskePulseCore
import SwiftUI

enum PulseClipboard {
    static func copy(_ text: String, clearAfterSeconds: TimeInterval? = SecurityPolicy.pasteboardClearDelaySeconds) {
        guard let sanitized = SecurityPolicy.sanitizedClipboardText(text) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(sanitized, forType: .string)

        guard let delay = clearAfterSeconds, delay > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if NSPasteboard.general.string(forType: .string) == sanitized {
                NSPasteboard.general.clearContents()
            }
        }
    }
}

private struct CopyOnClickModifier: ViewModifier {
    let value: String
    @State private var copied = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture {
                PulseClipboard.copy(value)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    copied = false
                }
            }
            .help(copied ? "Copied!" : "Click to copy — paste into an SSH client, not Terminal")
            .opacity(copied ? 0.55 : 1)
    }
}

extension View {
    func copyOnClick(_ value: String) -> some View {
        modifier(CopyOnClickModifier(value: value))
    }
}

/// Short label that copies its value on click (IP, SSH, URLs, etc.).
struct CopyableValue: View {
    let text: String
    var font: Font = .caption2
    var color: Color = BoskeTheme.muted

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .copyOnClick(text)
    }
}
