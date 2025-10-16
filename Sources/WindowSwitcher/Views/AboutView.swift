import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App Icon and Title
            HStack(spacing: 16) {
                Image(systemName: "square.3.layers.3d")
                    .resizable()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Window Switcher")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Built with SwiftUI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Description
            Text("Windows-style window switching for macOS")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            // Features Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                FeatureCard(icon: "square.stack.3d.up", text: "Window-Level Switching", color: .blue)
                FeatureCard(icon: "photo.on.rectangle", text: "Live Previews", color: .purple)
                FeatureCard(icon: "command", text: "Cmd+Tab Override", color: .orange)
                FeatureCard(icon: "bolt.fill", text: "Native Performance", color: .green)
            }
            .padding(.horizontal)

            Divider()
                .padding(.horizontal)

            // Keyboard Shortcuts
            VStack(spacing: 8) {
                Text("Keyboard Shortcuts")
                    .font(.headline)

                VStack(spacing: 4) {
                    ShortcutRow(keys: "⌘ Tab", description: "Show switcher / Next window")
                    ShortcutRow(keys: "⌘⇧ Tab", description: "Previous window")
                    ShortcutRow(keys: "Esc", description: "Cancel")
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.horizontal)

            // Author
            VStack(spacing: 6) {
                Text("Created by Steven Harbron")
                    .font(.subheadline)

                Button("steve.harbron@icloud.com") {
                    if let url = URL(string: "mailto:steve.harbron@icloud.com") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.link)
                .font(.caption)
            }

            Spacer()
        }
        .padding()
        .frame(width: 420, height: 540)
    }
}

struct FeatureCard: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(text)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
