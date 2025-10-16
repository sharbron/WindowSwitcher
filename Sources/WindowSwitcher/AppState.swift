import SwiftUI

/// Manages global state for the WindowSwitcher app
@MainActor
class AppState: ObservableObject {
    @Published var isAboutWindowOpen = false
    @Published var isPreferencesWindowOpen = false

    // Window references for managing SwiftUI windows
    var aboutWindow: NSWindow?
    var preferencesWindow: NSWindow?

    func openAboutWindow() {
        if aboutWindow == nil || !aboutWindow!.isVisible {
            let window = createWindow(
                title: "About Window Switcher",
                view: AboutView(),
                size: NSSize(width: 420, height: 540)
            )
            aboutWindow = window
            isAboutWindowOpen = true
        } else {
            aboutWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func openPreferencesWindow() {
        if preferencesWindow == nil || !preferencesWindow!.isVisible {
            let window = createWindow(
                title: "Window Switcher Preferences",
                view: PreferencesView(),
                size: NSSize(width: 600, height: 650)
            )
            preferencesWindow = window
            isPreferencesWindowOpen = true
        } else {
            preferencesWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func createWindow<Content: View>(
        title: String,
        view: Content,
        size: NSSize
    ) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.center()
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.isReleasedWhenClosed = false

        // Handle window close
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            MainActor.assumeIsolated {
                if window == self.aboutWindow {
                    self.isAboutWindowOpen = false
                } else if window == self.preferencesWindow {
                    self.isPreferencesWindowOpen = false
                }
            }
        }

        return window
    }
}
