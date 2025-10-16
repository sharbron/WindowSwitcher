# Window Switcher

A native macOS utility that brings Windows-style window switching to Mac - switch between individual windows instead of just applications.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%2013.0%2B-lightgrey.svg)
![Swift](https://img.shields.io/badge/swift-5.9-orange.svg)

## Features

- **Window-Level Switching** - See and switch between all open windows, not just applications
- **Live Previews** - Visual thumbnails of each window for easy identification
- **Native Cmd+Tab Override** - Seamlessly replaces the default macOS app switcher
- **Keyboard Navigation**:
  - `Cmd+Tab` - Show switcher and select next window
  - `Cmd+Shift+Tab` - Select previous window
  - `Esc` - Cancel and close switcher
  - Release `Cmd` - Activate selected window
- **Menu Bar Integration** - Runs quietly in the menu bar with preferences access
- **Customizable Settings** - Adjust thumbnail size, animation speed, and behavior
- **Lightweight** - Native performance with minimal resource usage

## Installation

### Download (Easiest)

1. Download [WindowSwitcher-1.0.dmg](../../releases)
2. Open the DMG file
3. Drag WindowSwitcher to Applications
4. **IMPORTANT:** Run this command in Terminal:
   ```bash
   xattr -cr /Applications/WindowSwitcher.app
   ```
5. Launch from Applications
6. Grant Accessibility permissions when prompted

⚠️ **This app is unsigned.** macOS will block it without the command above.

**Why unsigned?** Code signing requires a $99/year Apple Developer account. For an open-source project, the command above is a simple alternative that tells macOS "I trust this app."

### Build from Source

#### Prerequisites
- Xcode 15.0+
- macOS 13.0 (Ventura) or later
- SwiftLint (optional, for code quality):
  ```bash
  brew install swiftlint
  ```

#### Building

**Option A: Using Build Script (Recommended)**
```bash
cd WindowSwitcher
./create_app.sh
```
This creates `WindowSwitcher.app` ready to install.

**Option B: Using Command Line**
```bash
swift build -c release
```

**Option C: Using Xcode**
```bash
open Package.swift
```
Then build in Xcode (Cmd+B)

## Setup

### 1. Grant Accessibility Permissions

WindowSwitcher requires Accessibility permissions to:
- Monitor Cmd+Tab keyboard shortcuts
- Capture window information and thumbnails
- Activate and focus windows

When you first launch the app:
1. macOS will prompt you for Accessibility access
2. Click "Open System Settings"
3. In **Privacy & Security > Accessibility**, enable WindowSwitcher
4. Restart the app

### 2. Optional: Launch at Login

Enable in **Preferences > General > Launch at login** to have WindowSwitcher start automatically when you log in.

## How It Works

### Architecture

WindowSwitcher uses native macOS APIs for efficient window management:

- **WindowManager** - Enumerates all windows using macOS Accessibility API and CGWindowList
- **KeyboardMonitor** - Intercepts Cmd+Tab using CGEvent taps to override system behavior
- **SwitcherCoordinator** - Orchestrates the window switching logic and state management
- **WindowSwitcherView** - SwiftUI interface that displays window thumbnails with smooth animations
- **AppState** - Manages application state and window preferences

### Technical Details

- `AXUIElement` API to enumerate and activate windows across all applications
- `CGEvent` taps to intercept Cmd+Tab before the system app switcher activates
- `CGWindowListCopyWindowInfo` to capture window metadata and generate thumbnails
- SwiftUI for modern, native UI with smooth animations
- Runs as menu bar app (LSUIElement = true) with no Dock icon
- Async thumbnail capture for responsive UI

## Usage

1. Press `Cmd+Tab` to open the window switcher
2. Keep holding `Cmd` and press `Tab` to cycle through windows
3. Press `Shift+Tab` while holding `Cmd` to cycle backwards
4. Release `Cmd` to activate the selected window
5. Click on any window thumbnail to switch to it immediately

## Development

### Project Structure

```
WindowSwitcher/
├── Package.swift                    # Swift Package Manager manifest
├── Sources/
│   └── WindowSwitcher/
│       ├── WindowSwitcherApp.swift  # Main app entry point
│       ├── AppState.swift           # State management
│       ├── SwitcherCoordinator.swift # Switching logic coordinator
│       ├── WindowInfo.swift         # Window data structures
│       ├── KeyboardMonitor.swift    # Keyboard event monitoring
│       ├── WindowSwitcherView.swift # Main switcher UI
│       ├── Info.plist               # App bundle configuration
│       └── Views/
│           ├── AboutView.swift      # About window
│           └── PreferencesView.swift # Preferences window
├── .swiftlint.yml                   # SwiftLint configuration
├── .gitignore                       # Git ignore rules
├── create_app.sh                    # Build script
├── create_dmg.sh                    # DMG creation script
├── LICENSE                          # MIT License
└── README.md
```

### Code Quality

This project uses [SwiftLint](https://github.com/realm/SwiftLint) to ensure code quality and consistency.

**Install SwiftLint:**
```bash
brew install swiftlint
```

SwiftLint runs automatically during builds via `create_app.sh`. You can also run it manually:
```bash
swiftlint
```

### Customization

You can customize WindowSwitcher by:

- **Thumbnail size** - Adjust in Preferences or modify `thumbnailWidth` and `thumbnailHeight` in `WindowSwitcherView.swift`
- **Window filtering** - Modify the window enumeration logic in `WindowInfo.swift` to include/exclude certain windows
- **Appearance** - Customize colors, spacing, and styling in `WindowSwitcherView.swift`
- **Keyboard shortcuts** - Currently hardcoded to Cmd+Tab; can be made configurable in a future update

## Troubleshooting

### The switcher doesn't appear when pressing Cmd-Tab

- Ensure Accessibility permissions are granted
- Check that the app is running (menu bar icon should be visible)
- Try restarting the app

### Some windows don't appear in the switcher

- Some system windows and background processes are filtered out by design
- Windows with `layer != 0` are excluded (menu bars, dock, etc.)

### Window activation doesn't work

- Verify Accessibility permissions are granted
- Some apps may have special window management that conflicts

## Known Limitations

- Cannot capture thumbnails of some protected system windows
- Window matching by title may not be perfect for all applications
- Performance may vary with large numbers of windows (>50)

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Accessibility permissions

## Distribution

### Building for Distribution

```bash
# Build release version
./create_app.sh

# Create DMG installer
./create_dmg.sh
```

This creates `WindowSwitcher-1.0.dmg` with:
- The app bundle
- A symbolic link to the Applications folder
- Installation instructions

### Code Signing (Optional)

For distribution outside the Mac App Store, sign your app:

```bash
codesign --deep --force --sign "Developer ID Application: Your Name" \
  WindowSwitcher.app
```

For full notarization (required for Gatekeeper approval):
1. Sign with Developer ID certificate
2. Notarize with Apple: `xcrun notarytool submit`
3. Staple the notarization ticket
4. See Apple's [notarization documentation](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Support

Found a bug or have a feature request? Please open an issue on GitHub.

## Author

**Steven Harbron**
- Email: steve.harbron@icloud.com
- GitHub: [@sharbron](https://github.com/sharbron)

## License

MIT License

Copyright (c) 2025 Steven Harbron

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Acknowledgments

Built with:
- [Swift](https://swift.org/) - Programming language
- SwiftUI - Modern declarative UI framework
- macOS Accessibility API - Window management
- Core Graphics - Window thumbnails
