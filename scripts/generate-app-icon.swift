#!/usr/bin/env swift

import AppKit
import Foundation

private let canvas: CGFloat = 1024

private func renderIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw IconError.renderingContext
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    context.cgContext.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)

    let card = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 210, yRadius: 210)
    NSGradient(colors: [
        NSColor(red: 0.055, green: 0.105, blue: 0.20, alpha: 1),
        NSColor(red: 0.07, green: 0.20, blue: 0.31, alpha: 1),
    ])?.draw(in: card, angle: -45)
    NSColor(red: 0.20, green: 0.55, blue: 0.77, alpha: 0.35).setStroke()
    card.lineWidth = 10
    card.stroke()

    let inset = NSBezierPath(roundedRect: NSRect(x: 90, y: 90, width: 844, height: 844), xRadius: 178, yRadius: 178)
    NSColor.white.withAlphaComponent(0.045).setStroke()
    inset.lineWidth = 5
    inset.stroke()

    let center = NSPoint(x: 512, y: 520)
    let ringBase = NSBezierPath()
    ringBase.appendArc(withCenter: center, radius: 270, startAngle: 0, endAngle: 360)
    ringBase.lineWidth = 76
    ringBase.lineCapStyle = .round
    NSColor(red: 0.22, green: 0.34, blue: 0.43, alpha: 0.72).setStroke()
    ringBase.stroke()

    let ringValue = NSBezierPath()
    ringValue.appendArc(withCenter: center, radius: 270, startAngle: 112, endAngle: -150, clockwise: true)
    ringValue.lineWidth = 76
    ringValue.lineCapStyle = .round
    NSColor(red: 0.08, green: 0.82, blue: 0.83, alpha: 1).setStroke()
    ringValue.stroke()

    let pulse = NSBezierPath()
    pulse.move(to: NSPoint(x: 214, y: 515))
    pulse.line(to: NSPoint(x: 340, y: 515))
    pulse.line(to: NSPoint(x: 404, y: 635))
    pulse.line(to: NSPoint(x: 482, y: 365))
    pulse.line(to: NSPoint(x: 560, y: 590))
    pulse.line(to: NSPoint(x: 623, y: 485))
    pulse.line(to: NSPoint(x: 805, y: 485))
    pulse.lineCapStyle = .round
    pulse.lineJoinStyle = .round
    pulse.lineWidth = 72
    NSColor(red: 0.035, green: 0.10, blue: 0.18, alpha: 0.88).setStroke()
    pulse.stroke()
    pulse.lineWidth = 42
    NSColor(red: 0.18, green: 0.69, blue: 1.0, alpha: 1).setStroke()
    pulse.stroke()

    let node = NSBezierPath(ovalIn: NSRect(x: 456, y: 339, width: 52, height: 52))
    NSColor(red: 0.16, green: 0.93, blue: 0.83, alpha: 1).setFill()
    node.fill()

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.pngEncoding
    }
    return data
}

private func generateAssets(in assetsDirectory: URL) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: assetsDirectory, withIntermediateDirectories: true)

    let temporaryRoot = fileManager.temporaryDirectory
        .appendingPathComponent("cpa-monitor-icon-\(UUID().uuidString)")
    let iconset = temporaryRoot.appendingPathComponent("CPAMonitorBar.iconset")
    try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: temporaryRoot) }

    let representations = [
        ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
    ]
    for (name, size) in representations {
        try renderIcon(size: size).write(to: iconset.appendingPathComponent(name))
    }

    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = [
        "-c", "icns", "-o",
        assetsDirectory.appendingPathComponent("AppIcon.icns").path,
        iconset.path,
    ]
    try iconutil.run()
    iconutil.waitUntilExit()
    guard iconutil.terminationStatus == 0 else { throw IconError.iconutil }
}

private enum IconError: Error {
    case renderingContext, pngEncoding, iconutil
}

let output = CommandLine.arguments.dropFirst().first ?? "Assets"
try generateAssets(in: URL(fileURLWithPath: output, isDirectory: true))
print("Generated \(output)/AppIcon.icns")
