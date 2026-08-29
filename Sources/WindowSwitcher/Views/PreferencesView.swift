import SwiftUI
import ServiceManagement
import ApplicationServices
import Combine
import os.log

struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true
    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200
    @AppStorage("maxWindowsToShow") private var maxWindowsToShow: Double = 20
    @AppStorage("useAppIcons") private var useAppIcons: Bool = false

    // Live permission state, refreshed whenever the app regains focus — the user grants these
    // in System Settings and comes back, so a value read once at init goes stale immediately.
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()
    @State private var isScreenRecordingGranted = CGPreflightScreenCaptureAccess()

    private let logger = Logger(subsystem: "com.windowswitcher", category: "Preferences")

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            // Settings Content
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // General Section
                    PreferenceSection(title: "General", icon: "gearshape") {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                setLaunchAtLogin(newValue)
                            }

                        Text("Automatically start Window Switcher when you log in.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Appearance Section
                    PreferenceSection(title: "Appearance", icon: "paintbrush") {
                        Toggle("Use app icons instead of previews", isOn: $useAppIcons)

                        Text(
                            """
                            Show app icons instead of window thumbnails. \
                            Automatically enabled if Screen Recording permission is not granted.
                            """
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)

                        Divider()
                            .padding(.vertical, 8)

                        Toggle("Show window titles", isOn: $showWindowTitles)

                        Text("Display the window title below each thumbnail.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()
                            .padding(.vertical, 8)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Thumbnail size:")
                                Spacer()
                                Text("\(Int(thumbnailSize)) px")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }

                            Slider(value: $thumbnailSize, in: 150...300, step: 25) {
                                EmptyView()
                            } minimumValueLabel: {
                                Text("150")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } maximumValueLabel: {
                                Text("300")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Adjust the size of window preview thumbnails.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Behavior Section
                    PreferenceSection(title: "Behavior", icon: "slider.horizontal.3") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Maximum windows to show:")
                                Spacer()
                                Text("\(Int(maxWindowsToShow))")
                                    .foregroundColor(.secondary)
                                    .font(.system(.body, design: .monospaced))
                            }

                            Slider(value: $maxWindowsToShow, in: 5...50, step: 5) {
                                EmptyView()
                            } minimumValueLabel: {
                                Text("5")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } maximumValueLabel: {
                                Text("50")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Limit the number of windows displayed in the switcher.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Permissions Section
                    PreferenceSection(title: "Permissions", icon: "lock.shield") {
                        VStack(alignment: .leading, spacing: 16) {
                            // Accessibility Permission
                            PermissionStatusView(
                                title: "Accessibility access",
                                granted: isAccessibilityTrusted,
                                isRequired: true,
                                explanation: """
                                    Window Switcher needs Accessibility permissions to \
                                    monitor keyboard shortcuts and control windows.
                                    """,
                                buttonTitle: "Open Accessibility Settings",
                                action: openAccessibilityPreferences
                            )

                            Divider()

                            // Screen Recording Permission
                            PermissionStatusView(
                                title: "Screen Recording access",
                                granted: isScreenRecordingGranted,
                                isRequired: false,
                                explanation: """
                                    Capture live window previews for better identification. \
                                    Falls back to app icons if denied.
                                    """,
                                buttonTitle: "Open Screen Recording Settings",
                                action: openScreenRecordingPreferences
                            )
                        }
                    }

                    Divider()

                    // Keyboard Shortcuts Section
                    PreferenceSection(title: "Keyboard Shortcuts", icon: "command") {
                        VStack(alignment: .leading, spacing: 16) {
                            ShortcutGroup(title: "Navigation", shortcuts: SwitcherShortcuts.navigation)
                            ShortcutGroup(title: "Search & Filter", shortcuts: SwitcherShortcuts.search)
                            ShortcutGroup(title: "Direct Access", shortcuts: SwitcherShortcuts.directAccess)
                            ShortcutGroup(title: "Window Actions", shortcuts: SwitcherShortcuts.windowActions)
                        }

                        Text("Primary shortcuts (⌘Tab, ⌘⇧Tab, Esc) are fixed and cannot be customized.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 8)
                    }
                }
                .padding(24)
            }

            Divider()

            // Footer
            HStack {
                Text("Window Switcher v\(appVersion)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Reset to Defaults") {
                    resetToDefaults()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 600)
        // Keep the live permission readout honest when the user returns from System Settings.
        .onAppear(perform: refreshPermissionStatus)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
    }

    private func refreshPermissionStatus() {
        isAccessibilityTrusted = AXIsProcessTrusted()
        isScreenRecordingGranted = CGPreflightScreenCaptureAccess()
        syncLaunchAtLoginToggle()
    }

    /// The toggle is only a cached copy of a system setting the user can change elsewhere.
    private func syncLaunchAtLoginToggle() {
        let registered = SMAppService.mainApp.status == .enabled
        if launchAtLogin != registered {
            launchAtLogin = registered
        }
    }

    /// Read from the bundle so the footer cannot drift from the shipped version.
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
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

    private func openAccessibilityPreferences() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func openScreenRecordingPreferences() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    private func resetToDefaults() {
        logger.info("Resetting preferences to defaults")

        // First, clear all preference keys from UserDefaults
        UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        UserDefaults.standard.removeObject(forKey: "showWindowTitles")
        UserDefaults.standard.removeObject(forKey: "thumbnailSize")
        UserDefaults.standard.removeObject(forKey: "maxWindowsToShow")
        UserDefaults.standard.removeObject(forKey: "useAppIcons")

        // Then set the default values (which will write back to UserDefaults)
        launchAtLogin = false
        showWindowTitles = true
        thumbnailSize = 200
        maxWindowsToShow = 20
        useAppIcons = false

        // Also handle launch at login system state
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

// MARK: - Helper Views

struct PreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(.primary)

            content
        }
    }
}

/// A titled group of shortcuts.
struct ShortcutGroup: View {
    let title: String
    let shortcuts: [KeyboardShortcutItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            ShortcutList(shortcuts: shortcuts)
        }
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
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(explanation)
                .font(.caption)
                .foregroundColor(.secondary)

            // Nothing to do once it is granted.
            if !granted {
                Button(buttonTitle, action: action)
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            }
        }
    }
}
