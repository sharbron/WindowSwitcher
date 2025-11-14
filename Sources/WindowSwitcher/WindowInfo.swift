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
    private let activationLock = NSLock()
    private let maxActivationHistorySize = 50

    // UserDefaults instance for testing/dependency injection
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Start background cache refresh timer (every 2 seconds)
        startCacheRefresh()
        loadActivationHistory()
    }

    private func loadActivationHistory() {
        // Load previously saved activation order
        if let saved = userDefaults.array(forKey: "windowActivationOrder") as? [UInt32] {
            activationLock.lock()
            windowActivationOrder = saved.map { CGWindowID($0) }
            activationLock.unlock()
        }
    }

    private func saveActivationHistory() {
        // Save activation order for persistence across app restarts
        activationLock.lock()
        let orderToSave = windowActivationOrder.map { UInt32($0) }
        activationLock.unlock()

        userDefaults.set(orderToSave, forKey: "windowActivationOrder")
    }

    func recordWindowActivation(_ windowID: CGWindowID) {
        // Protect array access with lock
        activationLock.lock()

        // Remove if already in list
        windowActivationOrder.removeAll { $0 == windowID }
        // Add to front (most recent)
        windowActivationOrder.insert(windowID, at: 0)
        // Keep list size manageable
        if windowActivationOrder.count > maxActivationHistorySize {
            windowActivationOrder = Array(windowActivationOrder.prefix(maxActivationHistorySize))
        }

        // Create snapshot for saving (outside critical section)
        let orderToSave = windowActivationOrder.map { UInt32($0) }
        activationLock.unlock()

        // Save asynchronously to avoid blocking
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.userDefaults.set(orderToSave, forKey: "windowActivationOrder")
        }
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

        // Create a thread-safe snapshot of activation order for sorting
        activationLock.lock()
        let activationOrderSnapshot = windowActivationOrder
        activationLock.unlock()

        // Sort windows by recency (most recently activated first)
        windowList.sort { lhs, rhs in
            let lhsIndex = activationOrderSnapshot.firstIndex(of: lhs.id) ?? Int.max
            let rhsIndex = activationOrderSnapshot.firstIndex(of: rhs.id) ?? Int.max

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

        // Get the running application
        guard let app = getRunningApp(for: window) else {
            return
        }

        // Activate the application first
        app.activate(options: [.activateIgnoringOtherApps])

        // Find and focus the specific window
        if let axWindow = findAccessibilityWindow(for: window, in: app) {
            focusWindow(axWindow, for: app, window: window)
        } else {
            logger.warning("Could not find matching window for: \(window.title)")
        }
    }

    // MARK: - Window Activation Helper Methods

    /// Gets the NSRunningApplication for the given window
    private func getRunningApp(for window: WindowInfo) -> NSRunningApplication? {
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            logger.error("Failed to get NSRunningApplication for PID: \(window.ownerPID)")
            return nil
        }
        return app
    }

    /// Gets the array of accessibility windows for the given application
    private func getAccessibilityWindows(for app: NSRunningApplication) -> [AXUIElement]? {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?

        let windowsAttr = kAXWindowsAttribute as CFString
        guard AXUIElementCopyAttributeValue(appElement, windowsAttr, &windowsValue) == .success,
              let axWindows = windowsValue as? [AXUIElement] else {
            return nil
        }

        return axWindows
    }

    /// Finds the accessibility window element matching the given window info
    private func findAccessibilityWindow(for window: WindowInfo, in app: NSRunningApplication) -> AXUIElement? {
        guard let axWindows = getAccessibilityWindows(for: app) else {
            return nil
        }

        // First pass: Try to match by bounds (most accurate)
        if let match = matchWindowByBounds(window, in: axWindows) {
            logger.info("Matched window by bounds")
            return match
        }

        // Second pass: Try to match by title (fallback)
        if !window.title.isEmpty, let match = matchWindowByTitle(window, in: axWindows) {
            logger.info("Matched window by title: \(window.title)")
            return match
        }

        return nil
    }

    /// Attempts to match a window by its bounds (position and size)
    private func matchWindowByBounds(_ window: WindowInfo, in axWindows: [AXUIElement]) -> AXUIElement? {
        let tolerance: CGFloat = 5.0

        for axWindow in axWindows {
            var positionValue: AnyObject?
            var sizeValue: AnyObject?

            let posAttr = kAXPositionAttribute as CFString
            let sizeAttr = kAXSizeAttribute as CFString

            guard AXUIElementCopyAttributeValue(axWindow, posAttr, &positionValue) == .success,
                  AXUIElementCopyAttributeValue(axWindow, sizeAttr, &sizeValue) == .success,
                  let position = positionValue as? CGPoint,
                  let size = sizeValue as? CGSize else {
                continue
            }

            let axBounds = CGRect(origin: position, size: size)

            // Check if bounds match within tolerance
            if boundsMatch(axBounds, window.bounds, tolerance: tolerance) {
                return axWindow
            }
        }

        return nil
    }

    /// Checks if two bounds match within a given tolerance
    private func boundsMatch(_ bounds1: CGRect, _ bounds2: CGRect, tolerance: CGFloat) -> Bool {
        return abs(bounds1.origin.x - bounds2.origin.x) < tolerance &&
               abs(bounds1.origin.y - bounds2.origin.y) < tolerance &&
               abs(bounds1.size.width - bounds2.size.width) < tolerance &&
               abs(bounds1.size.height - bounds2.size.height) < tolerance
    }

    /// Attempts to match a window by its title
    private func matchWindowByTitle(_ window: WindowInfo, in axWindows: [AXUIElement]) -> AXUIElement? {
        for axWindow in axWindows {
            var titleValue: AnyObject?
            let titleAttr = kAXTitleAttribute as CFString

            guard AXUIElementCopyAttributeValue(axWindow, titleAttr, &titleValue) == .success,
                  let axTitle = titleValue as? String,
                  axTitle == window.title else {
                continue
            }

            return axWindow
        }

        return nil
    }

    /// Focuses the given accessibility window
    private func focusWindow(_ axWindow: AXUIElement, for app: NSRunningApplication, window: WindowInfo) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        // Perform window activation actions
        let raiseResult = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
        let frontmostAttr = kAXFrontmostAttribute as CFString
        let frontmostResult = AXUIElementSetAttributeValue(appElement, frontmostAttr, kCFBooleanTrue)
        let focusAttr = kAXFocusedWindowAttribute as CFString
        let focusResult = AXUIElementSetAttributeValue(appElement, focusAttr, axWindow as CFTypeRef)

        // Log results
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
    }

    func captureWindowThumbnail(_ window: WindowInfo) -> NSImage? {
        // Check user preference for using app icons
        let useAppIcons = userDefaults.bool(forKey: "useAppIcons")

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

    // MARK: - Window Actions

    /// Closes the specified window
    func closeWindow(_ window: WindowInfo) {
        logger.info("Closing window: \(window.title) (ID: \(window.id))")

        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            logger.error("Failed to get NSRunningApplication for PID: \(window.ownerPID)")
            return
        }

        // Find the window using Accessibility API
        if let axWindow = findAccessibilityWindow(for: window, in: app) {
            // Get the close button
            var closeButtonValue: AnyObject?
            let closeButtonAttr = kAXCloseButtonAttribute as CFString

            if AXUIElementCopyAttributeValue(axWindow, closeButtonAttr, &closeButtonValue) == .success {
                // Cast to AXUIElement (safe because copy succeeded)
                // swiftlint:disable:next force_cast
                let closeButton = closeButtonValue as! AXUIElement
                // Press the close button
                let result = AXUIElementPerformAction(closeButton, kAXPressAction as CFString)

                if result == .success {
                    logger.info("Successfully closed window: \(window.title)")
                } else {
                    logger.warning("Failed to close window: \(window.title), error code: \(result.rawValue)")
                }
            } else {
                logger.warning("Could not find close button for window: \(window.title)")
            }
        } else {
            logger.warning("Could not find accessibility window for: \(window.title)")
        }
    }

    /// Minimizes the specified window
    func minimizeWindow(_ window: WindowInfo) {
        logger.info("Minimizing window: \(window.title) (ID: \(window.id))")

        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            logger.error("Failed to get NSRunningApplication for PID: \(window.ownerPID)")
            return
        }

        // Find the window using Accessibility API
        if let axWindow = findAccessibilityWindow(for: window, in: app) {
            // Set the minimized attribute
            var minimizedValue: AnyObject?
            let minimizedAttr = kAXMinimizedAttribute as CFString

            // First check if window can be minimized
            if AXUIElementCopyAttributeValue(axWindow, minimizedAttr, &minimizedValue) == .success {
                // Set minimized to true
                let result = AXUIElementSetAttributeValue(axWindow, minimizedAttr, kCFBooleanTrue)

                if result == .success {
                    logger.info("Successfully minimized window: \(window.title)")
                } else {
                    logger.warning("Failed to minimize window: \(window.title), error code: \(result.rawValue)")

                    // Try alternative method using minimize button
                    minimizeWindowViaButton(axWindow, window: window)
                }
            } else {
                // Try minimize button as fallback
                minimizeWindowViaButton(axWindow, window: window)
            }
        } else {
            logger.warning("Could not find accessibility window for: \(window.title)")
        }
    }

    /// Alternative method to minimize window using the minimize button
    private func minimizeWindowViaButton(_ axWindow: AXUIElement, window: WindowInfo) {
        var minimizeButtonValue: AnyObject?
        let minimizeButtonAttr = kAXMinimizeButtonAttribute as CFString

        if AXUIElementCopyAttributeValue(axWindow, minimizeButtonAttr, &minimizeButtonValue) == .success {
            // Cast to AXUIElement (safe because copy succeeded)
            // swiftlint:disable:next force_cast
            let minimizeButton = minimizeButtonValue as! AXUIElement
            let result = AXUIElementPerformAction(minimizeButton, kAXPressAction as CFString)

            if result == .success {
                logger.info("Successfully minimized window via button: \(window.title)")
            } else {
                logger.warning("Failed to minimize window via button: \(window.title)")
            }
        } else {
            logger.warning("Could not find minimize button for window: \(window.title)")
        }
    }
}
