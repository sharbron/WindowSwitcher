import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @AppStorage("showWindowTitles") private var showWindowTitles: Bool = true
    @AppStorage("thumbnailSize") private var thumbnailSize: Double = 200
    @AppStorage("maxWindowsToShow") private var maxWindowsToShow: Double = 20
    @AppStorage("useAppIcons") private var useAppIcons: Bool = false

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
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "checkmark.shield.fill")
                                    .foregroundColor(.green)
                                Text("Accessibility access required")
                                    .font(.subheadline)
                            }

                            Text(
                                """
                                Window Switcher needs Accessibility permissions to \
                                monitor keyboard shortcuts and control windows.
                                """
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)

                            Button("Open System Settings") {
                                openAccessibilityPreferences()
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 4)
                        }
                    }

                    Divider()

                    // Keyboard Shortcuts Section
                    PreferenceSection(title: "Keyboard Shortcuts", icon: "command") {
                        VStack(alignment: .leading, spacing: 8) {
                            ShortcutRow(keys: "⌘ Tab", description: "Show switcher and select next window")
                            ShortcutRow(keys: "⌘⇧ Tab", description: "Select previous window")
                            ShortcutRow(keys: "Esc", description: "Cancel and close switcher")
                            ShortcutRow(keys: "Release ⌘", description: "Activate selected window")
                        }

                        Text("Keyboard shortcuts cannot be customized at this time.")
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
                    print("Launch at login already enabled")
                } else {
                    try SMAppService.mainApp.register()
                    print("Launch at login enabled successfully")
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    print("Launch at login disabled successfully")
                } else {
                    print("Launch at login already disabled")
                }
            }
        } catch {
            print("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
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

    private func resetToDefaults() {
        launchAtLogin = false
        showWindowTitles = true
        thumbnailSize = 200
        maxWindowsToShow = 20
        useAppIcons = false
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
