import SwiftUI
import ServiceManagement
import os.log

struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true
    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200
    @AppStorage("maxWindowsToShow") private var maxWindowsToShow: Double = 20
    @AppStorage("useAppIcons") private var useAppIcons: Bool = false

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
                                Text("Thumbnail Size")
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
                                Text("Max Windows")
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
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(.green)
                                    Text("Accessibility access required")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                Text(
                                    """
                                    Window Switcher needs Accessibility permissions to \
                                    monitor keyboard shortcuts and control windows.
                                    """
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)

                                Button("Open Accessibility Settings") {
                                    openAccessibilityPreferences()
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }

                            Divider()

                            // Screen Recording Permission
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .foregroundColor(.orange)
                                    Text("Screen Recording access recommended")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                Text(
                                    """
                                    Capture live window previews for better identification. \
                                    Falls back to app icons if denied.
                                    """
                                )
                                .font(.caption)
                                .foregroundColor(.secondary)

                                Button("Open Screen Recording Settings") {
                                    openScreenRecordingPreferences()
                                }
                                .buttonStyle(.bordered)
                                .padding(.top, 4)
                            }
                        }
                    }

                    Divider()

                    // Keyboard Shortcuts Section
                    PreferenceSection(title: "Keyboard Shortcuts", icon: "command") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Navigation")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 4)

                            ShortcutRow(keys: "⌘ Tab", description: "Show switcher and select next window")
                            ShortcutRow(keys: "⌘⇧ Tab", description: "Select previous window")
                            ShortcutRow(keys: "Esc", description: "Cancel and close switcher")
                            ShortcutRow(keys: "Release ⌘", description: "Activate selected window")

                            Text("Search & Filter")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 12)

                            ShortcutRow(keys: "Type (a-z, 0-9)", description: "Search windows by title or app name")
                            ShortcutRow(keys: "⌫ Backspace", description: "Clear search query")

                            Text("Direct Access")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 12)

                            ShortcutRow(keys: "⌘ 1-9", description: "Jump directly to window 1-9")

                            Text("Window Actions")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .padding(.top, 12)

                            ShortcutRow(keys: "Hover + Click ✕", description: "Close window")
                            ShortcutRow(keys: "Hover + Click −", description: "Minimize window")
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
                Text("Window Switcher v1.0")
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
        .frame(width: 600, height: 650)
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
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func openScreenRecordingPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
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
