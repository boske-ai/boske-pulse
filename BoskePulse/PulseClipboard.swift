import AppKit
import SwiftUI

enum PulseClipboard {
    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
            .help(copied ? "Copied!" : "Click to copy")
            .opacity(copied ? 0.55 : 1)
    }
}

extension View {
    func copyOnClick(_ value: String) -> some View {
        modifier(CopyOnClickModifier(value: value))
    }
}
