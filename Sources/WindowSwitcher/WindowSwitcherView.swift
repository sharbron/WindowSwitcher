import SwiftUI
import AppKit

struct WindowSwitcherView: View {
    let windows: [WindowInfo]
    let selectedIndex: Int
    let onSelect: (WindowInfo) -> Void
    let searchQuery: String
    let onCloseWindow: ((WindowInfo) -> Void)?
    let onMinimizeWindow: ((WindowInfo) -> Void)?

    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200
    @AppStorage("maxWindowsToShow") private var maxWindowsToShow: Double = 20
    @State private var hoveredWindowID: CGWindowID?

    private var thumbnailWidth: CGFloat {
        CGFloat(thumbnailSize)
    }

    private var thumbnailHeight: CGFloat {
        CGFloat(thumbnailSize * 0.75) // Maintain 4:3 aspect ratio
    }

    private var filteredWindows: [WindowInfo] {
        if searchQuery.isEmpty {
            return windows
        }
        return windows.filter { window in
            window.title.localizedCaseInsensitiveContains(searchQuery) ||
            window.appName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    private var displayWindows: [WindowInfo] {
        let maxCount = Int(maxWindowsToShow)
        return Array(filteredWindows.prefix(maxCount))
    }

    private var hasMoreWindows: Bool {
        return filteredWindows.count > displayWindows.count
    }

    private var totalWindowCount: Int {
        return filteredWindows.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar indicator (if searching)
            if !searchQuery.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text(searchQuery)
                        .font(.body)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(totalWindowCount) window\(totalWindowCount == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.15))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            // Main window switcher
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 20) {
                        ForEach(Array(displayWindows.enumerated()), id: \.element.id) { index, window in
                            WindowThumbnailView(
                                window: window,
                                isSelected: index == selectedIndex,
                                isHovered: hoveredWindowID == window.id,
                                thumbnailWidth: thumbnailWidth,
                                thumbnailHeight: thumbnailHeight,
                                windowNumber: getWindowNumber(for: window, at: index),
                                displayNumber: index < 9 ? index + 1 : nil, // Show 1-9 for Cmd+number
                                onClose: onCloseWindow != nil ? { onCloseWindow?(window) } : nil,
                                onMinimize: onMinimizeWindow != nil ? { onMinimizeWindow?(window) } : nil
                            )
                            .id(window.id)
                            .onTapGesture {
                                onSelect(window)
                            }
                            .onHover { hovering in
                                hoveredWindowID = hovering ? window.id : nil
                            }
                        }
                    }
                    .padding(32)
                }
                .frame(maxWidth: maxSwitcherWidth)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))

                        VisualEffectBlur(material: .menu, blendingMode: .withinWindow, cornerRadius: 20)
                            .opacity(0.8)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                .onChange(of: selectedIndex) { newIndex in
                    if newIndex < displayWindows.count {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(displayWindows[newIndex].id, anchor: .center)
                        }
                    }
                }
                .onAppear {
                    if selectedIndex < displayWindows.count {
                        proxy.scrollTo(displayWindows[selectedIndex].id, anchor: .center)
                    }
                }
            }

            // Window count and navigation hints
            if totalWindowCount > 0 {
                HStack(spacing: 16) {
                    // Window count
                    if displayWindows.count < totalWindowCount {
                        HStack(spacing: 4) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                            Text("Showing \(displayWindows.count) of \(totalWindowCount) windows")
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    } else {
                        Text("\(totalWindowCount) window\(totalWindowCount == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Keyboard hints
                    HStack(spacing: 12) {
                        KeyHintView(keys: "⌘1-9", description: "Jump")
                        KeyHintView(keys: "Tab", description: "Next")
                        if !searchQuery.isEmpty {
                            KeyHintView(keys: "⌫", description: "Clear")
                        } else {
                            KeyHintView(keys: "Type", description: "Search")
                        }
                        KeyHintView(keys: "Esc", description: "Cancel")
                    }
                    .font(.caption2)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .background(Color.clear)
    }

    private var maxSwitcherWidth: CGFloat {
        // Get screen width and limit switcher to 90% of screen width
        guard let screen = NSScreen.main else { return 1200 }
        return screen.visibleFrame.width * 0.9
    }

    private func getWindowNumber(for window: WindowInfo, at index: Int) -> Int? {
        // Count how many windows from the same app come before this one
        let sameAppWindows = displayWindows.filter { $0.appName == window.appName }
        if sameAppWindows.count > 1 {
            // Return 1-based index within same app
            if let windowIndex = sameAppWindows.firstIndex(where: { $0.id == window.id }) {
                return windowIndex + 1
            }
        }
        return nil
    }
}

// MARK: - Helper Views

struct KeyHintView: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 4) {
            Text(keys)
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
            Text(description)
                .foregroundColor(.secondary)
        }
    }
}

struct WindowThumbnailView: View {
    let window: WindowInfo
    let isSelected: Bool
    let isHovered: Bool
    let thumbnailWidth: CGFloat
    let thumbnailHeight: CGFloat
    let windowNumber: Int?
    let displayNumber: Int? // For Cmd+1-9 shortcuts
    let onClose: (() -> Void)?
    let onMinimize: (() -> Void)?

    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            // Window Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: thumbnailWidth, height: thumbnailHeight)

                if let thumbnail = window.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: thumbnailWidth, height: thumbnailHeight)
                        .cornerRadius(8)
                } else {
                    VStack {
                        Image(systemName: "hourglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Loading...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // App icon overlay in bottom-left corner (only when showing window previews)
                if !isUsingAppIconsMode(), let appIcon = getAppIcon() {
                    VStack {
                        Spacer()
                        HStack {
                            Image(nsImage: appIcon)
                                .resizable()
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

                // Display number badge (top-right) for Cmd+1-9
                if let number = displayNumber {
                    VStack {
                        HStack {
                            Spacer()
                            Text("\(number)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle()
                                        .fill(Color.accentColor)
                                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                )
                                .padding(8)
                        }
                        Spacer()
                    }
                }

                // Window actions (on hover)
                if isHovered && (onClose != nil || onMinimize != nil) {
                    VStack {
                        HStack(spacing: 8) {
                            Spacer()

                            if let onMinimize = onMinimize {
                                Button(
                                    action: { onMinimize() },
                                    label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.orange)
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                )
                                .buttonStyle(.plain)
                                .help("Minimize Window")
                            }

                            if let onClose = onClose {
                                Button(
                                    action: { onClose() },
                                    label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.red)
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                )
                                .buttonStyle(.plain)
                                .help("Close Window")
                            }
                        }
                        .padding(8)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
            )
            .scaleEffect(isHovered && !isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)

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
                    }
                }
                .frame(width: thumbnailWidth)
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

        // Ensure the content view is transparent and uses rounded corners
        if let contentView = self.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
            contentView.layer?.cornerRadius = 20
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true
        }
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
            layer.cornerCurve = .continuous // Smoother, more natural corners
            layer.allowsEdgeAntialiasing = true // Enable anti-aliasing for smooth edges
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
