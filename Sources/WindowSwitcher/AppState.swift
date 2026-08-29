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
                maxSize: NSSize(width: 420, height: 900),
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
                maxSize: NSSize(width: 600, height: 700),
                onClose: { [weak self] in self?.isPreferencesWindowOpen = false }
            )
            preferencesWindow = window
            preferencesWindowObserver = observer
            isPreferencesWindowOpen = true
        }
    }

    /// Creates a window sized to fit its content.
    ///
    /// `maxSize` is a ceiling, not a target: the window takes the smaller of what the view
    /// actually needs and what will fit on screen. Hardcoding a size instead meant a view that
    /// outgrew its number got silently centre-clipped at both ends — which is what happened to
    /// the About window's title and email link.
    private func createWindow<Content: View>(
        title: String,
        view: Content,
        maxSize: NSSize,
        onClose: @escaping () -> Void
    ) -> (NSWindow, NSObjectProtocol) {
        let hostingView = NSHostingView(rootView: view)
        let contentSize = fittedSize(for: hostingView, maxSize: maxSize)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.center()
        window.contentView = hostingView
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

    /// The content's natural size, capped by `maxSize` and by the visible screen.
    private func fittedSize(for hostingView: NSView, maxSize: NSSize) -> NSSize {
        let fitting = hostingView.fittingSize
        let screen = NSScreen.main?.visibleFrame.size ?? NSSize(width: 1440, height: 900)

        return NSSize(
            width: min(fitting.width, min(maxSize.width, screen.width * 0.9)),
            height: min(fitting.height, min(maxSize.height, screen.height * 0.9))
        )
    }
}
