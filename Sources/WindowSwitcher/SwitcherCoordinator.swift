import SwiftUI
import Cocoa
import os.log

class SwitcherCoordinator: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectedIndex = 0
    @Published var isShowingSwitcher = false

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

        keyboardMonitor.startMonitoring()
    }

    private func showSwitcher() {
        logger.info("Showing switcher")

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

        // Capture fresh thumbnails only for windows without cached thumbnails
        for (index, window) in updatedWindows.enumerated() {
            // Skip if window already has a cached thumbnail
            guard window.thumbnail == nil else { continue }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }

                if let thumbnail = self.windowManager.captureWindowThumbnail(window) {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self,
                              self.isShowingSwitcher,
                              index < self.windows.count,
                              self.windows[index].id == window.id else { return }

                        // Update just this window's thumbnail
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
        switcherWindow?.orderOut(nil)
    }

    deinit {
        logger.info("SwitcherCoordinator deallocating")
        keyboardMonitor.stopMonitoring()
        switcherWindow?.close()
    }
}
