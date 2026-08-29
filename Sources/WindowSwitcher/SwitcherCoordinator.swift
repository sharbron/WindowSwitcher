import SwiftUI
import Cocoa
import os.log

class SwitcherCoordinator: ObservableObject {
    /// Every window currently open, in recency order. This is the source list; the switcher
    /// displays `displayedWindows`, which applies the search filter and the display limit.
    @Published var windows: [WindowInfo] = []
    /// Index into `displayedWindows` — NOT into `windows`. Selection must be expressed in the
    /// same terms the user sees, or Tab highlights one window and activates another.
    @Published var selectedIndex = 0
    @Published var isShowingSwitcher = false
    @Published var searchQuery = ""

    private let windowManager = WindowManager()
    private let keyboardMonitor = KeyboardMonitor()
    private var switcherWindow: NSWindow?
    private var hostingController: NSHostingController<WindowSwitcherView>?
    private let logger = Logger(subsystem: "com.windowswitcher", category: "SwitcherCoordinator")

    private static let defaultMaxWindowsToShow = 20

    /// Bumped whenever the switcher opens or closes, so an in-flight background capture pass
    /// can tell that its results are no longer wanted. Guarded by captureGenerationLock.
    private var captureGeneration = 0
    private let captureGenerationLock = NSLock()

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        setupKeyboardMonitor()
    }

    // MARK: - Displayed Window List

    /// Windows matching the current search query.
    private var filteredWindows: [WindowInfo] {
        guard !searchQuery.isEmpty else { return windows }
        return windows.filter { window in
            window.title.localizedCaseInsensitiveContains(searchQuery) ||
            window.appName.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    /// Number of windows matching the search, before the display limit is applied.
    var matchingWindowCount: Int {
        filteredWindows.count
    }

    private var maxWindowsToShow: Int {
        let stored = userDefaults.double(forKey: "maxWindowsToShow")
        return stored > 0 ? Int(stored) : Self.defaultMaxWindowsToShow
    }

    /// Exactly what the switcher renders. `selectedIndex` indexes into this.
    var displayedWindows: [WindowInfo] {
        Array(filteredWindows.prefix(maxWindowsToShow))
    }

    private func setupKeyboardMonitor() {
        keyboardMonitor.onCmdTabPressed = { [weak self] in
            self?.showSwitcher()
        }

        keyboardMonitor.onTabPressed = { [weak self] in
            self?.selectNext()
        }

        keyboardMonitor.onShiftTabPressed = { [weak self] in
            self?.selectPrevious()
        }

        keyboardMonitor.onCmdReleased = { [weak self] in
            self?.activateSelectedWindow()
        }

        keyboardMonitor.onEscapePressed = { [weak self] in
            self?.hideSwitcher()
        }

        keyboardMonitor.onCharacterTyped = { [weak self] character in
            self?.handleCharacterInput(character)
        }

        keyboardMonitor.onBackspacePressed = { [weak self] in
            self?.handleBackspace()
        }

        keyboardMonitor.onNumberPressed = { [weak self] number in
            self?.handleNumberKey(number)
        }
    }

    /// Begins listening for Cmd+Tab. Returns false if Accessibility permission is missing.
    @discardableResult
    func startMonitoring() -> Bool {
        keyboardMonitor.startMonitoring()
    }

    private func currentCaptureGeneration() -> Int {
        captureGenerationLock.lock()
        defer { captureGenerationLock.unlock() }
        return captureGeneration
    }

    /// Abandons any background capture pass that is still running.
    @discardableResult
    private func invalidateInFlightCaptures() -> Int {
        captureGenerationLock.lock()
        defer { captureGenerationLock.unlock() }
        captureGeneration += 1
        return captureGeneration
    }

    // MARK: - Showing and Hiding

    private func showSwitcher() {
        // If switcher is already showing, don't show it again (user is holding Cmd)
        if isShowingSwitcher {
            logger.info("Switcher already showing, ignoring duplicate show request")
            return
        }

        logger.info("Showing switcher")

        // Start thumbnail caching while switcher is visible
        windowManager.startCacheRefresh()

        // Reset search query
        searchQuery = ""

        // Refresh window list
        windowManager.refreshWindows()
        let updatedWindows = windowManager.windows

        guard !updatedWindows.isEmpty else {
            logger.warning("No windows available to display")
            windowManager.stopCacheRefresh()
            // The monitor optimistically marked the switcher as showing when it consumed the
            // Cmd+Tab; undo that or every later keystroke gets swallowed.
            keyboardMonitor.isShowingSwitcher = false
            return
        }

        // For windows without cached thumbnails, use app icons as placeholders
        let windowsWithPlaceholders = updatedWindows.map { window -> WindowInfo in
            if window.thumbnail == nil, let icon = windowManager.getAppIconForWindow(window) {
                var windowWithIcon = window
                windowWithIcon.thumbnail = icon
                return windowWithIcon
            }
            return window
        }

        // Show switcher immediately (with cached thumbnails or app icon placeholders)
        windows = windowsWithPlaceholders
        selectedIndex = 0
        isShowingSwitcher = true
        keyboardMonitor.isShowingSwitcher = true

        // Create and show switcher window
        displaySwitcherWindow()

        captureFreshThumbnails(for: updatedWindows, generation: invalidateInFlightCaptures())
    }

    /// Refreshes every thumbnail once on open, so previews are current rather than up to a
    /// refresh-interval stale.
    ///
    /// Runs as a single background pass rather than one `async` block per window: dispatching
    /// N concurrent screen captures onto the global queue spawns a thread each and starves the
    /// pool. Results are published one at a time so the UI still fills in progressively.
    private func captureFreshThumbnails(for windowsToCapture: [WindowInfo], generation: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            for window in windowsToCapture {
                // Bail out as soon as this pass is superseded (switcher closed or reopened).
                guard self.currentCaptureGeneration() == generation else { return }

                guard let thumbnail = self.windowManager.captureWindowThumbnail(window) else { continue }

                DispatchQueue.main.async {
                    guard self.currentCaptureGeneration() == generation,
                          self.isShowingSwitcher,
                          let index = self.windows.firstIndex(where: { $0.id == window.id }) else { return }
                    self.windows[index].thumbnail = thumbnail
                    // Push the new image into the live view — mutating `windows` alone does
                    // nothing, since the hosting controller holds a snapshot struct.
                    self.updateSwitcherView()
                }
            }
        }
    }

    private func makeRootView() -> WindowSwitcherView {
        WindowSwitcherView(
            windows: displayedWindows,
            selectedIndex: selectedIndex,
            matchingWindowCount: matchingWindowCount,
            onSelect: { [weak self] selectedWindow in
                self?.activateWindow(selectedWindow)
            },
            searchQuery: searchQuery,
            onCloseWindow: { [weak self] window in
                self?.closeWindow(window)
            },
            onMinimizeWindow: { [weak self] window in
                self?.minimizeWindow(window)
            }
        )
    }

    private func displaySwitcherWindow() {
        if switcherWindow == nil {
            switcherWindow = SwitcherWindow()
        }

        guard let window = switcherWindow else { return }

        // Reuse the hosting controller across activations. Recreating it rebuilds the whole
        // SwiftUI hierarchy on every Cmd+Tab, and the old one stays alive anyway for as long
        // as the window holds it as its contentViewController.
        if hostingController == nil {
            hostingController = NSHostingController(rootView: makeRootView())
            window.contentViewController = hostingController
        } else {
            hostingController?.rootView = makeRootView()
        }

        // Calculate and set window size - limit to 90% of screen width
        guard let screen = NSScreen.main else { return }
        let screenWidth = screen.visibleFrame.width
        let maxWidth = screenWidth * 0.9
        let contentSize = hostingController?.view.fittingSize ?? NSSize(width: 800, height: 400)
        let windowWidth = min(contentSize.width, maxWidth)
        let windowHeight = contentSize.height

        window.setContentSize(NSSize(width: windowWidth, height: windowHeight))

        // Center the window on screen (both horizontally and vertically)
        if let switcherWindow = window as? SwitcherWindow {
            switcherWindow.centerOnScreen()
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Selection

    private func selectNext() {
        let count = displayedWindows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + 1) % count
        logger.info("Advanced to window index: \(self.selectedIndex)")
        updateSwitcherView()
    }

    private func selectPrevious() {
        let count = displayedWindows.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex - 1 + count) % count
        logger.info("Went back to window index: \(self.selectedIndex)")
        updateSwitcherView()
    }

    private func updateSwitcherView() {
        guard hostingController != nil else { return }

        // Reuse existing hosting controller - just update the root view
        hostingController?.rootView = makeRootView()

        // Don't resize window when just changing selection - keep the same size
        // This prevents shaking/jittering when cycling through windows
        // The scroll view will handle showing the selected window
    }

    private func activateSelectedWindow() {
        let visible = displayedWindows
        guard isShowingSwitcher, selectedIndex >= 0, selectedIndex < visible.count else {
            hideSwitcher()
            return
        }

        activateWindow(visible[selectedIndex])
    }

    private func activateWindow(_ window: WindowInfo) {
        windowManager.activateWindow(window)
        hideSwitcher()
    }

    private func hideSwitcher() {
        logger.info("Hiding switcher")
        invalidateInFlightCaptures()
        isShowingSwitcher = false
        keyboardMonitor.isShowingSwitcher = false
        searchQuery = "" // Reset search on hide
        selectedIndex = 0
        switcherWindow?.orderOut(nil)
        // Stop thumbnail caching when switcher is hidden
        windowManager.stopCacheRefresh()
    }

    // MARK: - Search Handling

    private func handleCharacterInput(_ character: String) {
        guard isShowingSwitcher else { return }

        // Ignore non-alphanumeric characters and spaces
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet.whitespaces)
        guard character.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else {
            return
        }

        searchQuery += character
        selectedIndex = 0 // Reset to first filtered window
        updateSwitcherView()
        logger.debug("Search query updated: \(self.searchQuery)")
    }

    private func handleBackspace() {
        guard isShowingSwitcher, !searchQuery.isEmpty else { return }

        searchQuery.removeLast()
        selectedIndex = 0 // Reset to first filtered window
        updateSwitcherView()
        logger.debug("Search query after backspace: \(self.searchQuery)")
    }

    // MARK: - Direct Window Access

    private func handleNumberKey(_ number: Int) {
        guard isShowingSwitcher else { return }

        // Index the visible list — the number badges are drawn over the filtered windows.
        let visible = displayedWindows
        guard number >= 0 && number < visible.count else {
            logger.warning("Number key \(number + 1) pressed but only \(visible.count) windows shown")
            return
        }

        logger.info("Activating window \(number + 1) via number key")
        activateWindow(visible[number])
    }

    // MARK: - Window Actions

    private func closeWindow(_ window: WindowInfo) {
        logger.info("Closing window: \(window.title)")
        windowManager.closeWindow(window)
        removeWindowFromList(window)
    }

    private func minimizeWindow(_ window: WindowInfo) {
        logger.info("Minimizing window: \(window.title)")
        windowManager.minimizeWindow(window)
        removeWindowFromList(window)
    }

    private func removeWindowFromList(_ window: WindowInfo) {
        windows.removeAll { $0.id == window.id }

        let remaining = displayedWindows.count
        if remaining == 0 {
            hideSwitcher()
            return
        }

        // Clamp against the visible list, which is what selectedIndex refers to.
        if selectedIndex >= remaining {
            selectedIndex = remaining - 1
        }
        updateSwitcherView()
    }

    deinit {
        logger.info("SwitcherCoordinator deallocating")
        keyboardMonitor.stopMonitoring()
        switcherWindow?.close()
    }
}
