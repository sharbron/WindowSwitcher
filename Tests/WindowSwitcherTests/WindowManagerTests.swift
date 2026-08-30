import XCTest
@testable import WindowSwitcher

/// Unit tests for WindowManager activation history
final class WindowManagerTests: XCTestCase {

    var windowManager: WindowManager!
    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        // Create unique suite name for this test instance to prevent parallel test pollution
        suiteName = "com.windowswitcher.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        // Use test-specific UserDefaults
        testDefaults.removePersistentDomain(forName: suiteName)
        windowManager = WindowManager(userDefaults: testDefaults)
    }

    override func tearDown() {
        windowManager = nil
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Activation History Tests

    func testRecordWindowActivationAddsToHistory() {
        // Given: A window ID
        let windowID: CGWindowID = 12345

        // When: Recording an activation
        windowManager.recordWindowActivation(windowID)
        windowManager.flushActivationHistory() // Synchronously save for testing

        // Then: Verify saved to UserDefaults
        let saved = testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
        XCTAssertNotNil(saved, "Activation order should be saved")
        XCTAssertEqual(saved?.first, UInt32(windowID), "Most recent activation should be first")
    }

    func testRecordWindowActivationMaintainsRecency() {
        // Given: Multiple window activations
        let window1: CGWindowID = 100
        let window2: CGWindowID = 200
        let window3: CGWindowID = 300

        // When: Recording activations in sequence
        windowManager.recordWindowActivation(window1)
        windowManager.recordWindowActivation(window2)
        windowManager.recordWindowActivation(window3)
        windowManager.flushActivationHistory() // Synchronously save for testing

        // Then: Verify order
        let saved = testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
        XCTAssertEqual(saved?.count, 3)
        XCTAssertEqual(saved?[0], UInt32(window3), "Most recent window should be first")
        XCTAssertEqual(saved?[1], UInt32(window2), "Second most recent should be second")
        XCTAssertEqual(saved?[2], UInt32(window1), "Oldest should be last")
    }

    func testRecordWindowActivationRemovesDuplicates() {
        // Given: Initial activations
        let window1: CGWindowID = 100
        let window2: CGWindowID = 200

        windowManager.recordWindowActivation(window1)
        windowManager.recordWindowActivation(window2)

        // When: Re-activating window1
        windowManager.recordWindowActivation(window1)
        windowManager.flushActivationHistory() // Synchronously save for testing

        // Then: Verify no duplicates
        let saved = testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
        XCTAssertEqual(saved?.count, 2, "Should not have duplicates")
        XCTAssertEqual(saved?[0], UInt32(window1), "Re-activated window should be first")
        XCTAssertEqual(saved?[1], UInt32(window2), "Previous window should be second")
    }

    func testRecordWindowActivationLimitsHistorySize() {
        // Given: More than maxActivationHistorySize windows
        let maxSize = 50
        let windowIDs = (1...60).map { CGWindowID($0) }

        // When: Recording all activations
        for windowID in windowIDs {
            windowManager.recordWindowActivation(windowID)
        }
        windowManager.flushActivationHistory() // Synchronously save for testing

        // Then: Verify history limit
        let saved = testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
        XCTAssertEqual(saved?.count, maxSize, "History should be limited to \(maxSize) entries")

        // Most recent 50 windows should be preserved
        for index in 0..<maxSize {
            let expectedWindowID = 60 - index // Most recent first
            XCTAssertEqual(saved?[index], UInt32(expectedWindowID))
        }
    }

    // MARK: - Window Sorting Tests

    func testWindowSortingByRecency() {
        // This test would require mocking CGWindowListCopyWindowInfo
        // For now, we'll test the sorting logic conceptually
        // In a real implementation, you'd need to create a testable wrapper
        // around the window enumeration logic

        // Test outline:
        // 1. Create mock windows
        // 2. Set up activation history
        // 3. Call refreshWindows
        // 4. Verify sort order matches recency
    }

    // MARK: - Thumbnail Caching Tests

    func testThumbnailCacheUpdates() {
        // This test would require mocking window capture
        // Testing strategy:
        // 1. Mock CGWindowListCopyWindowInfo
        // 2. Verify cache refresh is called
        // 3. Verify thumbnails are stored correctly

        // Note: This requires dependency injection or protocol-based design
        // for proper unit testing
    }

    // MARK: - Window Filtering Tests

    func testWindowFilteringBySize() {
        // Test outline:
        // Given: Windows of various sizes
        // When: Refreshing windows
        // Then: Only windows >= 100x100 should be included

        // This would require mocking window list
    }

    func testWindowFilteringByLayer() {
        // Test outline:
        // Given: Windows with different layer values
        // When: Refreshing windows
        // Then: Only layer == 0 windows should be included
    }
}

// MARK: - Helper Extensions for Testing

extension WindowManagerTests {

    /// Helper to create test windows
    func createTestWindow(
        id: CGWindowID,
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
}

// MARK: - Performance Tests

extension WindowManagerTests {

    func testActivationHistoryPerformance() {
        // Measure performance of recording 100 activations
        measure {
            for index in 0..<100 {
                windowManager.recordWindowActivation(CGWindowID(index))
            }
        }
    }

    func testActivationHistoryLookupPerformance() {
        // Given: A full activation history
        for index in 0..<50 {
            windowManager.recordWindowActivation(CGWindowID(index))
        }

        // Measure performance of sorting windows by recency
        let testWindows = (0..<50).map { createTestWindow(id: CGWindowID($0)) }

        measure {
            // Simulate the sorting logic from refreshWindows
            let _ = testWindows.sorted { lhs, rhs in
                let saved = self.testDefaults.array(forKey: "windowActivationOrder") as? [UInt32] ?? []
                let activationOrder = saved.map { CGWindowID($0) }

                let lhsIndex = activationOrder.firstIndex(of: lhs.id) ?? Int.max
                let rhsIndex = activationOrder.firstIndex(of: rhs.id) ?? Int.max
                return lhsIndex < rhsIndex
            }
        }
    }
}

// MARK: - Thumbnail Downsampling Tests

/// Window captures arrive at native Retina resolution — roughly 20MB per window — while the
/// switcher never draws one wider than 300pt. These cover the scaling that keeps a screenful
/// of previews from costing hundreds of megabytes.
final class ThumbnailCacheTests: XCTestCase {

    private var cache: ThumbnailCache!

    override func setUp() {
        super.setUp()
        cache = ThumbnailCache(userDefaults: UserDefaults(suiteName: "ThumbnailCacheTests")!)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: "ThumbnailCacheTests")
        cache = nil
        super.tearDown()
    }

    private func makeImage(width: Int, height: Int) -> CGImage {
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        )!
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    func testOversizedCaptureIsScaledDown() {
        // A 1440x900pt window on a 2x display.
        let source = makeImage(width: 2880, height: 1800)
        let result = cache.downsampled(source, maxPixelWidth: 640)

        XCTAssertEqual(result.size.width, 640, "Should scale to the requested width")
        XCTAssertEqual(result.size.height, 400, "Should preserve the aspect ratio")
    }

    func testSmallCaptureIsLeftAlone() {
        let source = makeImage(width: 320, height: 240)
        let result = cache.downsampled(source, maxPixelWidth: 640)

        XCTAssertEqual(result.size.width, 320, "Images already under the limit should not be upscaled")
        XCTAssertEqual(result.size.height, 240)
    }

    func testCaptureAtExactlyTheLimitIsLeftAlone() {
        let source = makeImage(width: 640, height: 480)
        let result = cache.downsampled(source, maxPixelWidth: 640)

        XCTAssertEqual(result.size.width, 640)
        XCTAssertEqual(result.size.height, 480)
    }

    func testExtremeAspectRatioKeepsAtLeastOnePixelOfHeight() {
        let source = makeImage(width: 4000, height: 2)
        let result = cache.downsampled(source, maxPixelWidth: 640)

        XCTAssertEqual(result.size.width, 640)
        XCTAssertGreaterThanOrEqual(result.size.height, 1, "Height must never round down to zero")
    }

    func testAppIconPreferencyReturnsIconInsteadOfCapture() {
        let defaults = UserDefaults(suiteName: "ThumbnailCacheTests.icons")!
        defaults.removePersistentDomain(forName: "ThumbnailCacheTests.icons")
        defaults.set(true, forKey: "useAppIcons")
        defer { defaults.removePersistentDomain(forName: "ThumbnailCacheTests.icons") }

        let iconCache = ThumbnailCache(userDefaults: defaults)
        let icon = NSImage(systemSymbolName: "star", accessibilityDescription: nil)
        let window = WindowInfo(
            id: 1,
            ownerPID: 1000,
            title: "Test",
            appName: "TestApp",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            isOnScreen: true,
            thumbnail: nil,
            appIcon: icon
        )

        XCTAssertIdentical(iconCache.capture(window), icon, "Should return the cached app icon, not a capture")
    }

    func testAppIconFallsBackToSymbolForUnknownProcess() {
        let window = WindowInfo(
            id: 1,
            ownerPID: -1,
            title: "Gone",
            appName: "Gone",
            bounds: .zero,
            layer: 0,
            isOnScreen: false,
            thumbnail: nil
        )

        XCTAssertNotNil(ThumbnailCache.appIcon(for: window), "A placeholder icon should always be available")
    }
}

// MARK: - Accessibility Window Discovery

/// Finder returns an empty `kAXWindows` array even when it has windows open, so its windows
/// have to be recovered from `AXChildren`. Without that, no Finder window can be matched and
/// activation degrades to raising the app — which fronts whichever window Finder last used,
/// not the one the user picked.
///
/// This is an integration test against the live system: it needs Accessibility permission and
/// an open Finder window, and skips when either is missing.
final class AccessibilityWindowDiscoveryTests: XCTestCase {

    private var manager: WindowManager!

    override func setUp() {
        super.setUp()
        manager = WindowManager(userDefaults: UserDefaults(suiteName: "AXDiscoveryTests")!)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: "AXDiscoveryTests")
        manager = nil
        super.tearDown()
    }

    /// Number of normal, switcher-eligible windows CoreGraphics reports for a bundle id.
    private func onScreenWindowCount(forBundleID bundleID: String) -> Int {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else {
            return 0
        }
        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return 0
        }
        return list.filter { info in
            (info[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier
                && (info[kCGWindowLayer as String] as? Int) == 0
        }.count
    }

    func testFinderWindowsAreDiscoverableDespiteEmptyAXWindowsArray() throws {
        try XCTSkipUnless(AXIsProcessTrusted(), "Needs Accessibility permission")

        guard let finder = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            throw XCTSkip("Finder is not running")
        }

        let visibleWindows = onScreenWindowCount(forBundleID: "com.apple.finder")
        try XCTSkipIf(visibleWindows == 0, "No Finder windows open")

        let discovered = manager.getAccessibilityWindows(for: finder)

        XCTAssertNotNil(discovered, "Finder's windows must be discoverable")
        XCTAssertGreaterThanOrEqual(
            discovered?.count ?? 0,
            1,
            "Finder reports an empty kAXWindows array; windows must be recovered from AXChildren"
        )
    }

    func testDiscoveredElementsAreWindows() throws {
        try XCTSkipUnless(AXIsProcessTrusted(), "Needs Accessibility permission")

        guard let finder = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            throw XCTSkip("Finder is not running")
        }
        try XCTSkipIf(onScreenWindowCount(forBundleID: "com.apple.finder") == 0, "No Finder windows open")
        guard let discovered = manager.getAccessibilityWindows(for: finder) else {
            throw XCTSkip("No accessibility windows returned")
        }

        // The menu bar and the desktop's scroll area are siblings of the windows in AXChildren
        // and must not leak through the filter.
        for element in discovered {
            var roleValue: AnyObject?
            let status = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
            XCTAssertEqual(status, .success)
            XCTAssertEqual(roleValue as? String, kAXWindowRole, "Only AXWindow elements should be returned")
        }
    }
}
