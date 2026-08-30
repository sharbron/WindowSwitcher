import SwiftUI
import ServiceManagement
import ApplicationServices
import Combine
import os.log

/// The Settings window.
///
/// Laid out the way macOS settings windows are: a toolbar of tabs over grouped forms, rather
/// than one long scroll. Each tab is short enough to read without scrolling.
struct PreferencesView: View {
    /// The tab strip otherwise sits flush against the title bar with no breathing room.
    /// Added to the frame height as well, so tabs keep their full content area.
    private static let tabStripTopPadding: CGFloat = 12

    @State private var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AppearanceSettingsTab()
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag(SettingsTab.appearance)

            ShortcutsSettingsTab()
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            PermissionsSettingsTab()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
        }
        .padding(.top, Self.tabStripTopPadding)
        // The window follows this, so it grows and shrinks per tab like macOS settings do.
        .frame(
            width: SettingsTab.width,
            height: selection.contentHeight + Self.tabStripTopPadding
        )
    }
}

/// The Settings tabs, and how tall each one needs to be.
///
/// A `TabView` reports only its tab bar as its ideal height, so the height has to be stated.
/// These are measured from each tab's content; a tab that outgrows its number scrolls inside
/// its form rather than clipping, so being slightly off degrades gently.
enum SettingsTab: Hashable {
    case general
    case appearance
    case shortcuts
    case permissions

    static let width: CGFloat = 540

    var contentHeight: CGFloat {
        switch self {
        case .general: return 330
        case .appearance: return 330
        case .shortcuts: return 620
        // Sized for the worst case, where neither permission is granted and both rows
        // show a button. Granted rows hide their button and simply leave slack.
        case .permissions: return 360
        }
    }
}

// MARK: - General

struct GeneralSettingsTab: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("maxWindowsToShow") private var maxWindowsToShow: Double = 20

    private let logger = Logger(subsystem: "com.windowswitcher", category: "Preferences")

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            } footer: {
                SettingsFooter("Automatically start Window Switcher when you log in.")
            }

            Section {
                LabeledContent("Maximum windows to show") {
                    HStack(spacing: 12) {
                        Slider(value: $maxWindowsToShow, in: 5...50, step: 5)
                        Text("\(Int(maxWindowsToShow))")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            } footer: {
                SettingsFooter("Limit the number of windows displayed in the switcher.")
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset to Defaults", action: resetToDefaults)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: syncLaunchAtLoginToggle)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            syncLaunchAtLoginToggle()
        }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                if SMAppService.mainApp.status == .enabled {
                    logger.info("Launch at login already enabled")
                } else {
                    try SMAppService.mainApp.register()
                    logger.info("Launch at login enabled successfully")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    logger.info("Launch at login disabled successfully")
                } else {
                    logger.info("Launch at login already disabled")
                }
            }
        } catch {
            logger.error("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
            // Revert the toggle if the operation failed
            DispatchQueue.main.async {
                launchAtLogin = !enable
            }
        }
    }

    /// The toggle is only a cached copy of a system setting the user can change elsewhere.
    private func syncLaunchAtLoginToggle() {
        let registered = SMAppService.mainApp.status == .enabled
        if launchAtLogin != registered {
            launchAtLogin = registered
        }
    }

    private func resetToDefaults() {
        logger.info("Resetting preferences to defaults")

        for key in PreferenceKeys.all {
            UserDefaults.standard.removeObject(forKey: key)
        }

        // Write the defaults back so the bindings observing them update immediately.
        launchAtLogin = false
        maxWindowsToShow = 20
        UserDefaults.standard.set(true, forKey: PreferenceKeys.showWindowTitles)
        UserDefaults.standard.set(200.0, forKey: PreferenceKeys.thumbnailSize)
        UserDefaults.standard.set(false, forKey: PreferenceKeys.useAppIcons)

        if SMAppService.mainApp.status == .enabled {
            do {
                try SMAppService.mainApp.unregister()
                logger.info("Launch at login disabled during reset")
            } catch {
                logger.error("Failed to disable launch at login during reset: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Appearance

struct AppearanceSettingsTab: View {
    @AppStorage("useAppIcons") private var useAppIcons: Bool = false
    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true
    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200

    var body: some View {
        Form {
            Section {
                Toggle("Use app icons instead of previews", isOn: $useAppIcons)
            } footer: {
                SettingsFooter(
                    """
                    Show app icons instead of window thumbnails. Automatically used if Screen \
                    Recording permission is not granted.
                    """
                )
            }

            Section {
                Toggle("Show window titles", isOn: $showWindowTitles)
            } footer: {
                SettingsFooter("Display the window title below each thumbnail.")
            }

            Section {
                LabeledContent("Thumbnail size") {
                    HStack(spacing: 12) {
                        Slider(value: $thumbnailSize, in: 150...300, step: 25)
                        Text("\(Int(thumbnailSize)) px")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .trailing)
                    }
                }
                .disabled(useAppIcons)
            } footer: {
                SettingsFooter(
                    useAppIcons
                        ? "Not used while app icons are shown instead of previews."
                        : "Adjust the size of window preview thumbnails."
                )
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsTab: View {
    var body: some View {
        Form {
            Section("Navigation") {
                ShortcutFormRows(shortcuts: SwitcherShortcuts.navigation)
            }

            Section("Search & Filter") {
                ShortcutFormRows(shortcuts: SwitcherShortcuts.search)
            }

            Section {
                ShortcutFormRows(shortcuts: SwitcherShortcuts.windowActions)
            } header: {
                Text("Window Actions")
            } footer: {
                SettingsFooter("Primary shortcuts (⌘Tab, ⌘⇧Tab, Esc) are fixed and cannot be customized.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Permissions

struct PermissionsSettingsTab: View {
    // Refreshed whenever the app regains focus — the user grants these in System Settings and
    // comes back, so a value read once goes stale immediately.
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @State private var isScreenRecordingGranted = CGPreflightScreenCaptureAccess()

    var body: some View {
        Form {
            Section {
                PermissionStatusView(
                    title: "Accessibility",
                    granted: isAccessibilityTrusted,
                    isRequired: true,
                    explanation: """
                        Required to monitor the Cmd+Tab shortcut and to raise, close and \
                        minimize windows.
                        """,
                    buttonTitle: "Open Accessibility Settings",
                    action: SettingsLinks.openAccessibility
                )
            }

            Section {
                PermissionStatusView(
                    title: "Screen Recording",
                    granted: isScreenRecordingGranted,
                    isRequired: false,
                    explanation: """
                        Used to capture live window previews. Without it the switcher falls \
                        back to app icons.
                        """,
                    buttonTitle: "Open Screen Recording Settings",
                    action: SettingsLinks.openScreenRecording
                )
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refresh()
        }
    }

    private func refresh() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
    }
}

// MARK: - Supporting Types

enum PreferenceKeys {
    static let launchAtLogin = "launchAtLogin"
    static let showWindowTitles = "showWindowTitles"
    static let thumbnailSize = "thumbnailSize"
    static let maxWindowsToShow = "maxWindowsToShow"
    static let useAppIcons = "useAppIcons"

    static let all = [launchAtLogin, showWindowTitles, thumbnailSize, maxWindowsToShow, useAppIcons]
}

enum SettingsLinks {
    static func openAccessibility() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    static func openScreenRecording() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Explanatory text under a settings row.
struct SettingsFooter: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shows whether a system permission is actually granted, rather than asserting it is.
struct PermissionStatusView: View {
    let title: String
    let granted: Bool
    /// Required permissions read as an error when missing; optional ones only as a suggestion.
    let isRequired: Bool
    let explanation: String
    let buttonTitle: String
    let action: () -> Void

    private var iconName: String {
        if granted { return "checkmark.circle.fill" }
        return isRequired ? "exclamationmark.triangle.fill" : "info.circle.fill"
    }

    private var iconColor: Color {
        if granted { return .green }
        return isRequired ? .red : .orange
    }

    private var statusText: String {
        if granted { return "Granted" }
        return isRequired ? "Required — not granted" : "Not granted"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundStyle(iconColor)
                Text(title)
                    .fontWeight(.medium)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            SettingsFooter(explanation)

            // Nothing to do once it is granted.
            if !granted {
                Button(buttonTitle, action: action)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}
