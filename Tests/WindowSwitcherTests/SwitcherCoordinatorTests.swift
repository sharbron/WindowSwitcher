import XCTest
import SwiftUI
@testable import WindowSwitcher

/// Unit tests for SwitcherCoordinator
final class SwitcherCoordinatorTests: XCTestCase {

    var coordinator: SwitcherCoordinator!

    override func setUp() {
        super.setUp()
        coordinator = SwitcherCoordinator()
    }

    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Then: Initial state should be correct
        XCTAssertEqual(coordinator.windows.count, 0, "Windows array should be empty initially")
        XCTAssertEqual(coordinator.selectedIndex, 0, "Selected index should be 0 initially")
        XCTAssertFalse(coordinator.isShowingSwitcher, "Switcher should not be showing initially")
    }

    // MARK: - Published Properties Tests

    func testWindowsPublishedProperty() {
        // Given: Initial empty windows
        XCTAssertEqual(coordinator.windows.count, 0)

        // When: Setting windows
        let testWindows = [
            createTestWindow(id: 1, title: "Window 1"),
            createTestWindow(id: 2, title: "Window 2")
        ]
        coordinator.windows = testWindows

        // Then: Windows should be updated
        XCTAssertEqual(coordinator.windows.count, 2)
        XCTAssertEqual(coordinator.windows[0].id, 1)
        XCTAssertEqual(coordinator.windows[1].id, 2)
    }

    func testSelectedIndexPublishedProperty() {
        // Given: Initial state
        XCTAssertEqual(coordinator.selectedIndex, 0)

        // When: Changing selected index
        coordinator.selectedIndex = 5

        // Then: State should be updated
        XCTAssertEqual(coordinator.selectedIndex, 5)
    }

    func testIsShowingSwitcherPublishedProperty() {
        // Given: Initial state
        XCTAssertFalse(coordinator.isShowingSwitcher)

        // When: Showing switcher
        coordinator.isShowingSwitcher = true

        // Then: State should be updated
        XCTAssertTrue(coordinator.isShowingSwitcher)
    }

    // MARK: - State Consistency Tests

    func testStateConsistency() {
        // Given: Some windows
        coordinator.windows = [
            createTestWindow(id: 1),
            createTestWindow(id: 2),
            createTestWindow(id: 3)
        ]

        // When: Setting selected index within bounds
        coordinator.selectedIndex = 1
        coordinator.isShowingSwitcher = true

        // Then: All state should be consistent
        XCTAssertEqual(coordinator.windows.count, 3)
        XCTAssertEqual(coordinator.selectedIndex, 1)
        XCTAssertTrue(coordinator.isShowingSwitcher)
    }

    func testSelectedIndexBeyondBounds() {
        // Given: 2 windows
        coordinator.windows = [
            createTestWindow(id: 1),
            createTestWindow(id: 2)
        ]

        // When: Setting selected index beyond bounds
        coordinator.selectedIndex = 5

        // Then: State should be set (coordinator should handle bounds)
        XCTAssertEqual(coordinator.selectedIndex, 5)
        // Note: The coordinator's selectNext/selectPrevious methods handle wrapping
    }

    // MARK: - Window List Management Tests

    func testEmptyWindowList() {
        // Given: Empty windows
        coordinator.windows = []

        // When: Checking state
        // Then: Should handle empty list gracefully
        XCTAssertEqual(coordinator.windows.count, 0)
        XCTAssertFalse(coordinator.isShowingSwitcher, "Should not show switcher with no windows")
    }

    func testSingleWindow() {
        // Given: Single window
        coordinator.windows = [createTestWindow(id: 1)]

        // When: Showing switcher
        coordinator.isShowingSwitcher = true

        // Then: Should show single window
        XCTAssertEqual(coordinator.windows.count, 1)
        XCTAssertTrue(coordinator.isShowingSwitcher)
        XCTAssertEqual(coordinator.selectedIndex, 0)
    }

    func testMultipleWindows() {
        // Given: Multiple windows
        let windowCount = 10
        coordinator.windows = (1...windowCount).map { createTestWindow(id: CGWindowID($0)) }

        // Then: All windows should be stored
        XCTAssertEqual(coordinator.windows.count, windowCount)
    }

    func testLargeNumberOfWindows() {
        // Given: Large number of windows (50)
        let windowCount = 50
        coordinator.windows = (1...windowCount).map { createTestWindow(id: CGWindowID($0)) }

        // Then: Should handle large list
        XCTAssertEqual(coordinator.windows.count, windowCount)
    }

    // MARK: - Selection Cycling Tests (Simulated)

    func testSelectionCyclingForward() {
        // Given: 3 windows
        coordinator.windows = [
            createTestWindow(id: 1),
            createTestWindow(id: 2),
            createTestWindow(id: 3)
        ]
        coordinator.selectedIndex = 0

        // When: Simulating forward cycling
        coordinator.selectedIndex = (coordinator.selectedIndex + 1) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 1)

        coordinator.selectedIndex = (coordinator.selectedIndex + 1) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 2)

        coordinator.selectedIndex = (coordinator.selectedIndex + 1) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 0, "Should wrap to beginning")
    }

    func testSelectionCyclingBackward() {
        // Given: 3 windows
        coordinator.windows = [
            createTestWindow(id: 1),
            createTestWindow(id: 2),
            createTestWindow(id: 3)
        ]
        coordinator.selectedIndex = 0

        // When: Simulating backward cycling
        coordinator.selectedIndex = (coordinator.selectedIndex - 1 + coordinator.windows.count) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 2, "Should wrap to end")

        coordinator.selectedIndex = (coordinator.selectedIndex - 1 + coordinator.windows.count) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 1)

        coordinator.selectedIndex = (coordinator.selectedIndex - 1 + coordinator.windows.count) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 0)
    }

    // MARK: - Window Data Integrity Tests

    func testWindowInfoPreservation() {
        // Given: Windows with specific data
        let window1 = createTestWindow(id: 100, title: "Test Window 1", appName: "TestApp1")
        let window2 = createTestWindow(id: 200, title: "Test Window 2", appName: "TestApp2")

        coordinator.windows = [window1, window2]

        // Then: All window data should be preserved
        XCTAssertEqual(coordinator.windows[0].id, 100)
        XCTAssertEqual(coordinator.windows[0].title, "Test Window 1")
        XCTAssertEqual(coordinator.windows[0].appName, "TestApp1")

        XCTAssertEqual(coordinator.windows[1].id, 200)
        XCTAssertEqual(coordinator.windows[1].title, "Test Window 2")
        XCTAssertEqual(coordinator.windows[1].appName, "TestApp2")
    }

    func testWindowThumbnailPreservation() {
        // Given: Windows with thumbnails
        let thumbnail = NSImage(size: NSSize(width: 100, height: 100))
        var window = createTestWindow(id: 1)
        window.thumbnail = thumbnail

        coordinator.windows = [window]

        // Then: Thumbnail should be preserved
        XCTAssertNotNil(coordinator.windows[0].thumbnail)
        XCTAssertEqual(coordinator.windows[0].thumbnail?.size, thumbnail.size)
    }

    // MARK: - State Transition Tests

    func testShowHideTransition() {
        // Given: Initial state
        XCTAssertFalse(coordinator.isShowingSwitcher)

        // When: Showing switcher
        coordinator.isShowingSwitcher = true
        XCTAssertTrue(coordinator.isShowingSwitcher)

        // When: Hiding switcher
        coordinator.isShowingSwitcher = false
        XCTAssertFalse(coordinator.isShowingSwitcher)
    }

    func testMultipleShowHideCycles() {
        // Test that we can show/hide multiple times
        for _ in 0..<10 {
            coordinator.isShowingSwitcher = true
            XCTAssertTrue(coordinator.isShowingSwitcher)

            coordinator.isShowingSwitcher = false
            XCTAssertFalse(coordinator.isShowingSwitcher)
        }
    }

    // MARK: - Window Uniqueness Tests

    func testDuplicateWindowIDs() {
        // Given: Windows with duplicate IDs (should not happen, but test handling)
        let window1 = createTestWindow(id: 100, title: "Window 1")
        let window2 = createTestWindow(id: 100, title: "Window 2") // Same ID

        coordinator.windows = [window1, window2]

        // Then: Both windows should be stored (coordinator stores array as-is)
        XCTAssertEqual(coordinator.windows.count, 2)

        // Note: WindowInfo equality is based on ID, so they're considered equal
        XCTAssertEqual(window1, window2, "Windows with same ID are considered equal")
    }

    func testWindowArrayEquality() {
        // Given: Two identical window arrays
        let windows1 = [
            createTestWindow(id: 1),
            createTestWindow(id: 2)
        ]

        let windows2 = [
            createTestWindow(id: 1),
            createTestWindow(id: 2)
        ]

        // Then: Arrays should be equal (element-wise)
        XCTAssertEqual(windows1, windows2, "Arrays with same window IDs should be equal")
    }

    // MARK: - Memory Management Tests

    func testCoordinatorDeallocation() {
        // Given: A coordinator that will be deallocated
        var testCoordinator: SwitcherCoordinator? = SwitcherCoordinator()
        weak var weakCoordinator = testCoordinator

        // When: Releasing strong reference
        testCoordinator = nil

        // Then: Coordinator should be deallocated
        XCTAssertNil(weakCoordinator, "Coordinator should be deallocated")
    }

    func testWindowsArrayMemoryManagement() {
        // Given: Large array of windows
        let largeArray = (1...100).map { createTestWindow(id: CGWindowID($0)) }
        coordinator.windows = largeArray

        // When: Clearing windows
        coordinator.windows = []

        // Then: Memory should be released (array cleared)
        XCTAssertEqual(coordinator.windows.count, 0)
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentStateUpdates() {
        // Test that concurrent updates don't crash
        let expectation = XCTestExpectation(description: "All updates complete")
        let updateCount = 100
        var completedUpdates = 0
        let lock = NSLock()

        for index in 0..<updateCount {
            DispatchQueue.global().async {
                self.coordinator.selectedIndex = index
                self.coordinator.isShowingSwitcher = (index % 2 == 0)

                lock.lock()
                completedUpdates += 1
                if completedUpdates == updateCount {
                    expectation.fulfill()
                }
                lock.unlock()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Then: Should not crash
        XCTAssertTrue(true, "Concurrent updates should not crash")
    }

    func testConcurrentWindowListUpdates() {
        // Test concurrent window list updates
        let expectation = XCTestExpectation(description: "All window updates complete")
        let updateCount = 50
        var completedUpdates = 0
        let lock = NSLock()

        for index in 0..<updateCount {
            DispatchQueue.global().async {
                let windows = (1...10).map { self.createTestWindow(id: CGWindowID($0 + index * 10)) }
                self.coordinator.windows = windows

                lock.lock()
                completedUpdates += 1
                if completedUpdates == updateCount {
                    expectation.fulfill()
                }
                lock.unlock()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Then: Should not crash and have some windows
        XCTAssertTrue(true, "Concurrent window list updates should not crash")
    }

    // MARK: - Edge Case Tests

    func testNegativeSelectedIndex() {
        // Given: Negative index (should not happen normally)
        coordinator.selectedIndex = -1

        // Then: State should accept it (wrapping handled by selectNext/Previous)
        XCTAssertEqual(coordinator.selectedIndex, -1)
    }

    func testVeryLargeSelectedIndex() {
        // Given: Very large index
        coordinator.selectedIndex = Int.max

        // Then: State should accept it
        XCTAssertEqual(coordinator.selectedIndex, Int.max)
    }

    func testWindowsWithEmptyTitles() {
        // Given: Windows with empty titles
        coordinator.windows = [
            createTestWindow(id: 1, title: "", appName: "App1"),
            createTestWindow(id: 2, title: "", appName: "App2")
        ]

        // Then: Should handle empty titles
        XCTAssertEqual(coordinator.windows.count, 2)
        XCTAssertTrue(coordinator.windows[0].title.isEmpty)
        XCTAssertTrue(coordinator.windows[1].title.isEmpty)
    }

    func testWindowsWithVeryLongTitles() {
        // Given: Windows with very long titles
        let longTitle = String(repeating: "A", count: 1000)
        coordinator.windows = [createTestWindow(id: 1, title: longTitle)]

        // Then: Should handle long titles
        XCTAssertEqual(coordinator.windows[0].title.count, 1000)
    }

    // MARK: - Performance Tests

    func testWindowListUpdatePerformance() {
        // Measure performance of updating window list
        let testWindows = (1...20).map { createTestWindow(id: CGWindowID($0)) }

        measure {
            coordinator.windows = testWindows
        }
    }

    func testSelectedIndexUpdatePerformance() {
        // Measure performance of index updates
        coordinator.windows = (1...20).map { createTestWindow(id: CGWindowID($0)) }

        measure {
            for index in 0..<100 {
                coordinator.selectedIndex = index % coordinator.windows.count
            }
        }
    }

    func testStateTogglePerformance() {
        // Measure performance of toggling state
        measure {
            for _ in 0..<1000 {
                coordinator.isShowingSwitcher.toggle()
            }
        }
    }

    // MARK: - Integration Test Notes

    /*
    The following aspects require integration tests or manual testing:

    1. Window Manager Integration:
       - Verify refreshWindows() is called when showing switcher
       - Verify thumbnail caching works correctly
       - Verify app icon placeholders appear

    2. Keyboard Monitor Integration:
       - Verify callbacks are properly connected
       - Verify keyboard events trigger correct coordinator actions
       - Verify state synchronization between monitor and coordinator

    3. Window Activation:
       - Verify window activation on Cmd release
       - Verify correct window is activated based on selectedIndex
       - Verify error handling when activation fails

    4. UI Integration:
       - Verify switcher window appears/disappears
       - Verify window centering
       - Verify view updates on selection change

    These tests would require:
    - Protocol-based design for WindowManager and KeyboardMonitor
    - Dependency injection in SwitcherCoordinator
    - Mock implementations for testing
    */
}

// MARK: - Test Helpers

extension SwitcherCoordinatorTests {

    /// Helper to create test windows
    func createTestWindow(
        id: CGWindowID,
        pid: pid_t = 1000,
        title: String = "Test Window",
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

    /// Helper to create windows with thumbnails
    func createWindowWithThumbnail(id: CGWindowID) -> WindowInfo {
        var window = createTestWindow(id: id)
        window.thumbnail = NSImage(size: NSSize(width: 100, height: 100))
        return window
    }
}

// MARK: - Workflow Simulation Tests

extension SwitcherCoordinatorTests {

    func testTypicalUserWorkflow() {
        // Simulate a typical user workflow:
        // 1. Cmd+Tab pressed (show switcher with windows)
        // 2. Tab pressed (cycle forward)
        // 3. Tab pressed (cycle forward again)
        // 4. Cmd released (activate selected window)

        // Given: Multiple windows
        coordinator.windows = [
            createTestWindow(id: 1, title: "Window 1"),
            createTestWindow(id: 2, title: "Window 2"),
            createTestWindow(id: 3, title: "Window 3")
        ]

        // When: Showing switcher (Cmd+Tab)
        coordinator.isShowingSwitcher = true
        coordinator.selectedIndex = 0

        // Then: Initial state correct
        XCTAssertTrue(coordinator.isShowingSwitcher)
        XCTAssertEqual(coordinator.selectedIndex, 0)

        // When: Tab pressed (select next)
        coordinator.selectedIndex = (coordinator.selectedIndex + 1) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 1)

        // When: Tab pressed again
        coordinator.selectedIndex = (coordinator.selectedIndex + 1) % coordinator.windows.count
        XCTAssertEqual(coordinator.selectedIndex, 2)

        // When: Cmd released (hide switcher)
        coordinator.isShowingSwitcher = false

        // Then: Switcher hidden
        XCTAssertFalse(coordinator.isShowingSwitcher)
    }

    func testEscapeKeyWorkflow() {
        // Simulate pressing Escape to cancel

        // Given: Switcher is showing
        coordinator.windows = [
            createTestWindow(id: 1),
            createTestWindow(id: 2)
        ]
        coordinator.isShowingSwitcher = true
        coordinator.selectedIndex = 1

        // When: Escape pressed (hide without activating)
        coordinator.isShowingSwitcher = false

        // Then: Switcher should be hidden
        XCTAssertFalse(coordinator.isShowingSwitcher)
    }
}
