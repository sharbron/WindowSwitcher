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
        // Check if we have accessibility permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let hasPermission = AXIsProcessTrustedWithOptions(options)

        if !hasPermission {
            // Show a helpful alert after a short delay to let the system prompt appear first
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.showPermissionAlert()
            }
        }
    }

    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Window Switcher needs Accessibility permissions to monitor keyboard shortcuts and control windows.

        Please grant permission in System Settings > Privacy & Security > Accessibility.

        The app will work once you grant permission and restart it.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Remind Me Later")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // Open System Settings
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
        case .alertSecondButtonReturn:
            // Quit
            NSApplication.shared.terminate(nil)
        default:
            // Remind Me Later - do nothing
            break
        }
    }
}
