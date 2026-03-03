import SwiftUI
import AppKit

struct WindowSwitcherView: View {
    let windows: [WindowInfo]
    let selectedIndex: Int
    let onSelect: (WindowInfo) -> Void

    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200
    @AppStorage("maxWindowsToShow") private var maxWindowsToShow: Double = 20

    private var thumbnailWidth: CGFloat {
        CGFloat(thumbnailSize)
    }

    private var thumbnailHeight: CGFloat {
        CGFloat(thumbnailSize * 0.75) // Maintain 4:3 aspect ratio
    }

    private var displayWindows: [WindowInfo] {
        let maxCount = Int(maxWindowsToShow)
        return Array(windows.prefix(maxCount))
    }

    // Pre-compute window numbers to avoid O(n²) performance issue
    private var windowNumbers: [CGWindowID: Int] {
        var numbers: [CGWindowID: Int] = [:]
        var appCounts: [String: Int] = [:]

        // First pass: count windows per app
        for window in displayWindows {
            appCounts[window.appName, default: 0] += 1
        }

        // Second pass: assign numbers only if multiple windows from same app
        var appIndices: [String: Int] = [:]
        for window in displayWindows where appCounts[window.appName, default: 0] > 1 {
            let index = appIndices[window.appName, default: 0]
            numbers[window.id] = index + 1
            appIndices[window.appName] = index + 1
        }

        return numbers
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                // Background with rounded corners - behind everything
                VisualEffectBlur(material: .menu, blendingMode: .behindWindow, cornerRadius: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Content on top
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(Array(displayWindows.enumerated()), id: \.element.id) { index, window in
                            WindowThumbnailView(
                                window: window,
                                isSelected: index == selectedIndex,
                                thumbnailWidth: thumbnailWidth,
                                thumbnailHeight: thumbnailHeight,
                                windowNumber: windowNumbers[window.id]
                            )
                            .id(window.id)
                            .onTapGesture {
                                onSelect(window)
                            }
                        }
                    }
                    .padding(32)
                }
            }
            .frame(maxWidth: maxSwitcherWidth)
            .compositingGroup()
            .shadow(color: .black.opacity(0.6), radius: 50, x: 0, y: 15)
            .onChange(of: selectedIndex) { newIndex in
                if newIndex < displayWindows.count {
                    // Scroll immediately without delay to prevent queuing issues
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(displayWindows[newIndex].id, anchor: .center)
                    }
                }
            }
            .onAppear {
                if selectedIndex < displayWindows.count {
                    // Initial scroll without animation or delay
                    proxy.scrollTo(displayWindows[selectedIndex].id, anchor: .center)
                }
            }
        }
    }

    private var maxSwitcherWidth: CGFloat {
        // Get screen width and limit switcher to 90% of screen width
        guard let screen = NSScreen.main else { return 1200 }
        return screen.visibleFrame.width * 0.9
    }
}

struct WindowThumbnailView: View {
    let window: WindowInfo
    let isSelected: Bool
    let thumbnailWidth: CGFloat
    let thumbnailHeight: CGFloat
    let windowNumber: Int?

    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            // Window Thumbnail
            ZStack {
                // Blurred background for thumbnail (clipped to rounded rect)
                VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, cornerRadius: 8)
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if let thumbnail = window.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .scaledToFit()
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(isUsingAppIconsMode() ? 16 : 0)
                } else {
                    VStack {
                        Image(systemName: "hourglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                }

                // App icon overlay in bottom-left corner (only when showing window previews)
                if !isUsingAppIconsMode(), let appIcon = getAppIcon() {
                    VStack {
                        Spacer()
                        HStack {
                            Image(nsImage: appIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.95))
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                )
                                .cornerRadius(6)
                                .padding(8)
                            Spacer()
                        }
                    }
                }
            }
            .frame(width: thumbnailWidth, height: thumbnailHeight)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )

            // App name and window title
            if showWindowTitles {
                VStack(spacing: 4) {
                    Text(window.appName)
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)

                    // Show window title if it exists and is different from app name
                    if !window.title.isEmpty && window.title != window.appName {
                        Text(window.title)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } else if let number = windowNumber {
                        // Show window number if multiple windows from same app
                        Text("Window \(number)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        // Empty text to maintain consistent height
                        Text(" ")
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }
                .frame(width: thumbnailWidth, height: 36, alignment: .top)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
    }

    private func getAppIcon() -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            return nil
        }
        return app.icon
    }

    private func isUsingAppIconsMode() -> Bool {
        return UserDefaults.standard.bool(forKey: "useAppIcons")
    }
}

class SwitcherWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]
        self.isMovableByWindowBackground = false
        self.ignoresMouseEvents = false
        self.hasShadow = false // Disable window shadow - we use view-level shadow instead
        self.titlebarAppearsTransparent = true
    }

    /// Centers the window on the main screen, both horizontally and vertically
    func centerOnScreen() {
        guard let screen = NSScreen.main else {
            center() // Fallback to default centering
            return
        }

        let screenFrame = screen.visibleFrame
        let windowFrame = frame

        let x = screenFrame.origin.x + (screenFrame.width - windowFrame.width) / 2
        let y = screenFrame.origin.y + (screenFrame.height - windowFrame.height) / 2

        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// Native macOS visual effect blur view wrapper
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var cornerRadius: CGFloat = 0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true

        // Configure layer for proper corner radius clipping
        if let layer = view.layer {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = true
            layer.cornerCurve = .continuous
            layer.allowsEdgeAntialiasing = true
        }

        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode

        // Update corner radius if changed
        if let layer = nsView.layer {
            layer.cornerRadius = cornerRadius
            layer.masksToBounds = true
            layer.cornerCurve = .continuous
            layer.allowsEdgeAntialiasing = true
        }
    }
}
