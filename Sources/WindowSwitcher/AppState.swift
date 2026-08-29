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
        if let window = aboutWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            if let observer = aboutWindowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            let (window, observer) = createWindow(
                title: "About Window Switcher",
                view: AboutView(),
                onClose: { [weak self] in self?.isAboutWindowOpen = false }
            )
            aboutWindow = window
            aboutWindowObserver = observer
            isAboutWindowOpen = true
        }
    }

    func openPreferencesWindow() {
        if let window = preferencesWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            if let observer = preferencesWindowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            let (window, observer) = createWindow(
                title: "Window Switcher Preferences",
                view: PreferencesView(),
                onClose: { [weak self] in self?.isPreferencesWindowOpen = false }
            )
            preferencesWindow = window
            preferencesWindowObserver = observer
            isPreferencesWindowOpen = true
        }
    }

    /// Creates a window that sizes itself to its SwiftUI content, and keeps doing so.
    ///
    /// Hosting the view in an `NSHostingController` set as the window's `contentViewController`
    /// (rather than assigning `contentView` directly) makes AppKit track the content's ideal
    /// size — so the Settings window grows and shrinks as you move between tabs, the way macOS
    /// settings windows do, and no view can be clipped by a hardcoded number the way the About
    /// window's was.
    private func createWindow<Content: View>(
        title: String,
        view: Content,
        onClose: @escaping () -> Void
    ) -> (NSWindow, NSObjectProtocol) {
        let controller = NSHostingController(rootView: view)
        let window = NSWindow(contentViewController: controller)

        window.styleMask = [.titled, .closable, .miniaturizable]
        window.title = title
        window.isReleasedWhenClosed = false

        // A backstop only: content should never want more than the screen, but if it ever does,
        // clamp rather than opening a window taller than the display.
        if let visible = NSScreen.main?.visibleFrame.size {
            window.contentMaxSize = NSSize(width: visible.width * 0.9, height: visible.height * 0.9)
        }

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

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
