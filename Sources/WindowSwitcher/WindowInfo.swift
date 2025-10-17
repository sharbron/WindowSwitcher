import Cocoa
import ApplicationServices
import os.log

struct WindowInfo: Identifiable, Equatable {
    let id: CGWindowID
    let ownerPID: pid_t
    let title: String
    let appName: String
    let bounds: CGRect
    let layer: Int
    let isOnScreen: Bool
    var thumbnail: NSImage?

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id
    }
}

class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []
    private let logger = Logger(subsystem: "com.windowswitcher", category: "WindowManager")

    // Thumbnail cache for instant display
    private var thumbnailCache: [CGWindowID: NSImage] = [:]
    private var cacheRefreshTimer: Timer?

    // Track window activation order for recency sorting
    private var windowActivationOrder: [CGWindowID] = []
    private let maxActivationHistorySize = 50

    init() {
        // Start background cache refresh timer (every 2 seconds)
        startCacheRefresh()
        loadActivationHistory()
    }

    private func loadActivationHistory() {
        // Load previously saved activation order
        if let saved = UserDefaults.standard.array(forKey: "windowActivationOrder") as? [UInt32] {
            windowActivationOrder = saved.map { CGWindowID($0) }
        }
    }

    private func saveActivationHistory() {
        // Save activation order for persistence across app restarts
        let orderToSave = windowActivationOrder.map { UInt32($0) }
        UserDefaults.standard.set(orderToSave, forKey: "windowActivationOrder")
    }

    func recordWindowActivation(_ windowID: CGWindowID) {
        // Remove if already in list
        windowActivationOrder.removeAll { $0 == windowID }
        // Add to front (most recent)
        windowActivationOrder.insert(windowID, at: 0)
        // Keep list size manageable
        if windowActivationOrder.count > maxActivationHistorySize {
            windowActivationOrder = Array(windowActivationOrder.prefix(maxActivationHistorySize))
        }
        saveActivationHistory()
    }

    deinit {
        cacheRefreshTimer?.invalidate()
    }

    private func startCacheRefresh() {
        // Start refreshing frequently for up-to-date previews (every 0.5 seconds)
        cacheRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.refreshThumbnailCache()
        }
    }

    private func refreshThumbnailCache() {
        // Use higher priority queue for faster, more responsive updates
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Get current window list (only on-screen windows)
            let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
            guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
                return
            }

            var newCache: [CGWindowID: NSImage] = [:]

            for windowInfo in windowInfoList {
                guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                      let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                      let layer = windowInfo[kCGWindowLayer as String] as? Int,
                      layer == 0 else {
                    continue
                }

                // Create a minimal WindowInfo for thumbnail capture
                let tempWindow = WindowInfo(
                    id: windowID,
                    ownerPID: ownerPID,
                    title: "",
                    appName: "",
                    bounds: .zero,
                    layer: layer,
                    isOnScreen: true,
                    thumbnail: nil
                )

                // Always capture fresh thumbnail to keep cache up-to-date
                if let thumbnail = self.captureWindowThumbnail(tempWindow) {
                    newCache[windowID] = thumbnail
                }
            }

            // Update cache on main thread
            DispatchQueue.main.async {
                self.thumbnailCache = newCache
                self.logger.debug("Thumbnail cache updated with \(newCache.count) entries")
            }
        }
    }

    func refreshWindows() {
        // Get visible windows via CoreGraphics
        var windowList = getWindowsViaCoreGraphics()

        // Sort windows by recency (most recently activated first)
        windowList.sort { lhs, rhs in
            let lhsIndex = windowActivationOrder.firstIndex(of: lhs.id) ?? Int.max
            let rhsIndex = windowActivationOrder.firstIndex(of: rhs.id) ?? Int.max

            // Lower index = more recent (comes first)
            if lhsIndex != rhsIndex {
                return lhsIndex < rhsIndex
            }

            // If neither has activation history, prioritize windows with titles
            let lhsHasTitle = !lhs.title.isEmpty
            let rhsHasTitle = !rhs.title.isEmpty

            if lhsHasTitle != rhsHasTitle {
                return lhsHasTitle
            }

            // Finally sort by app name
            return lhs.appName.localizedCaseInsensitiveCompare(rhs.appName) == .orderedAscending
        }

        self.windows = windowList
        logger.info("Total windows: \(windowList.count)")
    }

    private func getWindowsViaCoreGraphics() -> [WindowInfo] {
        var windowList: [WindowInfo] = []

        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            logger.error("Failed to get window list from CGWindowListCopyWindowInfo")
            return []
        }

        logger.info("Found \(windowInfoList.count) visible windows via CoreGraphics")

        for windowInfo in windowInfoList {
            guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = windowInfo[kCGWindowLayer as String] as? Int,
                  let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool else {
                continue
            }

            // Skip windows with layer != 0 (menu bars, dock, etc.)
            guard layer == 0 else { continue }

            // Get app name
            let runningApp = NSRunningApplication(processIdentifier: ownerPID)
            let appName = runningApp?.localizedName ?? "Unknown"

            // Get window title from CGWindowListCopyWindowInfo
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""

            let rect = CGRect(
                x: bounds["X"] ?? 0,
                y: bounds["Y"] ?? 0,
                width: bounds["Width"] ?? 0,
                height: bounds["Height"] ?? 0
            )

            // Skip very small windows (likely helper windows or popups)
            // Minimum size: 100x100 pixels
            guard rect.width >= 100 && rect.height >= 100 else {
                logger.debug("Skipping small window: \(windowTitle) (\(rect.width)x\(rect.height))")
                continue
            }

            // Use cached thumbnail if available, otherwise nil
            let cachedThumbnail = thumbnailCache[windowID]

            let window = WindowInfo(
                id: windowID,
                ownerPID: ownerPID,
                title: windowTitle,
                appName: appName,
                bounds: rect,
                layer: layer,
                isOnScreen: isOnScreen,
                thumbnail: cachedThumbnail
            )

            windowList.append(window)
        }

        return windowList
    }

    func activateWindow(_ window: WindowInfo) {
        logger.info("Attempting to activate window: \(window.title) from app: \(window.appName)")

        // Record this activation for recency tracking
        recordWindowActivation(window.id)

        // Get the application
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            logger.error("Failed to get NSRunningApplication for PID: \(window.ownerPID)")
            return
        }

        // Activate the application first
        app.activate(options: [.activateIgnoringOtherApps])

        // Use Accessibility API to focus the specific window by matching bounds
        let appElement = AXUIElementCreateApplication(window.ownerPID)
        var windowsValue: AnyObject?

        let windowsAttr = kAXWindowsAttribute as CFString
        if AXUIElementCopyAttributeValue(appElement, windowsAttr, &windowsValue) == .success,
           let axWindows = windowsValue as? [AXUIElement] {
            var matchedWindow: AXUIElement?
            // First pass: Try to match window by position and size (most accurate)
            for axWindow in axWindows {
                var positionValue: AnyObject?
                var sizeValue: AnyObject?

                let posAttr = kAXPositionAttribute as CFString
                let sizeAttr = kAXSizeAttribute as CFString
                if AXUIElementCopyAttributeValue(axWindow, posAttr, &positionValue) == .success,
                   AXUIElementCopyAttributeValue(axWindow, sizeAttr, &sizeValue) == .success,
                   let position = positionValue as? CGPoint,
                   let size = sizeValue as? CGSize {
                    let axBounds = CGRect(origin: position, size: size)

                    // Check if bounds match (with small tolerance)
                    if abs(axBounds.origin.x - window.bounds.origin.x) < 5 &&
                       abs(axBounds.origin.y - window.bounds.origin.y) < 5 &&
                       abs(axBounds.size.width - window.bounds.size.width) < 5 &&
                       abs(axBounds.size.height - window.bounds.size.height) < 5 {
                        matchedWindow = axWindow
                        logger.info("Matched window by bounds")
                        break
                    }
                }
            }

            // Second pass: If bounds matching failed, try title matching (fallback)
            if matchedWindow == nil && !window.title.isEmpty {
                for axWindow in axWindows {
                    var titleValue: AnyObject?
                    let titleAttr = kAXTitleAttribute as CFString
                    if AXUIElementCopyAttributeValue(axWindow, titleAttr, &titleValue) == .success,
                       let axTitle = titleValue as? String,
                       axTitle == window.title {
                        matchedWindow = axWindow
                        logger.info("Matched window by title: \(window.title)")
                        break
                    }
                }
            }

            // Activate the matched window
            if let axWindow = matchedWindow {
                let raiseResult = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                let frontmostAttr = kAXFrontmostAttribute as CFString
                let frontmostResult = AXUIElementSetAttributeValue(
                    appElement,
                    frontmostAttr,
                    kCFBooleanTrue
                )
                let focusAttr = kAXFocusedWindowAttribute as CFString
                let focusResult = AXUIElementSetAttributeValue(
                    appElement,
                    focusAttr,
                    axWindow as CFTypeRef
                )

                if raiseResult == .success && frontmostResult == .success && focusResult == .success {
                    logger.info("Successfully activated window: \(window.title)")
                } else {
                    logger.warning(
                        """
                        Window activation partially failed. \
                        Raise: \(raiseResult.rawValue), \
                        Frontmost: \(frontmostResult.rawValue), \
                        Focus: \(focusResult.rawValue)
                        """
                    )
                }
            } else {
                logger.warning("Could not find matching window for: \(window.title)")
            }
        }
    }

    func captureWindowThumbnail(_ window: WindowInfo) -> NSImage? {
        // Check user preference for using app icons
        let useAppIcons = UserDefaults.standard.bool(forKey: "useAppIcons")

        if useAppIcons {
            return getAppIcon(for: window)
        }

        // Try to capture window thumbnail
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.id,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            logger.warning("Failed to capture thumbnail for window: \(window.title) (ID: \(window.id))")
            // Fall back to app icon if thumbnail capture fails (likely no Screen Recording permission)
            return getAppIcon(for: window)
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        logger.debug("Successfully captured thumbnail for window: \(window.title)")
        return image
    }

    func getAppIconForWindow(_ window: WindowInfo) -> NSImage? {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            logger.warning("Failed to get app for PID: \(window.ownerPID)")
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "App")
        }

        if let icon = app.icon {
            logger.debug("Using app icon for: \(window.appName)")
            return icon
        }

        logger.warning("No icon available for: \(window.appName)")
        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "App")
    }

    private func getAppIcon(for window: WindowInfo) -> NSImage? {
        return getAppIconForWindow(window)
    }
}
