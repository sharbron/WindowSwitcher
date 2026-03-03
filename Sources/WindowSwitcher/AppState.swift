import SwiftUI

/// Manages global state for the WindowSwitcher app
@MainActor
class AppState: ObservableObject {
    @Published var isAboutWindowOpen = false
    @Published var isPreferencesWindowOpen = false

    // Window references for managing SwiftUI windows
    var aboutWindow: NSWindow?
    var preferencesWindow: NSWindow?

    // Stored observer tokens — must be kept to avoid leaking observers
    private var aboutWindowObserver: NSObjectProtocol?
    private var preferencesWindowObserver: NSObjectProtocol?

    func openAboutWindow() {
        if aboutWindow == nil || aboutWindow?.isVisible == false {
            // Remove previous observer before creating a new window
            if let observer = aboutWindowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            let (window, observer) = createWindow(
                title: "About Window Switcher",
                view: AboutView(),
                size: NSSize(width: 420, height: 540),
                onClose: { [weak self] in self?.isAboutWindowOpen = false }
            )
            aboutWindow = window
            aboutWindowObserver = observer
            isAboutWindowOpen = true
        } else {
            aboutWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func openPreferencesWindow() {
        if preferencesWindow == nil || preferencesWindow?.isVisible == false {
            // Remove previous observer before creating a new window
            if let observer = preferencesWindowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            let (window, observer) = createWindow(
                title: "Window Switcher Preferences",
                view: PreferencesView(),
                size: NSSize(width: 600, height: 650),
                onClose: { [weak self] in self?.isPreferencesWindowOpen = false }
            )
            preferencesWindow = window
            preferencesWindowObserver = observer
            isPreferencesWindowOpen = true
        } else {
            preferencesWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func createWindow<Content: View>(
        title: String,
        view: Content,
        size: NSSize,
        onClose: @escaping () -> Void
    ) -> (NSWindow, NSObjectProtocol) {
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

        // Store the returned token so the observer can be properly removed later
        let observer = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onClose() }
        }

        return (window, observer)
    }
}
