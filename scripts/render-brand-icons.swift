#!/usr/bin/env swift
import AppKit
import SwiftUI

private enum Brand {
    static let background = Color(red: 0.07, green: 0.08, blue: 0.10)
    static let accent = Color(red: 0.22, green: 0.84, blue: 0.60)
}

private struct PulseMark: View {
    let color: Color
    let diameter: CGFloat
    let strokeWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color, lineWidth: strokeWidth)
                .opacity(0.4)
                .frame(width: diameter, height: diameter)
            Circle()
                .stroke(color, lineWidth: strokeWidth)
                .opacity(0.75)
                .frame(width: diameter * 0.65, height: diameter * 0.65)
            Circle()
                .fill(color)
                .frame(width: diameter * 0.35, height: diameter * 0.35)
        }
    }
}

private struct AppIconView: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1024 * 0.223, style: .continuous)
                .fill(Brand.background)
            PulseMark(color: Brand.accent, diameter: 520, strokeWidth: 22)
        }
        .frame(width: 1024, height: 1024)
    }
}

private struct PulseLogoView: View {
    let canvas: CGFloat

    var body: some View {
        PulseMark(color: Brand.accent, diameter: canvas * 0.82, strokeWidth: max(1.5, canvas * 0.06))
            .frame(width: canvas, height: canvas)
    }
}

@MainActor
private func writePNG<V: View>(_ view: V, size: CGFloat, url: URL, opaque: Bool) throws {
    let renderer = ImageRenderer(content: view.frame(width: size, height: size))
    renderer.scale = 1
    renderer.isOpaque = opaque
    guard let cgImage = renderer.cgImage else {
        throw NSError(domain: "RenderBrandIcons", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to render \(url.lastPathComponent)"])
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RenderBrandIcons", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to encode PNG \(url.lastPathComponent)"])
    }
    try data.write(to: url, options: .atomic)
}

@MainActor
private func renderAll(root: URL) throws {
    let appIconDir = root.appendingPathComponent("BoskePulse/Assets.xcassets/AppIcon.appiconset")
    let pulseLogoDir = root.appendingPathComponent("BoskePulse/Assets.xcassets/PulseLogo.imageset")
    let widgetLogoDir = root.appendingPathComponent("BoskePulseWidget/Assets.xcassets/PulseLogo.imageset")

    for size in [16, 32, 64, 128, 256, 512, 1024] {
        let side = CGFloat(size)
        try writePNG(
            AppIconView(),
            size: side,
            url: appIconDir.appendingPathComponent("icon_\(size)x\(size).png"),
            opaque: true
        )
    }

    for (size, name) in [(32, "logo_32.png"), (64, "logo_64.png")] {
        let side = CGFloat(size)
        let logo = PulseLogoView(canvas: side)
        try writePNG(logo, size: side, url: pulseLogoDir.appendingPathComponent(name), opaque: false)
        try writePNG(logo, size: side, url: widgetLogoDir.appendingPathComponent(name), opaque: false)
    }

    print("✓ Rendered AppIcon + PulseLogo assets")
}

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try await MainActor.run {
    try renderAll(root: root)
}
