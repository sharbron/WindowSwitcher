#!/usr/bin/env swift

import Foundation
import AppKit
import CoreGraphics

// Generate app icon with overlapping windows design
func generateIcon(size: CGFloat) -> NSImage {
    // Create bitmap with proper pixel dimensions
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        return NSImage(size: NSSize(width: size, height: size))
    }

    // Set the bitmap's size to match pixel dimensions (72 DPI)
    bitmapRep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)

    guard let context = NSGraphicsContext.current?.cgContext else {
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: size, height: size))
        image.addRepresentation(bitmapRep)
        return image
    }

    // Background - rounded square with gradient
    // Add inset margins (96px on 1024px canvas = 9.375% margin)
    // This prevents the icon from appearing too large compared to other macOS apps
    let inset = size * 0.09375
    let usableSize = size - (inset * 2)
    let backgroundRect = CGRect(x: inset, y: inset, width: usableSize, height: usableSize)
    // Corner radius is ~22% of the usable size
    let cornerRadius = usableSize * 0.22

    // Create gradient background
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let gradientColors = [
        NSColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0).cgColor,
        NSColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1.0).cgColor
    ] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: [0.0, 1.0])!

    context.saveGState()
    let backgroundPath = NSBezierPath(roundedRect: backgroundRect, xRadius: cornerRadius, yRadius: cornerRadius)
    backgroundPath.addClip()
    context.drawLinearGradient(gradient,
                              start: CGPoint(x: 0, y: size),
                              end: CGPoint(x: size, y: 0),
                              options: [])
    context.restoreGState()

    // Calculate dimensions for the window rectangles within the usable area
    let padding = usableSize * 0.2 + inset
    let windowWidth = usableSize * 0.45
    let windowHeight = usableSize * 0.35
    let windowRadius = usableSize * 0.08
    let offset = usableSize * 0.12

    // Draw three overlapping windows to represent window switching
    let windows = [
        CGRect(x: padding, y: padding + offset * 2, width: windowWidth, height: windowHeight),
        CGRect(x: padding + offset, y: padding + offset, width: windowWidth, height: windowHeight),
        CGRect(x: padding + offset * 2, y: padding, width: windowWidth, height: windowHeight)
    ]

    // Colors for windows (back to front)
    let windowColors = [
        NSColor(white: 0.9, alpha: 0.5),
        NSColor(white: 0.95, alpha: 0.7),
        NSColor.white.withAlphaComponent(0.9)
    ]

    // Draw windows from back to front
    for (index, windowRect) in windows.enumerated() {
        context.saveGState()

        // Window fill
        let windowPath = NSBezierPath(roundedRect: windowRect, xRadius: windowRadius, yRadius: windowRadius)
        windowColors[index].setFill()
        windowPath.fill()

        // Window border
        NSColor(white: 0.3, alpha: 0.3).setStroke()
        windowPath.lineWidth = size * 0.01
        windowPath.stroke()

        // Title bar for the front window
        if index == 2 {
            let titleBarHeight = windowHeight * 0.25
            let titleBarRect = CGRect(x: windowRect.origin.x,
                                     y: windowRect.origin.y + windowHeight - titleBarHeight,
                                     width: windowWidth,
                                     height: titleBarHeight)

            let titleBarPath = NSBezierPath()
            titleBarPath.move(to: CGPoint(x: titleBarRect.minX + windowRadius, y: titleBarRect.minY))
            titleBarPath.line(to: CGPoint(x: titleBarRect.maxX - windowRadius, y: titleBarRect.minY))
            titleBarPath.line(to: CGPoint(x: titleBarRect.maxX, y: titleBarRect.maxY - windowRadius))
            titleBarPath.appendArc(withCenter: CGPoint(x: titleBarRect.maxX - windowRadius, y: titleBarRect.maxY - windowRadius),
                                  radius: windowRadius, startAngle: 0, endAngle: 90)
            titleBarPath.line(to: CGPoint(x: titleBarRect.minX + windowRadius, y: titleBarRect.maxY))
            titleBarPath.appendArc(withCenter: CGPoint(x: titleBarRect.minX + windowRadius, y: titleBarRect.maxY - windowRadius),
                                  radius: windowRadius, startAngle: 90, endAngle: 180)
            titleBarPath.close()

            NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.6).setFill()
            titleBarPath.fill()

            // Draw traffic lights
            let dotSize = size * 0.025
            let dotY = titleBarRect.midY
            let startX = titleBarRect.minX + size * 0.05

            let colors = [
                NSColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 0.8),
                NSColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 0.8),
                NSColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 0.8)
            ]

            for (i, color) in colors.enumerated() {
                let dotX = startX + CGFloat(i) * (dotSize * 2)
                let dotRect = CGRect(x: dotX, y: dotY - dotSize / 2, width: dotSize, height: dotSize)
                let dotPath = NSBezierPath(ovalIn: dotRect)
                color.setFill()
                dotPath.fill()
            }
        }

        context.restoreGState()
    }

    // Shortcut badge, bottom right of the artwork.
    //
    // The badge is sized from the *measured* text. It used to draw "⌘⇥" into a square box
    // scaled for a single glyph — the string measured 360pt wide against a 208pt box, so
    // `draw(in:)` clipped the ⇥ away entirely and the shipped icon showed a lone ⌘.
    let symbolText = "⌘⇥"
    let badgeFont = NSFont.systemFont(ofSize: usableSize * 0.14, weight: .semibold)
    let textAttributes: [NSAttributedString.Key: Any] = [
        .font: badgeFont,
        .foregroundColor: NSColor.white
    ]
    let textSize = (symbolText as NSString).size(withAttributes: textAttributes)

    let badgePaddingX = usableSize * 0.05
    let badgePaddingY = usableSize * 0.028
    let badgeWidth = textSize.width + badgePaddingX * 2
    let badgeHeight = textSize.height + badgePaddingY * 2
    let badgeRect = CGRect(
        x: inset + usableSize - badgeWidth - usableSize * 0.07,
        y: inset + usableSize * 0.09,
        width: badgeWidth,
        height: badgeHeight
    )

    // Opaque, so the badge reads as one deliberate shape. At 40% black it took its colour
    // from whatever sat behind it — neutral grey over the white window, dark navy over the
    // background gradient — which read as two overlapping shapes rather than one badge.
    let badgePath = NSBezierPath(roundedRect: badgeRect,
                                 xRadius: badgeHeight / 2,
                                 yRadius: badgeHeight / 2)
    NSColor(red: 0.05, green: 0.15, blue: 0.38, alpha: 1.0).setFill()
    badgePath.fill()

    // draw(at:) rather than draw(in:) so the glyphs can never be silently clipped again.
    let textOrigin = CGPoint(x: badgeRect.midX - textSize.width / 2,
                             y: badgeRect.midY - textSize.height / 2)
    (symbolText as NSString).draw(at: textOrigin, withAttributes: textAttributes)

    NSGraphicsContext.restoreGraphicsState()

    // Create final NSImage and add the bitmap representation
    let image = NSImage(size: NSSize(width: size, height: size))
    image.addRepresentation(bitmapRep)
    return image
}

// Save image as PNG at specific size
func saveIconImage(_ image: NSImage, size: Int, filename: String) -> Bool {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        print("Failed to create PNG data for \(filename)")
        return false
    }

    // Explicitly set DPI to 72 (standard for macOS icons)
    bitmap.size = NSSize(width: size, height: size)

    // Create PNG with explicit DPI metadata
    let pngProperties: [NSBitmapImageRep.PropertyKey: Any] = [
        .compressionFactor: 1.0
    ]

    guard let pngData = bitmap.representation(using: .png, properties: pngProperties) else {
        print("Failed to create PNG data for \(filename)")
        return false
    }

    let url = URL(fileURLWithPath: filename)
    do {
        try pngData.write(to: url)
        print("✓ Generated \(filename)")
        return true
    } catch {
        print("Failed to write \(filename): \(error)")
        return false
    }
}

// Main execution
print("Generating WindowSwitcher app icon...")

// Write straight to where SwiftPM picks the icon up. Previously the .icns landed in the
// current directory and had to be moved by hand, which is easy to forget.
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Sources/WindowSwitcher/AppIcon.icns"

let iconsDir = NSTemporaryDirectory() + "AppIcon.iconset"
let fileManager = FileManager.default

// Create iconset directory
if fileManager.fileExists(atPath: iconsDir) {
    try? fileManager.removeItem(atPath: iconsDir)
}

do {
    try fileManager.createDirectory(atPath: iconsDir, withIntermediateDirectories: true)
} catch {
    print("Failed to create directory: \(error)")
    exit(1)
}

// Generate all required icon sizes for macOS
let sizes = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

var allSuccessful = true
for (size, filename) in sizes {
    let image = generateIcon(size: CGFloat(size))
    let path = "\(iconsDir)/\(filename)"
    if !saveIconImage(image, size: size, filename: path) {
        allSuccessful = false
    }
}

if !allSuccessful {
    print("\n⚠️  Some icons failed to generate")
    exit(1)
}

// Convert iconset to icns using iconutil
print("\nConverting to .icns format...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsDir, "-o", outputPath]

do {
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("✓ Generated \(outputPath)")

        // Clean up iconset directory
        try? fileManager.removeItem(atPath: iconsDir)

        // Set DPI to 72 for the .icns file to match other macOS app icons
        let sipsProcess = Process()
        sipsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        sipsProcess.arguments = ["-s", "dpiWidth", "72", "-s", "dpiHeight", "72", outputPath]
        sipsProcess.standardOutput = FileHandle.nullDevice
        sipsProcess.standardError = FileHandle.nullDevice
        try? sipsProcess.run()
        sipsProcess.waitUntilExit()

        print("\n✅ Icon generation complete: \(outputPath)")
        print("   Run ./create_app.sh to rebuild the bundle with it.")
    } else {
        print("❌ iconutil failed with status: \(process.terminationStatus)")
        exit(1)
    }
} catch {
    print("❌ Failed to run iconutil: \(error)")
    exit(1)
}
