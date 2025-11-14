import SwiftUI
import Cocoa
import os.log

class SwitcherCoordinator: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectedIndex = 0
    @Published var isShowingSwitcher = false
    @Published var searchQuery = ""

    private let windowManager = WindowManager()
    private let keyboardMonitor = KeyboardMonitor()
    private var switcherWindow: NSWindow?
    private let logger = Logger(subsystem: "com.windowswitcher", category: "SwitcherCoordinator")

    init() {
        setupKeyboardMonitor()
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

        keyboardMonitor.startMonitoring()
    }

    private func showSwitcher() {
        logger.info("Showing switcher")

        // Reset search query
        searchQuery = ""

        // Refresh window list
        windowManager.refreshWindows()
        let updatedWindows = windowManager.windows

        guard !updatedWindows.isEmpty else {
            logger.warning("No windows available to display")
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

        // Capture fresh thumbnails for all windows when switcher opens
        // This ensures previews are always up-to-date
        for (index, window) in updatedWindows.enumerated() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                if let thumbnail = self.windowManager.captureWindowThumbnail(window) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self,
                              self.isShowingSwitcher,
                              index < self.windows.count,
                              self.windows[index].id == window.id else { return }

                        // Update with fresh thumbnail
                        self.windows[index].thumbnail = thumbnail
                    }
                }
            }
        }
    }

    private func displaySwitcherWindow() {
        if switcherWindow == nil {
            switcherWindow = SwitcherWindow()
        }

        guard let window = switcherWindow else { return }

        let hostingController = NSHostingController(
            rootView: WindowSwitcherView(
                windows: windows,
                selectedIndex: selectedIndex,
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
        )

        window.contentViewController = hostingController

        // Update window size based on content and center
        let contentSize = hostingController.view.fittingSize
        window.setContentSize(contentSize)

        // Center the window on screen (both horizontally and vertically)
        if let switcherWindow = window as? SwitcherWindow {
            switcherWindow.centerOnScreen()
        } else {
            window.center()
        }

        window.makeKeyAndOrderFront(nil)
    }

    private func selectNext() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        updateSwitcherView()
    }

    private func selectPrevious() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex - 1 + windows.count) % windows.count
        updateSwitcherView()
    }

    private func updateSwitcherView() {
        guard let window = switcherWindow else { return }

        let hostingController = NSHostingController(
            rootView: WindowSwitcherView(
                windows: windows,
                selectedIndex: selectedIndex,
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
        )

        window.contentViewController = hostingController

        // Re-center after content update
        let contentSize = hostingController.view.fittingSize
        window.setContentSize(contentSize)

        // Center the window on screen (both horizontally and vertically)
        if let switcherWindow = window as? SwitcherWindow {
            switcherWindow.centerOnScreen()
        } else {
            window.center()
        }
    }

    private func activateSelectedWindow() {
        guard isShowingSwitcher, !windows.isEmpty, selectedIndex < windows.count else {
            hideSwitcher()
            return
        }

        let selectedWindow = windows[selectedIndex]
        activateWindow(selectedWindow)
    }

    private func activateWindow(_ window: WindowInfo) {
        windowManager.activateWindow(window)
        hideSwitcher()
    }

    private func hideSwitcher() {
        logger.info("Hiding switcher")
        isShowingSwitcher = false
        keyboardMonitor.isShowingSwitcher = false
        searchQuery = "" // Reset search on hide
        switcherWindow?.orderOut(nil)
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
        guard number >= 0 && number < windows.count else {
            logger.warning("Number key \(number + 1) pressed but only \(self.windows.count) windows available")
            return
        }

        logger.info("Activating window \(number + 1) via number key")
        let targetWindow = windows[number]
        activateWindow(targetWindow)
    }

    // MARK: - Window Actions

    private func closeWindow(_ window: WindowInfo) {
        logger.info("Closing window: \(window.title)")

        windowManager.closeWindow(window)

        // Remove from list and update view
        windows.removeAll { $0.id == window.id }

        if windows.isEmpty {
            hideSwitcher()
        } else {
            // Adjust selected index if needed
            if selectedIndex >= windows.count {
                selectedIndex = windows.count - 1
            }
            updateSwitcherView()
        }
    }

    private func minimizeWindow(_ window: WindowInfo) {
        logger.info("Minimizing window: \(window.title)")

        windowManager.minimizeWindow(window)

        // Remove from list and update view
        windows.removeAll { $0.id == window.id }

        if windows.isEmpty {
            hideSwitcher()
        } else {
            // Adjust selected index if needed
            if selectedIndex >= windows.count {
                selectedIndex = windows.count - 1
            }
            updateSwitcherView()
        }
    }

    deinit {
        logger.info("SwitcherCoordinator deallocating")
        keyboardMonitor.stopMonitoring()
        switcherWindow?.close()
    }
}
