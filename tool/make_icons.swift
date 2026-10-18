// Renders the app and tray icons (macOS only; outputs are committed).
// Usage: swift tool/make_icons.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icons-out")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func png(_ size: Int, _ draw: (CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGFloat(size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

func symbol(_ pointSize: CGFloat, color: NSColor, in s: CGFloat) {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold).applying(.init(paletteColors: [color]))
    guard let img = NSImage(systemSymbolName: "hourglass", accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    img.draw(in: NSRect(x: (s - img.size.width) / 2, y: (s - img.size.height) / 2, width: img.size.width, height: img.size.height))
}

/// Gradient rounded square + white hourglass (same look as the SwiftUI app). `inset` 0.1 for app icons.
func appIcon(_ s: CGFloat, inset: CGFloat = 0.1) {
    let i = s * inset
    let rect = NSRect(x: i, y: i, width: s - 2 * i, height: s - 2 * i)
    let shape = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
    NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.27, blue: 0.95, alpha: 1),
                        NSColor(calibratedRed: 0.93, green: 0.30, blue: 0.56, alpha: 1)])!.draw(in: shape, angle: -55)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.22), NSColor.white.withAlphaComponent(0)])!.draw(in: shape, angle: -90)
    symbol(rect.width * 0.5, color: .white, in: s)
}

func write(_ data: Data, _ name: String) throws { try data.write(to: out.appendingPathComponent(name)) }

// Tray: macOS template (black + alpha, recolored by the system), Linux/Windows colored.
try write(png(36) { s in symbol(s * 0.62, color: .black, in: s) }, "tray_template.png")
try write(png(64) { s in appIcon(s, inset: 0.02) }, "tray_color.png")
for size in [16, 24, 32, 48, 64] { try write(png(size) { s in appIcon(s, inset: 0.02) }, "tray_\(size).png") }
// App icons.
for size in [16, 32, 48, 64, 72, 96, 128, 144, 192, 256, 512, 1024] { try write(png(size) { s in appIcon(s) }, "app_\(size).png") }
for size in [16, 24, 32, 48, 64, 256] { try write(png(size) { s in appIcon(s, inset: 0.04) }, "win_\(size).png") }
print("Wrote \(out.path)")
