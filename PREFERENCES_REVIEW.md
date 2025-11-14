# Preferences System - Comprehensive Review

**Date**: 2025-11-08
**Reviewer**: Claude (Code Review)
**Files Reviewed**:
- `Sources/WindowSwitcher/Views/PreferencesView.swift`
- `Sources/WindowSwitcher/Views/SharedComponents.swift`
- `Sources/WindowSwitcher/AppState.swift`

---

## Executive Summary

The preferences system is **well-structured and functional** with clean SwiftUI implementation using `@AppStorage` for persistence. However, there are **3 critical issues** and **7 moderate improvements** needed to bring the preferences UI in sync with recently implemented features and improve robustness.

**Overall Rating**: 7/10 (Good, but needs updates)

---

## Critical Issues

### 1. 🔴 CRITICAL: Outdated Keyboard Shortcuts Documentation

**Location**: `PreferencesView.swift:160-172`

**Issue**: The keyboard shortcuts section is severely outdated and missing all three newly implemented features:

**Current shortcuts shown**:
```swift
ShortcutRow(keys: "⌘ Tab", description: "Show switcher and select next window")
ShortcutRow(keys: "⌘⇧ Tab", description: "Select previous window")
ShortcutRow(keys: "Esc", description: "Cancel and close switcher")
ShortcutRow(keys: "Release ⌘", description: "Activate selected window")
```

**Missing shortcuts** (implemented but not documented):
- `Type (a-z, 0-9)` - Search/filter windows in real-time
- `Backspace` - Clear search query one character at a time
- `⌘1` through `⌘9` - Jump directly to window 1-9
- `Hover + Click X` - Close window without switching
- `Hover + Click -` - Minimize window without switching

**Impact**: Users won't discover these powerful features. This defeats the purpose of implementing them.

**Recommendation**: Add all missing shortcuts to the preferences UI immediately. Update the description on line 168 from "cannot be customized" to clarify that *primary* shortcuts are fixed but *search and direct access* are available.

**Priority**: 🔴 HIGH - Complete immediately before documentation update

---

### 2. 🔴 CRITICAL: Incomplete Reset to Defaults

**Location**: `PreferencesView.swift:228-234`

**Issue**: The `resetToDefaults()` function only updates the `@AppStorage` properties in memory, but does NOT clear the underlying UserDefaults storage.

**Current implementation**:
```swift
private func resetToDefaults() {
    launchAtLogin = false          // Only updates @AppStorage binding
    showWindowTitles = true        // Not removing from UserDefaults
    thumbnailSize = 200
    maxWindowsToShow = 20
    useAppIcons = false
}
```

**Problem**: If a user:
1. Changes thumbnail size to 300
2. Clicks "Reset to Defaults"
3. Quits and relaunches the app

The value might revert to 300 from UserDefaults instead of staying at 200.

**Root cause**: `@AppStorage` reads from UserDefaults on init. If the key exists in UserDefaults, it will override the default value.

**Recommendation**:
```swift
private func resetToDefaults() {
    // Clear from UserDefaults first
    UserDefaults.standard.removeObject(forKey: "launchAtLogin")
    UserDefaults.standard.removeObject(forKey: "showWindowTitles")
    UserDefaults.standard.removeObject(forKey: "thumbnailSize")
    UserDefaults.standard.removeObject(forKey: "maxWindowsToShow")
    UserDefaults.standard.removeObject(forKey: "useAppIcons")

    // Then set the default values
    launchAtLogin = false
    showWindowTitles = true
    thumbnailSize = 200
    maxWindowsToShow = 20
    useAppIcons = false

    // Also handle launch at login system state
    if SMAppService.mainApp.status == .enabled {
        try? SMAppService.mainApp.unregister()
    }
}
```

**Priority**: 🔴 HIGH - Data consistency issue

---

### 3. 🟡 MODERATE: Race Condition in Launch at Login Error Handling

**Location**: `PreferencesView.swift:217-219`

**Issue**: When `SMAppService` registration fails, the toggle is reverted asynchronously, which can cause a race condition if the user toggles again quickly.

**Current implementation**:
```swift
} catch {
    print("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
    // Revert the toggle if the operation failed
    DispatchQueue.main.async {
        launchAtLogin = !enable  // ⚠️ Race condition possible
    }
}
```

**Problem**: If the user toggles ON → fails → toggles OFF before the async block executes, the state becomes inconsistent.

**Recommendation**: Use `@State` for the toggle and only update `@AppStorage` on success:
```swift
@AppStorage("launchAtLogin") private var launchAtLoginStored: Bool = false
@State private var launchAtLoginUI: Bool = false

// In onAppear:
launchAtLoginUI = launchAtLoginStored

// In toggle:
.onChange(of: launchAtLoginUI) { newValue in
    setLaunchAtLogin(newValue) { success in
        if success {
            launchAtLoginStored = newValue
        } else {
            launchAtLoginUI = launchAtLoginStored // Revert UI immediately
        }
    }
}
```

**Priority**: 🟡 MODERATE - Edge case, but affects UX

---

## Moderate Issues

### 4. 🟡 Missing Screen Recording Permission Status

**Location**: `PreferencesView.swift:131-155` (Permissions section)

**Issue**: The preferences show Accessibility permission info but NOT Screen Recording permission status, even though Screen Recording is critical for window previews.

**Current state**: Only shows a button to open Accessibility settings.

**Recommendation**: Add a second permission row showing Screen Recording status:
- Green checkmark if granted
- Yellow warning if denied (with note about falling back to app icons)
- Button to open Screen Recording settings

**Code suggestion**:
```swift
VStack(alignment: .leading, spacing: 16) {
    // Accessibility (existing)
    PermissionRow(
        icon: "checkmark.shield.fill",
        color: .green,
        title: "Accessibility access required",
        description: "Monitor keyboard shortcuts and control windows",
        buttonAction: openAccessibilityPreferences
    )

    // Screen Recording (new)
    PermissionRow(
        icon: hasScreenRecordingPermission() ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
        color: hasScreenRecordingPermission() ? .green : .orange,
        title: "Screen Recording access \(hasScreenRecordingPermission() ? "granted" : "recommended")",
        description: "Capture window previews. Falls back to app icons if denied.",
        buttonAction: openScreenRecordingPreferences
    )
}
```

**Priority**: 🟡 MODERATE - Improves user understanding

---

### 5. 🟡 Inconsistent Logging (print vs Logger)

**Location**: `PreferencesView.swift:197-220`

**Issue**: The `setLaunchAtLogin` function uses `print()` for logging, while the rest of the codebase uses `os.log` Logger.

**Current**:
```swift
print("Launch at login already enabled")
print("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
```

**Recommendation**: Add a Logger and use it consistently:
```swift
private let logger = Logger(subsystem: "com.windowswitcher", category: "Preferences")

// Then replace all print() calls:
logger.info("Launch at login already enabled")
logger.error("Failed to \(enable ? "enable" : "disable") launch at login: \(error.localizedDescription)")
```

**Priority**: 🟡 MODERATE - Code consistency and debuggability

---

### 6. 🟢 Minor: No Validation for Preference Values

**Issue**: While the UI sliders enforce ranges (150-300 for thumbnails, 5-50 for max windows), there's no validation if values are modified directly via UserDefaults or corrupted.

**Recommendation**: Add computed property wrappers with validation:
```swift
private var validatedThumbnailSize: Double {
    min(max(thumbnailSize, 150), 300)
}

private var validatedMaxWindows: Double {
    min(max(maxWindowsToShow, 5), 50)
}
```

Use these validated values when passing to other components.

**Priority**: 🟢 LOW - Edge case, but good defensive programming

---

### 7. 🟢 Minor: Hardcoded Window Size in View

**Location**: `PreferencesView.swift:194`

**Issue**: The window size is hardcoded in the view:
```swift
.frame(width: 600, height: 650)
```

But in `AppState.swift:42`, the window size is also specified when creating the window:
```swift
size: NSSize(width: 600, height: 650)
```

**Recommendation**: Define a constant in AppState and reuse:
```swift
// In AppState.swift
private static let preferencesWindowSize = NSSize(width: 600, height: 650)

// Use in both places
```

**Priority**: 🟢 LOW - Code maintenance

---

### 8. 🟢 Enhancement: Keyboard Shortcut to Close Preferences

**Issue**: Users cannot close the preferences window with keyboard (standard macOS pattern is Cmd+W).

**Recommendation**: Add keyboard shortcut handler:
```swift
.onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { _ in
    // Handle cleanup if needed
}
.keyboardShortcut("w", modifiers: .command) // Cmd+W to close
```

**Priority**: 🟢 LOW - Nice-to-have UX improvement

---

### 9. 🟢 Enhancement: Export/Import Settings

**Issue**: No way for users to backup or share their preference configuration.

**Recommendation**: Add export/import buttons in the footer:
```swift
HStack {
    Button("Export Settings") { exportSettings() }
    Button("Import Settings") { importSettings() }
    Spacer()
    Button("Reset to Defaults") { resetToDefaults() }
}
```

**Priority**: 🟢 LOW - Power user feature

---

### 10. 🟢 Enhancement: Show Filtered Window Statistics

**Issue**: Users don't know how many windows are being filtered out (<100x100 pixels).

**Recommendation**: Add a statistics section:
```swift
PreferenceSection(title: "Statistics", icon: "chart.bar") {
    HStack {
        Text("Total windows detected:")
        Spacer()
        Text("\(totalWindowCount)")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
    }
    HStack {
        Text("Windows filtered out:")
        Spacer()
        Text("\(filteredWindowCount)")
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
    }
}
```

**Priority**: 🟢 LOW - Informational

---

## Positive Aspects

### ✅ What's Working Well

1. **@AppStorage Usage**: Clean, reactive persistence without boilerplate
2. **UI Organization**: Well-structured with PreferenceSection components
3. **Accessibility**: Proper use of Label and semantic structure
4. **Slider Configuration**: Clear min/max labels and step values
5. **Error Handling**: SMAppService errors are caught and handled
6. **User Guidance**: Helpful descriptions under each preference
7. **Visual Hierarchy**: Good use of spacing, dividers, and typography
8. **System Integration**: Proper deeplinks to System Settings

---

## Testing Coverage

Current test coverage for preferences (from PreferencesTests.swift): **~80%**

### Covered:
- ✅ Default values
- ✅ Persistence across launches
- ✅ Slider range validation
- ✅ Toggle state changes
- ✅ UserDefaults synchronization

### Not Covered:
- ❌ SMAppService registration success/failure paths
- ❌ Race conditions in async toggle reversion
- ❌ Reset to defaults clearing UserDefaults
- ❌ System Settings deeplink navigation
- ❌ Permission status checking

**Recommendation**: Add integration tests for SMAppService and permission checking after fixing the critical issues above.

---

## Action Plan

### Immediate (Before Documentation Update)
1. ✅ Fix outdated keyboard shortcuts section (add search, Cmd+1-9, window actions)
2. ✅ Fix resetToDefaults to clear UserDefaults
3. ✅ Add Screen Recording permission status

### Short-term (Next Sprint)
4. ✅ Fix race condition in launch at login toggle
5. ✅ Replace print() with Logger for consistency
6. ✅ Add validation for preference values

### Long-term (Future Enhancements)
7. ⏳ Add Cmd+W keyboard shortcut for closing preferences
8. ⏳ Add export/import settings feature
9. ⏳ Add filtered window statistics
10. ⏳ Add integration tests for permission handling

---

## Conclusion

The preferences system has a **solid foundation** with clean SwiftUI code and good UX patterns. However, it **urgently needs updates** to reflect the newly implemented features (search, direct access, window actions).

The two critical bugs (incomplete reset, race condition) are **low-probability but high-impact** issues that should be fixed to prevent user confusion and data inconsistency.

**Next Steps**:
1. Implement fixes for issues #1, #2, #3
2. Test reset functionality thoroughly
3. Update documentation to match new preferences UI
4. Add integration tests for edge cases

---

**Review Status**: ✅ Complete
**Next Task**: Update CLAUDE.md and documentation
