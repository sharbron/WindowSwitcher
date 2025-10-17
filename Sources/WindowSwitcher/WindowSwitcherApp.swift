import SwiftUI

@main
struct WindowSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

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

        // Check accessibility permissions
        checkAccessibilityPermissions()

        // Initialize the coordinator
        coordinator = SwitcherCoordinator()
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
