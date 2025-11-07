# Window Switcher - Installation Guide

A native macOS utility that brings Windows-style window switching to Mac.

## Features
- 🪟 Switch between individual windows, not just applications
- 🖼️ Live window previews or app icons
- ⌨️ Native Cmd+Tab override with smooth navigation
- 🎯 Auto-scroll to keep selected window centered
- 🎨 Smart window filtering (removes tiny/irrelevant windows)
- ⚙️ Customizable thumbnail size and display options
- 🚀 Launch at login support
- ⚡ Native Swift - fast and lightweight (~20MB RAM)

## Installation

### Easy Install (Recommended)

1. **Download** `WindowSwitcher-1.0.dmg`
2. **Open** the DMG file (double-click)
3. **Drag** `WindowSwitcher.app` to your Applications folder
4. **IMPORTANT:** Don't double-click the app yet! Follow step 5 first.
5. **Remove quarantine** (required for unsigned apps):
   - Open Terminal
   - Run: `xattr -cr /Applications/WindowSwitcher.app`
   - Or right-click the app → Open → Open Anyway (when macOS warns)
6. **Open** WindowSwitcher from Applications
7. **Grant permissions** when macOS prompts:
   - **Accessibility** (required) - for Cmd+Tab monitoring and window activation
   - **Screen Recording** (optional) - for window previews (falls back to app icons if denied)

### Why the Extra Step?

This app is not code-signed (which requires a $99/year Apple Developer account). macOS blocks unsigned apps downloaded from the internet as a security measure. The `xattr -cr` command simply tells macOS "I trust this app."

### Build from Source (Alternative)

If you prefer to build from source:

```bash
# Clone the repository
git clone https://github.com/sharbron/WindowSwitcher.git
cd WindowSwitcher

# Build the app
swift build -c release
./create_app.sh

# Remove quarantine and open
xattr -cr WindowSwitcher.app
open WindowSwitcher.app
```

## Setup

### Required: Accessibility Permission

WindowSwitcher **requires** Accessibility permission to:
- Monitor Cmd+Tab keyboard shortcuts
- Activate and focus windows
- Access window information

**To grant permission:**
1. Open WindowSwitcher (macOS will prompt for permission)
2. Click **"Open System Settings"**
3. In **Privacy & Security → Accessibility**, enable WindowSwitcher
4. Restart the app

**Or manually:**
1. Open **System Settings**
2. Go to **Privacy & Security → Accessibility**
3. Click the **+** button and add WindowSwitcher
4. Ensure the checkbox is enabled

### Optional: Screen Recording Permission

For **window previews/thumbnails**, grant Screen Recording permission:
1. Open **System Settings**
2. Go to **Privacy & Security → Screen Recording**
3. Enable WindowSwitcher
4. Restart the app

**Note:** If you deny this permission, WindowSwitcher will use app icons instead of window previews (still fully functional).

### Optional: Launch at Login

To have WindowSwitcher start automatically when you log in:

**Option 1 (In-App):**
1. Click the WindowSwitcher menu bar icon
2. Open **Preferences**
3. Enable **"Launch at login"**

**Option 2 (System Settings):**
1. Open **System Settings → General → Login Items**
2. Click the **+** button
3. Select **WindowSwitcher** from Applications

## Usage

1. Press **Cmd+Tab** to open the window switcher
2. Keep holding **Cmd** and press **Tab** to cycle through windows
3. Press **Shift+Tab** while holding **Cmd** to cycle backwards
4. Release **Cmd** to activate the selected window
5. Press **Esc** to cancel without switching
6. Configure preferences via the menu bar icon

## System Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac
- Accessibility permission (required)
- Screen Recording permission (optional, for window previews)

## Uninstallation

1. **Quit** the app from menu bar
2. **Remove from Login Items** (if added)
3. **Delete** from Applications folder
4. **Optional**: Remove preferences
   ```bash
   defaults delete com.windowswitcher
   ```

## Troubleshooting

**"App can't be opened because it is from an unidentified developer" or "App is damaged"?**

This is normal for unsigned apps. Two solutions:

**Option 1 (Easiest):**
```bash
xattr -cr /Applications/WindowSwitcher.app
```
Then open the app normally.

**Option 2:**
- Right-click the app → Open → Open Anyway
- Or go to System Settings → Privacy & Security → Open Anyway

**Switcher doesn't appear when pressing Cmd+Tab?**
- Ensure Accessibility permission is granted (see Setup section above)
- Check that the app is running (menu bar icon should be visible)
- Try restarting the app

**No window previews shown?**
- Grant Screen Recording permission in System Settings → Privacy & Security → Screen Recording
- Or enable "Use app icons instead of previews" in Preferences
- Restart the app after granting permission

**Some windows are missing?**
- Windows smaller than 100x100 pixels are filtered out by design
- System windows and background processes are excluded
- Increase "Max windows to show" in Preferences if needed

**WindowSwitcher uses too much memory?**
- Reduce thumbnail size in Preferences
- Reduce "Max windows to show" in Preferences
- Disable window previews and use app icons instead

## Privacy & Security

- **Local Only** - No network access, all processing happens on your Mac
- **No Data Collection** - WindowSwitcher doesn't collect or transmit any data
- **Permissions Used**:
  - Accessibility: Required for keyboard monitoring and window activation
  - Screen Recording: Optional for window thumbnails (falls back to app icons)
- **Open Source** - Full source code available on GitHub for transparency

## Support

Found a bug or have a feature request? Please open an issue on GitHub:
https://github.com/sharbron/WindowSwitcher/issues

## License

MIT License - Free to use and modify

---

**Author**: Steven Harbron
**GitHub**: [@sharbron](https://github.com/sharbron)
**Email**: steve.harbron@icloud.com
