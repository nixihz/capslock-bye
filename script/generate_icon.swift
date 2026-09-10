import AppKit

// Package the approved artwork into transparent macOS icons.
// Re-run with `swift script/generate_icon.swift` from the project root.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Resources/AppIconSource.png")
guard let source = NSImage(contentsOf: sourceURL) else {
    fatalError("Cannot load \(sourceURL.path)")
}
source.size = NSSize(width: 1254, height: 1254)

// The approved image has a studio backdrop. Clip to the key's rounded outline
// while preserving the original glass, glyph, and wave pixels inside it.
// Coordinates use AppKit's bottom-left origin on the 1254 px source canvas.
let keyBounds = NSRect(x: 195, y: 404, width: 873, height: 484)
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high

        let p = CGFloat(pixels)
        let artworkScale = p * 0.9 / keyBounds.width
        let keySize = NSSize(width: p * 0.9, height: keyBounds.height * artworkScale)
        let destination = NSRect(
            x: (p - keySize.width) / 2, y: (p - keySize.height) / 2,
            width: keySize.width, height: keySize.height
        )
        let outline = NSBezierPath(
            roundedRect: destination,
            xRadius: 69 * artworkScale, yRadius: 69 * artworkScale
        )

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.17)
        shadow.shadowBlurRadius = p * 0.018
        shadow.shadowOffset = NSSize(width: 0, height: -p * 0.012)
        shadow.set()
        NSColor.white.setFill()
        outline.fill()
        NSGraphicsContext.restoreGraphicsState()

        outline.addClip()
        source.draw(in: destination, from: keyBounds, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()

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
