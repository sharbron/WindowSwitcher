import XCTest
@testable import WindowSwitcher

/// Unit tests for WindowManager activation history
final class WindowManagerTests: XCTestCase {

    var windowManager: WindowManager!
    let testDefaults = UserDefaults(suiteName: "com.windowswitcher.tests")!

    override func setUp() {
        super.setUp()
        // Use test-specific UserDefaults
        testDefaults.removePersistentDomain(forName: "com.windowswitcher.tests")
        windowManager = WindowManager(userDefaults: testDefaults)
    }

    override func tearDown() {
        windowManager = nil
        testDefaults.removePersistentDomain(forName: "com.windowswitcher.tests")
        super.tearDown()
    }

    // MARK: - Activation History Tests

    func testRecordWindowActivationAddsToHistory() {
        // Given: A window ID
        let windowID: CGWindowID = 12345

        // When: Recording an activation
        windowManager.recordWindowActivation(windowID)

        // Then: Wait for async UserDefaults save to complete
        let expectation = XCTestExpectation(description: "UserDefaults save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let saved = self.testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
            XCTAssertNotNil(saved, "Activation order should be saved")
            XCTAssertEqual(saved?.first, UInt32(windowID), "Most recent activation should be first")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
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

        // Then: Wait for async UserDefaults save and verify order
        let expectation = XCTestExpectation(description: "UserDefaults save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let saved = self.testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
            XCTAssertEqual(saved?.count, 3)
            XCTAssertEqual(saved?[0], UInt32(window3), "Most recent window should be first")
            XCTAssertEqual(saved?[1], UInt32(window2), "Second most recent should be second")
            XCTAssertEqual(saved?[2], UInt32(window1), "Oldest should be last")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRecordWindowActivationRemovesDuplicates() {
        // Given: Initial activations
        let window1: CGWindowID = 100
        let window2: CGWindowID = 200

        windowManager.recordWindowActivation(window1)
        windowManager.recordWindowActivation(window2)

        // When: Re-activating window1
        windowManager.recordWindowActivation(window1)

        // Then: Wait for async save and verify no duplicates
        let expectation = XCTestExpectation(description: "UserDefaults save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let saved = self.testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
            XCTAssertEqual(saved?.count, 2, "Should not have duplicates")
            XCTAssertEqual(saved?[0], UInt32(window1), "Re-activated window should be first")
            XCTAssertEqual(saved?[1], UInt32(window2), "Previous window should be second")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
    }

    func testRecordWindowActivationLimitsHistorySize() {
        // Given: More than maxActivationHistorySize windows
        let maxSize = 50
        let windowIDs = (1...60).map { CGWindowID($0) }

        // When: Recording all activations
        for windowID in windowIDs {
            windowManager.recordWindowActivation(windowID)
        }

        // Then: Wait for async save and verify history limit
        let expectation = XCTestExpectation(description: "UserDefaults save")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let saved = self.testDefaults.array(forKey: "windowActivationOrder") as? [UInt32]
            XCTAssertEqual(saved?.count, maxSize, "History should be limited to \(maxSize) entries")

            // Most recent 50 windows should be preserved
            for index in 0..<maxSize {
                let expectedWindowID = 60 - index // Most recent first
                XCTAssertEqual(saved?[index], UInt32(expectedWindowID))
            }
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
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
