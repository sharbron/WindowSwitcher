import SwiftUI
import AppKit

struct WindowSwitcherView: View {
    /// Already filtered and limited by the coordinator. The view renders this list verbatim so
    /// that `selectedIndex` means the same thing here as it does where windows get activated.
    let windows: [WindowInfo]
    let selectedIndex: Int
    /// How many windows match the search before the display limit — drives "showing X of Y".
    let matchingWindowCount: Int
    let onSelect: (WindowInfo) -> Void
    let searchQuery: String
    let onCloseWindow: ((WindowInfo) -> Void)?
    let onMinimizeWindow: ((WindowInfo) -> Void)?

    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200
    @AppStorage("useAppIcons") private var useAppIcons: Bool = false
    @State private var hoveredWindowID: CGWindowID?

    private static let cornerRadius: CGFloat = 16

    private var thumbnailWidth: CGFloat {
        CGFloat(thumbnailSize)
    }

    private var thumbnailHeight: CGFloat {
        CGFloat(thumbnailSize * 0.75) // Maintain 4:3 aspect ratio
    }

    private var displayWindows: [WindowInfo] {
        windows
    }

    private var totalWindowCount: Int {
        matchingWindowCount
    }

    // Pre-compute window numbers to avoid O(n²) performance issue
    private var windowNumbers: [CGWindowID: Int] {
        var numbers: [CGWindowID: Int] = [:]
        var appCounts: [String: Int] = [:]

        for window in displayWindows {
            appCounts[window.appName, default: 0] += 1
        }

        var appIndices: [String: Int] = [:]
        for window in displayWindows where appCounts[window.appName, default: 0] > 1 {
            let index = appIndices[window.appName, default: 0]
            numbers[window.id] = index + 1
            appIndices[window.appName] = index + 1
        }

        return numbers
    }

    var body: some View {
        VStack(spacing: 0) {
            if !searchQuery.isEmpty {
                searchHeader
                Divider().opacity(0.5)
            }

            windowStrip

            if totalWindowCount > 0 {
                Divider().opacity(0.5)
                footer
            }
        }
        .frame(maxWidth: maxSwitcherWidth)
        // The material, the rounded corners and the shadow belong to the whole panel. They
        // used to be applied to the scroll view alone, which left the footer hanging below
        // the card as an unclipped, square-cornered slab.
        .background(
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow)
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay(
            // A hairline keeps the panel from dissolving into a light desktop.
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 12)
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            Text(searchQuery)
                .font(.body.weight(.medium))
            Spacer()
            Text(windowCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var windowStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(displayWindows.enumerated()), id: \.element.id) { index, window in
                        WindowThumbnailView(
                            window: window,
                            isSelected: index == selectedIndex,
                            isHovered: hoveredWindowID == window.id,
                            thumbnailWidth: thumbnailWidth,
                            thumbnailHeight: thumbnailHeight,
                            windowNumber: windowNumbers[window.id],
                            displayNumber: index < 9 ? index + 1 : nil, // Show 1-9 for Cmd+number
                            showAppIconOverlay: !useAppIcons,
                            onClose: onCloseWindow != nil ? { onCloseWindow?(window) } : nil,
                            onMinimize: onMinimizeWindow != nil ? { onMinimizeWindow?(window) } : nil
                        )
                        .id(window.id)
                        .onTapGesture { onSelect(window) }
                        .onHover { hovering in
                            hoveredWindowID = hovering ? window.id : nil
                        }
                    }
                }
                .padding(20)
            }
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
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text(windowCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 14) {
                KeyHintView(keys: "⌘1-9", description: "Jump")
                KeyHintView(keys: "Tab", description: "Next")
                if searchQuery.isEmpty {
                    KeyHintView(keys: "Type", description: "Search")
                } else {
                    KeyHintView(keys: "Delete", description: "Clear")
                }
                KeyHintView(keys: "Esc", description: "Cancel")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private var windowCountLabel: String {
        if displayWindows.count < totalWindowCount {
            return "Showing \(displayWindows.count) of \(totalWindowCount) windows"
        }
        return "\(totalWindowCount) window\(totalWindowCount == 1 ? "" : "s")"
    }

    private var maxSwitcherWidth: CGFloat {
        // Get screen width and limit switcher to 90% of screen width
        guard let screen = NSScreen.main else { return 1200 }
        return screen.visibleFrame.width * 0.9
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
    /// False when the user has opted into app icons as the preview, where a corner badge of
    /// the same icon would be redundant.
    let showAppIconOverlay: Bool
    let onClose: (() -> Void)?
    let onMinimize: (() -> Void)?

    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true

    /// Both label lines are always reserved, so a window without a title does not sit at a
    /// different height from its neighbours and the row stops jumping as you Tab through.
    private static let labelHeight: CGFloat = 34

    private var secondaryLabel: String? {
        if !window.title.isEmpty && window.title != window.appName {
            return window.title
        }
        if let number = windowNumber {
            return "Window \(number)"
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 10) {
            preview

            if showWindowTitles {
                VStack(spacing: 2) {
                    Text(window.appName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    if let secondaryLabel {
                        Text(secondaryLabel)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(width: thumbnailWidth, height: Self.labelHeight, alignment: .top)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selectionFill)
        )
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }

    /// One selection treatment, not two. The old cell drew a 3pt accent border around the
    /// thumbnail *and* filled the whole cell, which read as much louder than the rest of the UI.
    private var selectionFill: Color {
        if isSelected { return Color.accentColor.opacity(0.22) }
        if isHovered { return Color.primary.opacity(0.08) }
        return .clear
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.07))

            if let thumbnail = window.thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "macwindow")
                    .font(.system(size: 28))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: thumbnailWidth, height: thumbnailHeight)
        .overlay(alignment: .bottomLeading) {
            if showAppIconOverlay, let appIcon = window.appIcon {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .padding(6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let number = displayNumber {
                Text("\(number)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.55)))
                    .padding(5)
            }
        }
        .overlay(alignment: .topLeading) {
            if isHovered && (onClose != nil || onMinimize != nil) {
                HStack(spacing: 6) {
                    if let onMinimize {
                        WindowActionButton(symbol: "minus", help: "Minimize Window", action: onMinimize)
                    }
                    if let onClose {
                        WindowActionButton(symbol: "xmark", help: "Close Window", action: onClose)
                    }
                }
                .padding(5)
                .transition(.opacity)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.12),
                    lineWidth: isSelected ? 2 : 1
                )
        )
    }
}

/// A small circular control shown over a preview on hover.
struct WindowActionButton: View {
    let symbol: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.black.opacity(0.6)))
        }
        .buttonStyle(.plain)
        .help(help)
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
