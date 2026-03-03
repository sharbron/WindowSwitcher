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

    // Draw ⌘⇥ symbol in the bottom right corner (within usable area)
    let symbolSize = usableSize * 0.25
    let symbolX = inset + usableSize - symbolSize - usableSize * 0.12
    let symbolY = inset + usableSize * 0.12

    // Create background circle for the symbol
    let symbolCircleRect = CGRect(x: symbolX - symbolSize * 0.15,
                                 y: symbolY - symbolSize * 0.15,
                                 width: symbolSize * 1.3,
                                 height: symbolSize * 1.3)
    let symbolCirclePath = NSBezierPath(ovalIn: symbolCircleRect)
    NSColor(white: 0.0, alpha: 0.4).setFill()
    symbolCirclePath.fill()

    // Draw ⌘⇥ text
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: symbolSize * 0.9, weight: .medium),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraphStyle
    ]

    let symbolText = "⌘⇥"
    let symbolRect = CGRect(x: symbolX, y: symbolY, width: symbolSize, height: symbolSize)
    symbolText.draw(in: symbolRect, withAttributes: attributes)

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

let iconsDir = "AppIcon.iconset"
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
process.arguments = ["-c", "icns", iconsDir, "-o", "AppIcon.icns"]

do {
    try process.run()
    process.waitUntilExit()

    if process.terminationStatus == 0 {
        print("✓ Generated AppIcon.icns")

        // Clean up iconset directory
        try? fileManager.removeItem(atPath: iconsDir)

        // Set DPI to 72 for the .icns file to match other macOS app icons
        let sipsProcess = Process()
        sipsProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        sipsProcess.arguments = ["-s", "dpiWidth", "72", "-s", "dpiHeight", "72", "AppIcon.icns"]
        sipsProcess.standardOutput = FileHandle.nullDevice
        sipsProcess.standardError = FileHandle.nullDevice
        try? sipsProcess.run()
        sipsProcess.waitUntilExit()

        print("\n✅ Icon generation complete!")
        print("📁 AppIcon.icns has been created")
        print("\nTo use this icon:")
        print("1. Add AppIcon.icns to your Xcode project")
        print("2. Update Info.plist with: <key>CFBundleIconFile</key><string>AppIcon</string>")
        print("3. Rebuild your app")
    } else {
        print("❌ iconutil failed with status: \(process.terminationStatus)")
        exit(1)
    }
} catch {
    print("❌ Failed to run iconutil: \(error)")
    exit(1)
}
