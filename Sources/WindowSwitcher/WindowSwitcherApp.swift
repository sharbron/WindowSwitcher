import SwiftUI

@main
struct WindowSwitcherApp: App {
    // AppState is owned by AppDelegate, which is where the menu bar actions that drive it live.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var coordinator: SwitcherCoordinator?
    private var appState: AppState?
    private var permissionPollTimer: Timer?

    private static let permissionPollInterval: TimeInterval = 1.0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create AppState on main actor
        appState = AppState()

        // Create menu bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "square.3.layers.3d",
                accessibilityDescription: "Window Switcher"
            )
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "About",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))
        menu.addItem(NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        ))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: "q"
        ))

        statusItem?.menu = menu

        // Initialize the coordinator
        coordinator = SwitcherCoordinator()

        startMonitoringWhenPermitted()
    }

    /// Starts the event tap, waiting for Accessibility permission if it has not been granted.
    ///
    /// The tap cannot be created until the user approves the app, and approval happens *after*
    /// launch — so starting once at launch and giving up meant a fresh install did nothing
    /// until it was quit and reopened.
    private func startMonitoringWhenPermitted() {
        if coordinator?.startMonitoring() == true {
            return
        }

        // Not trusted yet: show the system prompt, then wait for the user to grant it.
        checkAccessibilityPermissions()

        permissionPollTimer = Timer.scheduledTimer(
            withTimeInterval: Self.permissionPollInterval,
            repeats: true
        ) { [weak self] timer in
            guard AXIsProcessTrusted() else { return }
            guard let self = self else {
                timer.invalidate()
                return
            }
            if self.coordinator?.startMonitoring() == true {
                timer.invalidate()
                self.permissionPollTimer = nil
            }
        }
    }

    @objc func showAbout() {
        Task { @MainActor in
            appState?.openAboutWindow()
        }
    }

    @objc func showPreferences() {
        Task { @MainActor in
            appState?.openPreferencesWindow()
        }
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func checkAccessibilityPermissions() {
        // Request permissions - macOS will show its own prompt
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
