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
    private var isCacheRefreshActive = false
    private let cacheRefreshLock = NSLock()

    // Track window activation order for recency sorting
    private var windowActivationOrder: [CGWindowID] = []
    private let maxActivationHistorySize = 50
    private let activationOrderLock = NSLock()

    init() {
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
        activationOrderLock.lock()
        defer { activationOrderLock.unlock() }

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
        stopCacheRefresh()
    }

    func startCacheRefresh() {
        cacheRefreshLock.lock()
        defer { cacheRefreshLock.unlock() }

        guard !isCacheRefreshActive else { return }
        isCacheRefreshActive = true

        // Start refreshing on main thread (every 2 seconds only when switcher is shown)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cacheRefreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.refreshThumbnailCache()
            }
        }
    }

    func stopCacheRefresh() {
        cacheRefreshLock.lock()
        defer { cacheRefreshLock.unlock() }

        guard isCacheRefreshActive else { return }
        isCacheRefreshActive = false

        DispatchQueue.main.async { [weak self] in
            self?.cacheRefreshTimer?.invalidate()
            self?.cacheRefreshTimer = nil
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

            // Build set of valid window IDs currently on screen
            var validWindowIDs = Set<CGWindowID>()
            var newCache: [CGWindowID: NSImage] = [:]

            for windowInfo in windowInfoList {
                guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                      let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                      let layer = windowInfo[kCGWindowLayer as String] as? Int,
                      layer == 0 else {
                    continue
                }

                validWindowIDs.insert(windowID)

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
            // Only keep thumbnails for windows that still exist to prevent memory leak
            DispatchQueue.main.async {
                let prunedCount = self.thumbnailCache.count - newCache.count
                self.thumbnailCache = newCache
                self.logger.debug("Cache updated: \(newCache.count) entries (pruned \(prunedCount))")
            }
        }
    }

    func refreshWindows() {
        // Get visible windows via CoreGraphics
        var windowList = getWindowsViaCoreGraphics()

        // Reverse the list because CoreGraphics returns in ascending z-order (background first)
        // but we want descending z-order (foreground/most recent first)
        windowList.reverse()

        activationOrderLock.lock()
        defer { activationOrderLock.unlock() }

        // FIRST: Record any new windows at the FRONT of activation order (they are most recent)
        // Do this BEFORE sorting so the sort uses the updated activation order
        var newWindows: [CGWindowID] = []
        for window in windowList where !windowActivationOrder.contains(window.id) {
            newWindows.append(window.id)
        }
        // Insert new windows at the front (in reverse order to maintain their relative order)
        for newWindowID in newWindows.reversed() {
            windowActivationOrder.insert(newWindowID, at: 0)
        }
        saveActivationHistory()

        // THEN: Sort windows by their position in activation order (recency)
        windowList.sort { lhs, rhs in
            let lhsIndex = windowActivationOrder.firstIndex(of: lhs.id) ?? Int.max
            let rhsIndex = windowActivationOrder.firstIndex(of: rhs.id) ?? Int.max
            return lhsIndex < rhsIndex
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
        logger.info("Attempting to activate window: \(window.title) from app: \(window.appName), ID: \(window.id)")

        // Record this activation for recency tracking
        recordWindowActivation(window.id)

        // Get the application
        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            logger.error("Failed to get NSRunningApplication for PID: \(window.ownerPID)")
            return
        }

        // Activate the application first
        let activateResult = app.activate(options: [.activateIgnoringOtherApps])
        logger.info("App activation result: \(activateResult)")

        // Small delay to allow app to become active
        usleep(100_000) // 100ms

        // Try Accessibility API first
        let appElement = AXUIElementCreateApplication(window.ownerPID)
        var windowsValue: AnyObject?

        let windowsAttr = kAXWindowsAttribute as CFString
        if AXUIElementCopyAttributeValue(appElement, windowsAttr, &windowsValue) == .success,
           let axWindows = windowsValue as? [AXUIElement] {
            logger.info("Found \(axWindows.count) windows in Accessibility API for app")
            if !axWindows.isEmpty {
                if let axWindow = findMatchingWindow(axWindows, for: window) {
                    performWindowActivation(appElement, window: axWindow, for: window)
                    return
                }
            }
        }

        logger.warning(
            "Accessibility API failed or returned 0 windows. Trying direct CGWindow activation for ID: \(window.id)"
        )
        activateWindowDirectly(window)
    }

    private func activateWindowDirectly(_ window: WindowInfo) {
        logger.info("Attempting direct window activation using Accessibility API with focus")

        // Create app element
        let appElement = AXUIElementCreateApplication(window.ownerPID)

        // Try to set focus on the app itself, which might help enumerate windows
        var focusedWindowValue: AnyObject?
        let focusedWindowAttr = kAXFocusedWindowAttribute as CFString

        // Try to get the focused window first
        if AXUIElementCopyAttributeValue(appElement, focusedWindowAttr, &focusedWindowValue) == .success {
            logger.info("Successfully retrieved focused window attribute")
        }

        // Try a different approach: iterate through all windows in a different way
        // Get all windows including the one we're looking for
        var allWindowsValue: AnyObject?
        let allWindowsAttr = kAXWindowsAttribute as CFString

        if AXUIElementCopyAttributeValue(appElement, allWindowsAttr, &allWindowsValue) == .success,
           let allWindows = allWindowsValue as? [AXUIElement] {
            logger.info("Got \(allWindows.count) windows from AX API")

            // If we get windows, try to find and activate our target
            for (idx, axWindow) in allWindows.enumerated() {
                var posValue: AnyObject?
                let posAttr = kAXPositionAttribute as CFString

                if AXUIElementCopyAttributeValue(axWindow, posAttr, &posValue) == .success {
                    // Try to raise this window
                    let raiseResult = AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    logger.debug("Window \(idx): Raise result = \(raiseResult.rawValue)")

                    if raiseResult == .success {
                        logger.info("Successfully raised window \(idx)")
                        return
                    }
                }
            }
        } else {
            logger.warning("Could not access AX windows attribute on second attempt")
        }

        // Last resort: just set focus on the app
        let focusResult = AXUIElementSetAttributeValue(
            appElement,
            focusedWindowAttr,
            focusedWindowValue as CFTypeRef? ?? kCFNull
        )
        logger.info("Set app focus result: \(focusResult.rawValue)")
    }

    private func findMatchingWindow(_ axWindows: [AXUIElement], for window: WindowInfo) -> AXUIElement? {
        // First pass: Try to match window by CGWindowID (most reliable for Finder)
        if let matched = matchByWindowID(axWindows, targetID: window.id) {
            return matched
        }

        // Second pass: Try to match window by position and size
        if let matched = matchByBounds(axWindows, targetBounds: window.bounds) {
            return matched
        }

        // Third pass: Try to match window by title with position refinement (fallback)
        if let matched = matchByTitle(axWindows, targetTitle: window.title, targetBounds: window.bounds) {
            return matched
        }

        return nil
    }

    private func matchByWindowID(_ axWindows: [AXUIElement], targetID: CGWindowID) -> AXUIElement? {
        logger.info("matchByWindowID: Looking for window ID \(targetID) among \(axWindows.count) AX windows")
        var foundAnyID = false

        for (index, axWindow) in axWindows.enumerated() {
            var windowIDValue: AnyObject?
            let windowIDAttr = kAXWindowAttribute as CFString

            if AXUIElementCopyAttributeValue(axWindow, windowIDAttr, &windowIDValue) == .success,
               let windowIDNum = windowIDValue as? NSNumber {
                let axWindowID = CGWindowID(windowIDNum.uint32Value)
                foundAnyID = true
                logger.debug("Window \(index): ID=\(axWindowID) (target=\(targetID)), match=\(axWindowID == targetID)")
                if axWindowID == targetID {
                    logger.info("✓ Matched window by CGWindowID: \(targetID)")
                    return axWindow
                }
            } else {
                logger.debug("Window \(index): No AX window ID attribute found")
            }
        }

        if foundAnyID {
            logger.warning("✗ No window matched by ID. Target ID: \(targetID), checked \(axWindows.count) windows")
        } else {
            logger.warning("✗ No AX windows had retrievable window IDs. Checked \(axWindows.count) windows")
        }
        return nil
    }

    private func matchByBounds(_ axWindows: [AXUIElement], targetBounds: CGRect) -> AXUIElement? {
        logger.info("matchByBounds: Looking among \(axWindows.count) AX windows")
        for (index, axWindow) in axWindows.enumerated() {
            var positionValue: AnyObject?
            var sizeValue: AnyObject?

            let posAttr = kAXPositionAttribute as CFString
            let sizeAttr = kAXSizeAttribute as CFString
            if AXUIElementCopyAttributeValue(axWindow, posAttr, &positionValue) == .success,
               AXUIElementCopyAttributeValue(axWindow, sizeAttr, &sizeValue) == .success,
               let position = positionValue as? CGPoint,
               let size = sizeValue as? CGSize {
                let axBounds = CGRect(origin: position, size: size)

                let xDiff = abs(axBounds.origin.x - targetBounds.origin.x)
                let yDiff = abs(axBounds.origin.y - targetBounds.origin.y)
                let wDiff = abs(axBounds.size.width - targetBounds.size.width)
                let hDiff = abs(axBounds.size.height - targetBounds.size.height)

                logger.debug("Window \(index): diffs x=\(xDiff) y=\(yDiff) w=\(wDiff) h=\(hDiff)")

                // Check if bounds match (with small tolerance)
                if xDiff < 5 && yDiff < 5 && wDiff < 5 && hDiff < 5 {
                    logger.info("Matched window by bounds")
                    return axWindow
                }
            } else {
                logger.debug("Window \(index): Could not get AX position or size")
            }
        }
        logger.warning("No window matched by bounds")
        return nil
    }

    private func matchByTitle(_ axWindows: [AXUIElement], targetTitle: String, targetBounds: CGRect) -> AXUIElement? {
        guard !targetTitle.isEmpty else { return nil }

        var titleMatches: [AXUIElement] = []
        for axWindow in axWindows {
            var titleValue: AnyObject?
            let titleAttr = kAXTitleAttribute as CFString
            if AXUIElementCopyAttributeValue(axWindow, titleAttr, &titleValue) == .success,
               let axTitle = titleValue as? String,
               axTitle == targetTitle {
                titleMatches.append(axWindow)
            }
        }

        // If multiple matches, find the one closest in position to our window bounds
        if titleMatches.count > 1 {
            return findClosestByPosition(titleMatches, to: targetBounds)
        } else if titleMatches.count == 1 {
            logger.info("Matched window by title: \(targetTitle)")
            return titleMatches.first
        }

        return nil
    }

    private func findClosestByPosition(_ windows: [AXUIElement], to targetBounds: CGRect) -> AXUIElement? {
        var bestMatch: AXUIElement?
        var bestDistance: CGFloat = CGFloat.greatestFiniteMagnitude

        for axWindow in windows {
            var positionValue: AnyObject?
            let posAttr = kAXPositionAttribute as CFString
            if AXUIElementCopyAttributeValue(axWindow, posAttr, &positionValue) == .success,
               let position = positionValue as? CGPoint {
                let distance = hypot(
                    position.x - targetBounds.origin.x,
                    position.y - targetBounds.origin.y
                )
                if distance < bestDistance {
                    bestDistance = distance
                    bestMatch = axWindow
                }
            }
        }

        if bestMatch != nil {
            logger.info("Matched window by title with position refinement")
        }
        return bestMatch
    }

    private func performWindowActivation(
        _ appElement: AXUIElement,
        window axWindow: AXUIElement,
        for windowInfo: WindowInfo
    ) {
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
            logger.info("Successfully activated window: \(windowInfo.title)")
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
        let useAppIcons = UserDefaults.standard.bool(forKey: "useAppIcons")

        if useAppIcons {
            return getAppIconForWindow(window)
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
            return getAppIconForWindow(window)
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
}
