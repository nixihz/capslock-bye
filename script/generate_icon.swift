import AppKit

// A native vector keycap mark. Re-run with `swift script/generate_icon.swift`.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let rect = NSRect(x: p * 0.055, y: p * 0.055, width: p * 0.89, height: p * 0.89)
        NSColor(red: 0.9, green: 0.94, blue: 0.9, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: p * 0.21, yRadius: p * 0.21).fill()
        let key = NSRect(x: p * 0.19, y: p * 0.205, width: p * 0.62, height: p * 0.62)
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.14)
        shadow.shadowBlurRadius = p * 0.04
        shadow.shadowOffset = NSSize(width: 0, height: -p * 0.02)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(red: 0.97, green: 0.98, blue: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: key, xRadius: p * 0.12, yRadius: p * 0.12).fill()
        NSGraphicsContext.restoreGraphicsState()
        if let symbol = NSImage(systemSymbolName: "capslock", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize: p * 0.34, weight: .medium)) {
            let tinted = NSImage(size: symbol.size)
            tinted.lockFocus()
            symbol.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1)
            NSColor(red: 0.19, green: 0.44, blue: 0.34, alpha: 1).setFill()
            NSRect(origin: .zero, size: symbol.size).fill(using: .sourceAtop)
            tinted.unlockFocus()
            let width = p * 0.38
            let height = width * symbol.size.height / symbol.size.width
            tinted.draw(in: NSRect(x: (p - width) / 2, y: (p - height) / 2, width: width, height: height))
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try bitmap.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(filename))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try task.run()
task.waitUntilExit()
if task.terminationStatus != 0 { exit(task.terminationStatus) }
