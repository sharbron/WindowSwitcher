# WindowSwitcher - Comprehensive Test Plan

## Table of Contents
1. [Testing Strategy](#testing-strategy)
2. [Unit Tests](#unit-tests)
3. [Integration Tests](#integration-tests)
4. [Manual Testing](#manual-testing)
5. [Performance Tests](#performance-tests)
6. [Edge Cases & Error Handling](#edge-cases--error-handling)
7. [CI/CD Integration](#cicd-integration)

---

## Testing Strategy

### Testing Pyramid
```
    /\
   /  \     E2E Tests (5%)
  /____\    Integration Tests (15%)
 /      \   Unit Tests (80%)
/__________\
```

### Test Coverage Goals
- **Overall**: 70%+ code coverage
- **Critical Paths**: 90%+ coverage
  - Window activation logic
  - Keyboard event handling
  - Activation history management
- **UI Components**: 50%+ coverage

### Testing Approach
1. **Unit Tests** - Test individual components in isolation
2. **Integration Tests** - Test component interactions
3. **Manual Tests** - UI/UX validation and permission flows
4. **Performance Tests** - Validate performance with many windows

---

## Unit Tests

### ✅ Implemented

#### 1. WindowInfo Model Tests (`WindowInfoTests.swift`)
- [x] Equality based on ID
- [x] Inequality with different IDs
- [x] Identifiable protocol conformance
- [x] Thumbnail storage
- [x] Array filtering operations
- [x] Array sorting operations

#### 2. AppState Tests (`AppStateTests.swift`)
- [x] Initial state validation
- [x] About window lifecycle
- [x] Preferences window lifecycle
- [x] Multiple window management
- [x] Window close notifications
- [x] Window sizing
- [x] Window style masks

#### 3. WindowManager Tests (`WindowManagerTests.swift`)
- [x] Activation history recording
- [x] Recency maintenance
- [x] Duplicate removal in history
- [x] History size limiting (50 max)
- [x] Performance benchmarks

### 🔄 To Be Implemented

#### 4. KeyboardMonitor Tests (`KeyboardMonitorTests.swift`)
**Priority: HIGH**

```swift
// Test Coverage Needed:
- [ ] Cmd key state tracking
- [ ] Tab key detection (keycode 48)
- [ ] Shift+Tab detection
- [ ] Escape key handling (keycode 53)
- [ ] Event consumption
- [ ] Thread safety of state changes
- [ ] Callback invocation
- [ ] Event tap creation/destruction
```

**Implementation Notes:**
- Mock `CGEvent` using protocol-based design
- Test state transitions with thread safety
- Verify callback invocation order
- Test edge cases (rapid key presses, simultaneous keys)

**Example Test:**
```swift
func testCmdTabTriggersCallback() {
    // Given: Keyboard monitor with callback
    var callbackInvoked = false
    keyboardMonitor.onCmdTabPressed = { callbackInvoked = true }

    // When: Simulating Cmd+Tab event
    let mockEvent = createMockKeyEvent(keyCode: 48, flags: .maskCommand)
    keyboardMonitor.handleEvent(proxy: mockProxy, type: .keyDown, event: mockEvent)

    // Then: Callback should be invoked
    XCTAssertTrue(callbackInvoked)
}
```

#### 5. SwitcherCoordinator Tests (`SwitcherCoordinatorTests.swift`)
**Priority: HIGH**

```swift
// Test Coverage Needed:
- [ ] Window list refresh on show
- [ ] Selection cycling (next/previous)
- [ ] Window activation on Cmd release
- [ ] Escape key dismissal
- [ ] Empty window list handling
- [ ] Thumbnail placeholder logic
- [ ] Window centering
- [ ] Coordinator cleanup (deinit)
```

**Testing Challenges:**
- Requires mocking `WindowManager`
- Requires mocking `KeyboardMonitor`
- NSWindow testing requires careful setup

**Recommended Approach:**
- Create protocol-based abstractions (`WindowManagerProtocol`)
- Use dependency injection for testability
- Mock window operations

#### 6. Preferences Logic Tests (`PreferencesTests.swift`)
**Priority: MEDIUM**

```swift
// Test Coverage Needed:
- [ ] UserDefaults persistence
- [ ] Launch at login toggle (SMAppService)
- [ ] Preference validation (ranges)
- [ ] Reset to defaults
- [ ] Thumbnail size constraints (150-300)
- [ ] Max windows constraints (5-50)
```

#### 7. Window Activation Tests (`WindowActivationTests.swift`)
**Priority: HIGH**

```swift
// Test Coverage Needed:
- [ ] Bounds-based window matching
- [ ] Title-based fallback matching
- [ ] Accessibility API error handling
- [ ] App activation before window focus
- [ ] Partial activation success scenarios
```

**Critical Code Path:** `WindowInfo.swift:215-310`
- This 95-line method needs comprehensive testing
- Consider refactoring into smaller, testable methods

---

## Integration Tests

### 1. End-to-End Window Switching Flow
**Priority: HIGH**

```swift
// Test Scenario:
- Launch app
- Open multiple test windows
- Press Cmd+Tab
- Verify switcher appears
- Navigate with Tab
- Release Cmd
- Verify correct window activated
```

**Implementation:**
```swift
func testCompleteWindowSwitchingFlow() async {
    // 1. Setup: Create 3 test windows
    // 2. Show switcher
    // 3. Simulate Tab key (select next)
    // 4. Simulate Cmd release
    // 5. Verify window 2 is now active
}
```

### 2. Permission Handling Integration
**Priority: MEDIUM**

```swift
// Test Scenarios:
- [ ] No Accessibility permission → show alert
- [ ] No Screen Recording → fallback to icons
- [ ] Permissions granted mid-session
```

### 3. Multi-Screen Support
**Priority: MEDIUM**

```swift
// Test Scenarios:
- [ ] Windows across multiple displays
- [ ] Switcher centering on main screen
- [ ] Window activation on secondary screen
```

### 4. Thumbnail Cache Integration
**Priority: MEDIUM**

```swift
// Test Scenarios:
- [ ] Cache warmup on app launch
- [ ] Cache refresh every 0.5 seconds
- [ ] Placeholder icons when cache empty
- [ ] Fresh capture when switcher shown
- [ ] Memory management with 50+ windows
```

---

## Manual Testing

### Checklist for Each Release

#### Core Functionality
- [ ] Cmd+Tab shows switcher with all windows
- [ ] Tab cycles forward through windows
- [ ] Shift+Tab cycles backward
- [ ] Escape dismisses switcher
- [ ] Releasing Cmd activates selected window
- [ ] Selected window is centered in view

#### Window Filtering
- [ ] Only shows normal windows (layer 0)
- [ ] Excludes tiny windows (<100x100)
- [ ] Excludes desktop elements
- [ ] Shows windows from all apps

#### UI/UX
- [ ] Thumbnails are up-to-date
- [ ] App icons visible in corner
- [ ] Window titles display correctly
- [ ] Selected window has blue border
- [ ] Smooth scrolling animation (0.2s)
- [ ] Switcher is centered on screen

#### Preferences
- [ ] Launch at login toggle works
- [ ] Show window titles toggle works
- [ ] Thumbnail size slider updates UI
- [ ] Max windows slider limits display
- [ ] Use app icons toggle works
- [ ] Reset to defaults works
- [ ] Preferences persist across restarts

#### Permissions
- [ ] Accessibility permission prompt on first launch
- [ ] Screen Recording permission handled gracefully
- [ ] "Open System Settings" button works
- [ ] App works without Screen Recording (uses icons)

#### Edge Cases
- [ ] Works with 50+ windows
- [ ] Works with 0 windows (no crash)
- [ ] Works with fullscreen apps
- [ ] Works with hidden apps
- [ ] Works during screen recording
- [ ] Works with external displays

#### Performance
- [ ] No lag when showing switcher
- [ ] No lag when cycling windows
- [ ] Thumbnail capture doesn't block UI
- [ ] Memory usage stays reasonable (<100MB)
- [ ] CPU usage low when idle

---

## Performance Tests

### Benchmarks to Implement

#### 1. Thumbnail Capture Performance
```swift
func testThumbnailCapturePerformance() {
    measure {
        // Capture 20 window thumbnails
        for window in testWindows {
            _ = windowManager.captureWindowThumbnail(window)
        }
    }
    // Target: <500ms for 20 windows
}
```

#### 2. Window List Refresh Performance
```swift
func testWindowListRefreshPerformance() {
    measure {
        windowManager.refreshWindows()
    }
    // Target: <100ms for typical window count
}
```

#### 3. Switcher Display Performance
```swift
func testSwitcherDisplayPerformance() {
    measure {
        coordinator.showSwitcher()
    }
    // Target: <200ms from keypress to visible UI
}
```

#### 4. Memory Usage with Many Windows
```swift
func testMemoryUsageWith50Windows() {
    // Create 50 test windows
    // Measure memory footprint
    // Target: <100MB total
}
```

### Performance Requirements
| Operation | Target | Max Acceptable |
|-----------|--------|----------------|
| Show switcher | <200ms | 500ms |
| Cycle selection | <50ms | 100ms |
| Activate window | <300ms | 500ms |
| Thumbnail capture (20) | <500ms | 1000ms |
| Memory (50 windows) | <80MB | 150MB |

---

## Edge Cases & Error Handling

### Critical Edge Cases to Test

#### 1. Empty Window List
```swift
- No windows open → don't show switcher
- All windows filtered out → don't show switcher
- Windows disappear while switcher shown → handle gracefully
```

#### 2. Rapid Key Presses
```swift
- Cmd+Tab pressed repeatedly → smooth cycling
- Shift+Tab alternating → bidirectional cycling works
- Cmd held for long time → no timeout issues
```

#### 3. Permission Denied Scenarios
```swift
- Accessibility denied → log error, inform user
- Screen Recording denied → fallback to app icons
- Permissions revoked mid-session → detect and adapt
```

#### 4. Window Activation Failures
```swift
- Window closed before activation → skip gracefully
- Window moved to different space → still activates
- Window minimized → restore and activate
- Fullscreen window → switch space correctly
```

#### 5. Thread Safety
```swift
- Thumbnail cache updated during display → no crashes
- Keyboard events during window refresh → thread-safe
- Multiple callback invocations → proper locking
```

#### 6. Resource Cleanup
```swift
- App quit → timers invalidated
- Coordinator deallocated → keyboard monitor stopped
- Windows closed → notification observers removed
```

---

## CI/CD Integration

### Recommended GitHub Actions Workflow

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-13

    steps:
      - uses: actions/checkout@v3

      - name: Build
        run: swift build -c release

      - name: Run Tests
        run: swift test --enable-code-coverage

      - name: Generate Coverage Report
        run: |
          xcrun llvm-cov export \
            .build/debug/WindowSwitcherPackageTests.xctest/Contents/MacOS/WindowSwitcherPackageTests \
            -instr-profile .build/debug/codecov/default.profdata \
            -format=lcov > coverage.lcov

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.lcov

      - name: SwiftLint
        run: |
          brew install swiftlint
          swiftlint --strict
```

### Coverage Requirements
- **Minimum**: 60% overall coverage
- **Critical paths**: 85%+ coverage
- **PR requirement**: No decrease in coverage

---

## Testing Roadmap

### Phase 1: Foundation (Week 1)
- [x] Set up test infrastructure
- [x] WindowInfo tests
- [x] AppState tests
- [x] WindowManager activation history tests
- [ ] KeyboardMonitor tests
- [ ] Document testing patterns

### Phase 2: Core Logic (Week 2)
- [ ] SwitcherCoordinator tests
- [ ] Window activation tests
- [ ] Refactor activateWindow for testability
- [ ] Integration tests for switching flow
- [ ] Performance benchmarks

### Phase 3: Completeness (Week 3)
- [ ] Preferences tests
- [ ] UI component tests
- [ ] Edge case coverage
- [ ] Manual test execution
- [ ] CI/CD pipeline setup

### Phase 4: Optimization (Week 4)
- [ ] Achieve 70%+ coverage
- [ ] Performance optimization based on tests
- [ ] Documentation updates
- [ ] Test maintenance guide

---

## Known Testing Challenges

### 1. System API Dependencies
**Challenge:** Code heavily relies on CoreGraphics, Accessibility APIs
**Solution:**
- Create protocol-based abstractions
- Use dependency injection
- Mock system APIs in tests

### 2. NSWindow Testing
**Challenge:** NSWindow requires application context
**Solution:**
- Use `NSApplication.shared` in test setup
- Test window properties, not rendering
- Focus on business logic over UI

### 3. Keyboard Event Simulation
**Challenge:** CGEvent tap cannot be easily mocked
**Solution:**
- Extract event handling logic to testable methods
- Use protocol for event source
- Test state transitions separately from event capture

### 4. Asynchronous Operations
**Challenge:** Thumbnail capture, cache refresh are async
**Solution:**
- Use XCTestExpectation for async tests
- Mock DispatchQueue in tests
- Test completion handlers

---

## Testing Best Practices

### Code Organization
```swift
// Arrange-Act-Assert pattern
func testExample() {
    // Given: Setup test conditions
    let input = createTestInput()

    // When: Execute the operation
    let result = performOperation(input)

    // Then: Verify expectations
    XCTAssertEqual(result, expected)
}
```

### Naming Convention
```swift
func test{WhatIsBeingTested}{ExpectedBehavior}()

Examples:
- testRecordWindowActivation_AddsToHistory
- testShowSwitcher_WithNoWindows_DoesNotShow
- testCmdTabPressed_InvokesCallback
```

### Test Independence
- Each test should be independent
- Use setUp/tearDown for clean state
- Don't rely on test execution order
- Clean up UserDefaults, timers, observers

### Assertion Quality
```swift
// ❌ Bad: Vague assertion
XCTAssertTrue(result)

// ✅ Good: Descriptive assertion
XCTAssertTrue(window.isVisible,
  "Window should be visible after opening")
```

---

## Appendix: Mock Implementation Examples

### Mock WindowManager
```swift
protocol WindowManagerProtocol {
    var windows: [WindowInfo] { get }
    func refreshWindows()
    func activateWindow(_ window: WindowInfo)
    func recordWindowActivation(_ windowID: CGWindowID)
}

class MockWindowManager: WindowManagerProtocol {
    var windows: [WindowInfo] = []
    var activateWindowCalled = false
    var recordActivationCalled = false

    func refreshWindows() {
        windows = createMockWindows()
    }

    func activateWindow(_ window: WindowInfo) {
        activateWindowCalled = true
    }

    func recordWindowActivation(_ windowID: CGWindowID) {
        recordActivationCalled = true
    }
}
```

### Mock KeyboardMonitor
```swift
class MockKeyboardMonitor: KeyboardMonitorProtocol {
    var isShowingSwitcher = false
    var onCmdTabPressed: (() -> Void)?
    var onTabPressed: (() -> Void)?
    var onCmdReleased: (() -> Void)?

    func simulateCmdTab() {
        onCmdTabPressed?()
    }

    func simulateTab() {
        onTabPressed?()
    }

    func simulateCmdRelease() {
        onCmdReleased?()
    }
}
```

---

## Summary

This test plan provides a comprehensive framework for testing WindowSwitcher. The immediate priorities are:

1. **Complete unit tests** for KeyboardMonitor and SwitcherCoordinator
2. **Refactor** `activateWindow` method for better testability
3. **Implement** integration tests for critical flows
4. **Set up** CI/CD pipeline with coverage reporting
5. **Achieve** 70%+ code coverage goal

Following this plan will significantly improve code quality, reliability, and maintainability of the WindowSwitcher application.
