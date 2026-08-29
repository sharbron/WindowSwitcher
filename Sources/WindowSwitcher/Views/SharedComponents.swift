import SwiftUI

/// A single keyboard shortcut and what it does.
struct KeyboardShortcutItem: Identifiable {
    let id = UUID()
    let keys: String
    let description: String

    init(_ keys: String, _ description: String) {
        self.keys = keys
        self.description = description
    }
}

/// The one place shortcuts are described.
///
/// About and Preferences previously kept separate hand-written lists, which had already
/// drifted — About omitted Backspace, the hover actions, and the release-to-activate gesture.
enum SwitcherShortcuts {
    static let navigation = [
        KeyboardShortcutItem("⌘ Tab", "Show switcher and select next window"),
        KeyboardShortcutItem("⌘⇧ Tab", "Select previous window"),
        KeyboardShortcutItem("Release ⌘", "Activate selected window"),
        KeyboardShortcutItem("Esc", "Cancel and close switcher")
    ]

    static let search = [
        KeyboardShortcutItem("Type", "Search windows by title or app name"),
        KeyboardShortcutItem("Delete", "Delete a search character")
    ]

    static let directAccess = [
        KeyboardShortcutItem("⌘ 1-9", "Jump directly to window 1-9")
    ]

    static let windowActions = [
        KeyboardShortcutItem("Hover ✕", "Close window"),
        KeyboardShortcutItem("Hover −", "Minimize window")
    ]

    /// Condensed set for the About window.
    static let essentials = [
        KeyboardShortcutItem("⌘ Tab", "Show switcher / next window"),
        KeyboardShortcutItem("⌘⇧ Tab", "Previous window"),
        KeyboardShortcutItem("Type", "Search by title or app name"),
        KeyboardShortcutItem("⌘ 1-9", "Jump to window 1-9"),
        KeyboardShortcutItem("Esc", "Cancel")
    ]
}

/// A keycap-styled label for a shortcut.
struct KeyCap: View {
    let keys: String

    var body: some View {
        Text(keys)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .fixedSize()
    }
}

/// A list of shortcuts whose descriptions line up in a column.
///
/// A plain HStack per row left the descriptions ragged, because each keycap is a different
/// width. A Grid sizes the keycap column to the widest cap and aligns the rest against it.
struct ShortcutList: View {
    let shortcuts: [KeyboardShortcutItem]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
            ForEach(shortcuts) { shortcut in
                GridRow {
                    KeyCap(keys: shortcut.keys)
                        .gridColumnAlignment(.trailing)

                    Text(shortcut.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

/// Displays a keyboard shortcut with its description.
struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            KeyCap(keys: keys)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }
}
