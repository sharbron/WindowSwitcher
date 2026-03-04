# WindowSwitcher Tests

This directory contains unit and integration tests for the WindowSwitcher application.

## Running Tests

### Command Line

```bash
# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run specific test file
swift test --filter WindowInfoTests

# Run specific test method
swift test --filter WindowInfoTests.testWindowInfoEquality

# Parallel execution
swift test --parallel
```

### Xcode

1. Open Package.swift in Xcode
2. Select the test target
3. Press ⌘U to run all tests
4. Or click the diamond icon next to individual tests

## Test Structure

```
Tests/WindowSwitcherTests/
├── README.md                    # This file
├── WindowInfoTests.swift        # WindowInfo model tests
├── AppStateTests.swift          # AppState class tests
├── WindowManagerTests.swift     # WindowManager tests
└── [Future test files]
```

## Test Coverage

### Current Coverage

| Component | Coverage | Status |
|-----------|----------|--------|
| WindowInfo (model) | 95% | ✅ Complete |
| AppState | 85% | ✅ Complete |
| WindowManager (activation history) | 40% | 🟡 Partial |
| KeyboardMonitor | 0% | ❌ Not started |
| SwitcherCoordinator | 0% | ❌ Not started |
| Views | 0% | ❌ Not started |
| **Total** | **~30%** | 🟡 **In Progress** |

### Target Coverage

- Overall: **70%+**
- Critical paths: **85%+**

## Writing Tests

### Test Naming Convention

```swift
func test{Component}{Behavior}()

Examples:
✅ testWindowInfoEquality
✅ testOpenAboutWindow
✅ testRecordWindowActivationAddsToHistory
✅ testWindowSortingByRecency
```

### Test Structure (Arrange-Act-Assert)

```swift
func testExample() {
    // Given: Setup test conditions
    let window = WindowInfo(
        id: 123,
        ownerPID: 456,
        title: "Test",
        appName: "App",
        bounds: .zero,
        layer: 0,
        isOnScreen: true,
        thumbnail: nil
    )

    // When: Execute the operation
    let result = window.id

    // Then: Verify expectations
    XCTAssertEqual(result, 123, "Window ID should match")
}
```

### Async Tests

```swift
func testAsyncOperation() async {
    // Given
    let appState = AppState()

    // When
    appState.openAboutWindow()

    // Wait for async operation
    try? await Task.sleep(nanoseconds: 100_000_000)

    // Then
    XCTAssertTrue(appState.isAboutWindowOpen)
}
```

### Testing with @MainActor

```swift
@MainActor
final class MyTests: XCTestCase {
    var appState: AppState!

    override func setUp() async throws {
        await MainActor.run {
            appState = AppState()
        }
    }

    func testMainActorOperation() {
        // Test runs on main actor
        appState.openAboutWindow()
        XCTAssertTrue(appState.isAboutWindowOpen)
    }
}
```

## Implemented Tests

### 1. WindowInfoTests.swift

Tests for the `WindowInfo` model and basic operations.

**Coverage:**
- ✅ Equality based on ID
- ✅ Inequality with different IDs
- ✅ Identifiable conformance
- ✅ Thumbnail storage
- ✅ Array filtering
- ✅ Array sorting

**Run:**
```bash
swift test --filter WindowInfoTests
```

### 2. AppStateTests.swift

Tests for the `AppState` class managing global app state.

**Coverage:**
- ✅ Initial state
- ✅ About window lifecycle
- ✅ Preferences window lifecycle
- ✅ Multiple window management
- ✅ Window close notifications
- ✅ Window sizing and styling

**Run:**
```bash
swift test --filter AppStateTests
```

### 3. WindowManagerTests.swift

Tests for `WindowManager` activation history and caching logic.

**Coverage:**
- ✅ Activation history recording
- ✅ Recency maintenance
- ✅ Duplicate removal
- ✅ History size limiting (50 max)
- ✅ Performance benchmarks

**Run:**
```bash
swift test --filter WindowManagerTests
```

## Planned Tests (To Be Implemented)

### 4. KeyboardMonitorTests.swift (Priority: HIGH)

```swift
// Test Coverage Needed:
- [ ] Cmd key state tracking
- [ ] Tab key detection (keycode 48)
- [ ] Shift+Tab detection
- [ ] Escape key handling
- [ ] Event consumption
- [ ] Thread safety
- [ ] Callback invocation
```

### 5. SwitcherCoordinatorTests.swift (Priority: HIGH)

```swift
// Test Coverage Needed:
- [ ] Window list refresh
- [ ] Selection cycling
- [ ] Window activation on Cmd release
- [ ] Escape key dismissal
- [ ] Empty window list handling
- [ ] Thumbnail placeholders
```

### 6. PreferencesTests.swift (Priority: MEDIUM)

```swift
// Test Coverage Needed:
- [ ] UserDefaults persistence
- [ ] Launch at login toggle
- [ ] Preference validation
- [ ] Reset to defaults
```

## Test Helpers

### Creating Test Windows

```swift
func createTestWindow(
    id: CGWindowID = 123,
    pid: pid_t = 1000,
    title: String = "Test",
    appName: String = "TestApp",
    bounds: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600)
) -> WindowInfo {
    return WindowInfo(
        id: id,
        ownerPID: pid,
        title: title,
        appName: appName,
        bounds: bounds,
        layer: 0,
        isOnScreen: true,
        thumbnail: nil
    )
}

// Usage:
let window = createTestWindow(id: 456, title: "My Window")
```

### Using Test UserDefaults

```swift
class MyTests: XCTestCase {
    let testDefaults = UserDefaults(suiteName: "com.windowswitcher.tests")!

    override func setUp() {
        testDefaults.removePersistentDomain(forName: "com.windowswitcher.tests")
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: "com.windowswitcher.tests")
    }
}
```

## Continuous Integration

### GitHub Actions (Recommended)

Create `.github/workflows/tests.yml`:

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
```

## Debugging Tests

### Verbose Output

```bash
# Show test names as they run
swift test --verbose

# Show all log output
swift test --enable-test-discovery
```

### Debugging in Xcode

1. Set breakpoint in test
2. Click "Debug Test" (not "Run Test")
3. Use debugger as normal

### Debugging Failed Tests

```swift
// Add print statements
func testExample() {
    let result = doSomething()
    print("DEBUG: result = \(result)")  // Temporary debug
    XCTAssertEqual(result, expected)
}

// Or use XCTContext
func testWithContext() {
    XCTContext.runActivity(named: "Verify window creation") { _ in
        let window = createWindow()
        XCTAssertNotNil(window)
    }
}
```

## Performance Testing

### Measuring Performance

```swift
func testPerformance() {
    measure {
        // Code to measure
        for _ in 0..<100 {
            windowManager.recordWindowActivation(CGWindowID(Int.random(in: 0...1000)))
        }
    }

    // Results printed to console:
    // Average: 0.023 sec
    // Relative standard deviation: 12.5%
}
```

### Performance Baselines

First run establishes baseline. Subsequent runs compare against it.

```bash
# Update performance baselines
swift test --filter testPerformance --enable-baseline-update
```

## Common Issues

### Issue: Tests fail with "No such module 'WindowSwitcher'"

**Solution:**
```bash
# Clean build
swift package clean
swift build
swift test
```

### Issue: AppState tests fail with window not created

**Solution:**
Ensure tests are run with `@MainActor`:

```swift
@MainActor
final class AppStateTests: XCTestCase {
    // ...
}
```

### Issue: UserDefaults persisting between tests

**Solution:**
Use test-specific suite and clean in setUp/tearDown:

```swift
let testDefaults = UserDefaults(suiteName: "com.windowswitcher.tests")!

override func setUp() {
    testDefaults.removePersistentDomain(forName: "com.windowswitcher.tests")
}
```

### Issue: Tests hang on CI

**Solution:**
Ensure no infinite loops or missing timeouts:

```swift
// Bad
while !condition {  // Could hang forever
    // ...
}

// Good
let timeout = Date().addingTimeInterval(5)
while !condition && Date() < timeout {
    // ...
}
```

## Best Practices

### ✅ Do

- Write tests before fixing bugs (TDD)
- Keep tests fast (<1s per test)
- Test one thing per test
- Use descriptive test names
- Clean up in `tearDown()`
- Use assertions with messages

```swift
XCTAssertEqual(window.id, 123, "Window ID should match the provided value")
```

### ❌ Don't

- Don't test implementation details
- Don't have tests depend on each other
- Don't use sleep() except for async operations
- Don't skip cleanup in tearDown
- Don't test third-party code

## Resources

- [Swift Testing Documentation](https://developer.apple.com/documentation/xctest)
- [Testing Best Practices](https://developer.apple.com/documentation/xctest/user_interface_tests)
- [Code Coverage](https://developer.apple.com/documentation/xcode/code-coverage)
- [WindowSwitcher TEST_PLAN.md](../../TEST_PLAN.md) - Comprehensive test plan

## Contributing

When adding new tests:

1. Follow the naming convention
2. Add test to appropriate file (or create new file)
3. Update this README with coverage info
4. Ensure `swift test` passes
5. Check coverage doesn't decrease

## Questions?

Refer to:
- [TEST_PLAN.md](../../TEST_PLAN.md) - Detailed testing strategy
- [CODE_REVIEW.md](../../CODE_REVIEW.md) - Code quality findings
- [CLAUDE.md](../../CLAUDE.md) - Project architecture

---

**Last Updated:** 2025-11-07
**Total Tests:** 30+
**Test Coverage:** ~30% (target: 70%+)
