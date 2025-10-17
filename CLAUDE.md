# WindowSwitcher - Development Notes

## Project Overview

WindowSwitcher is a native macOS utility that brings Windows-style window switching to Mac. It allows users to switch between individual windows (not just applications) using Cmd+Tab, with live window previews or app icons.

**Platform**: macOS 13.0+ (Ventura and later)
**Language**: Swift 5.9
**Framework**: SwiftUI
**Build System**: Swift Package Manager

## Architecture

### Core Components

1. **WindowSwitcherApp** - Main app entry point and menu bar integration
2. **AppState** - Global state management for preferences and about windows
3. **WindowManager** - Window enumeration, thumbnail caching, and activation
4. **KeyboardMonitor** - CGEvent tap for intercepting Cmd+Tab shortcuts
5. **SwitcherCoordinator** - Orchestrates switching logic and state
6. **WindowSwitcherView** - SwiftUI interface with auto-scrolling support

### File Structure

```
Sources/WindowSwitcher/
├── WindowSwitcherApp.swift      # App entry, menu bar, delegate
├── AppState.swift               # State management
├── WindowInfo.swift             # Window data model & WindowManager
├── KeyboardMonitor.swift        # Keyboard event handling
├── SwitcherCoordinator.swift    # Switching orchestration
├── WindowSwitcherView.swift     # Main UI view
├── Info.plist                   # Bundle configuration
├── WindowSwitcher.entitlements  # Required capabilities
└── Views/
    ├── AboutView.swift          # About window
    ├── PreferencesView.swift    # Settings window
    └── SharedComponents.swift   # Reusable UI components
```

## Key Features

### Window Management
- **Layer 0 Filtering**: Only shows normal windows (excludes menu bars, dock, etc.)
- **Size Filtering**: Filters out tiny windows (<100x100 pixels) to remove helper windows
- **Smart Sorting**: Prioritizes windows with titles, then sorts alphabetically by app name
- **Thumbnail Caching**: Background refresh every 2 seconds for instant display

### User Experience
- **Auto-Scroll**: Selected window stays centered when navigating many windows
- **Smooth Animations**: 0.2s ease-in-out transitions
- **Compact Layout**: 20px spacing between windows, 32px padding
- **Configurable**: Thumbnail size (150-300px), max windows (5-50)

### Permissions
- **Accessibility**: Required for keyboard monitoring and window activation
- **Screen Recording**: Optional for window previews (falls back to app icons)
- Uses native macOS permission prompts only (no custom alerts)

## Recent Improvements (2025-10-16)

### Bug Fixes
1. ✅ **Launch at Login** - Implemented using `SMAppService` (macOS 13+)
2. ✅ **Window Activation** - Added title matching fallback for better reliability
3. ✅ **Permission Handling** - Removed confusing custom alerts, use native macOS prompts
4. ✅ **Code Cleanup** - Removed unused animation speed preference, extracted duplicate components

### UX Improvements
1. ✅ **Auto-Scroll Navigation** - ScrollViewReader keeps selected window centered
2. ✅ **Window Filtering** - Removes tiny/irrelevant windows, smart sorting
3. ✅ **Compact Layout** - Reduced spacing for better multi-window experience
4. ✅ **Graceful Fallbacks** - App icons when Screen Recording permission denied

### Code Quality
- Git repository initialized
- SwiftLint integration with passing checks
- Removed duplicate code (ShortcutRow component)
- Clean commit history with descriptive messages

## Building the App

### Requirements
- Xcode 15.0+
- macOS 13.0+ (Ventura)
- SwiftLint (optional): `brew install swiftlint`

### Build Commands

```bash
# Using build script (recommended)
./create_app.sh

# Manual build
swift build -c release

# Create DMG for distribution
./create_dmg.sh
```

### Build Output
- **App Bundle**: `WindowSwitcher.app` (~519 KB)
- **DMG**: `WindowSwitcher-1.0.dmg` (for distribution)

## Configuration

### User Preferences (via UserDefaults)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `launchAtLogin` | Bool | false | Auto-start on login |
| `showWindowTitles` | Bool | true | Display window titles below thumbnails |
| `thumbnailSize` | Double | 200 | Thumbnail width in pixels (150-300) |
| `maxWindowsToShow` | Double | 20 | Maximum windows to display (5-50) |
| `useAppIcons` | Bool | false | Use app icons instead of window previews |

### Entitlements Required

```xml
<!-- WindowSwitcher.entitlements -->
<key>com.apple.security.device.audio-input</key>
<false/>
```

No special entitlements required for unsigned builds. For distribution, add code signing entitlements.

## Known Limitations

1. **Screen Recording Permission**: Required for window previews. Falls back to app icons if denied.
2. **Window Matching**: Uses bounds + title matching. May fail for rapidly resizing windows.
3. **Protected Windows**: Cannot capture thumbnails of some system windows.
4. **Performance**: May degrade with >50 windows (configurable limit).

## Troubleshooting

### Cmd+Tab Not Working
- Check Accessibility permission: System Settings > Privacy & Security > Accessibility
- Restart the app after granting permission
- Check Console.app for error logs from "com.windowswitcher"

### No Window Previews
- Grant Screen Recording permission: System Settings > Privacy & Security > Screen Recording
- Or enable "Use app icons instead of previews" in Preferences
- Restart the app after granting permission

### Some Windows Missing
- Windows <100x100 pixels are filtered out (by design)
- System windows and layer != 0 windows are excluded
- Increase "Max windows to show" in Preferences if needed

## Development Workflow

### Git Workflow
```bash
# Current branch structure
main  # Production-ready code

# Recent commits
3a1695e - Remove custom permission alerts - use native macOS prompts
1fe8568 - Fix window preview and UX issues with many windows
c5667d6 - Fix SwiftLint warnings
23f2ac3 - Initial commit with bug fixes
```

### Testing
```bash
# Run the app locally
open WindowSwitcher.app

# Check for memory leaks
leaks -atExit -- .build/release/WindowSwitcher

# View logs
log stream --predicate 'subsystem == "com.windowswitcher"' --level debug
```

### Code Style
- SwiftLint enforced (1 acceptable warning: function body length)
- No force unwraps or force casts
- Proper error handling with os.log Logger
- Swift concurrency (@MainActor, async/await) where appropriate

## Distribution

### Unsigned Distribution (Current)
1. Build with `./create_app.sh`
2. Clear quarantine: `xattr -cr WindowSwitcher.app`
3. Ad-hoc code signature applied automatically

Users must run: `xattr -cr /Applications/WindowSwitcher.app` on first install.

### Signed Distribution (Future)
1. Obtain Apple Developer ID certificate ($99/year)
2. Sign: `codesign --deep --force --sign "Developer ID Application: Name" WindowSwitcher.app`
3. Notarize: `xcrun notarytool submit WindowSwitcher.zip`
4. Staple: `xcrun stapler staple WindowSwitcher.app`

## Future Enhancements

### Potential Features
- [ ] Customizable keyboard shortcuts
- [ ] Window preview zoom on hover
- [ ] Recently used window ordering
- [ ] Search/filter windows by name
- [ ] Dark mode auto-detection
- [ ] Per-app window filtering rules
- [ ] Keyboard shortcuts for direct window access (Cmd+1, Cmd+2, etc.)

### Technical Debt
- Add unit tests for WindowManager and KeyboardMonitor
- Consider refactoring activateWindow (75 lines, SwiftLint warning)
- Add integration tests for keyboard event handling
- Document public APIs with doc comments

## Resources

### Documentation
- [Swift Package Manager](https://swift.org/package-manager/)
- [macOS Accessibility API](https://developer.apple.com/documentation/applicationservices/axuielement_h)
- [CGEvent Tap Guide](https://developer.apple.com/documentation/coregraphics/quartz_event_services)
- [SMAppService Documentation](https://developer.apple.com/documentation/servicemanagement/smappservice)

### Similar Projects
- [AltTab](https://github.com/lwouis/alt-tab-macos) - Open source macOS window switcher
- [Witch](https://manytricks.com/witch/) - Commercial window switcher
- [Contexts](https://contexts.co/) - Window & app switcher for macOS

## Contact

**Author**: Steven Harbron
**Email**: steve.harbron@icloud.com
**GitHub**: [@sharbron](https://github.com/sharbron)
**License**: MIT

---

*Last Updated: 2025-10-16*
*Project Version: 1.0*
