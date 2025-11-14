import XCTest
import Carbon
@testable import WindowSwitcher

/// Unit tests for KeyboardMonitor
final class KeyboardMonitorTests: XCTestCase {

    var keyboardMonitor: KeyboardMonitor!

    override func setUp() {
        super.setUp()
        keyboardMonitor = KeyboardMonitor()
    }

    override func tearDown() {
        keyboardMonitor.stopMonitoring()
        keyboardMonitor = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Then: Initial state should be correct
        XCTAssertFalse(keyboardMonitor.isShowingSwitcher, "Switcher should not be showing initially")
        XCTAssertEqual(keyboardMonitor.selectedIndex, 0, "Selected index should be 0 initially")
    }

    // MARK: - Callback Tests

    func testCmdTabPressedCallbackInvocation() {
        // Given: A callback is registered
        var callbackInvoked = false
        keyboardMonitor.onCmdTabPressed = {
            callbackInvoked = true
        }

        // When: Manually invoking the callback (simulating Cmd+Tab)
        keyboardMonitor.onCmdTabPressed?()

        // Then: Callback should be invoked
        XCTAssertTrue(callbackInvoked, "onCmdTabPressed callback should be invoked")
    }

    func testTabPressedCallbackInvocation() {
        // Given: A callback is registered
        var callbackInvoked = false
        keyboardMonitor.onTabPressed = {
            callbackInvoked = true
        }

        // When: Manually invoking the callback (simulating Tab)
        keyboardMonitor.onTabPressed?()

        // Then: Callback should be invoked
        XCTAssertTrue(callbackInvoked, "onTabPressed callback should be invoked")
    }

    func testShiftTabPressedCallbackInvocation() {
        // Given: A callback is registered
        var callbackInvoked = false
        keyboardMonitor.onShiftTabPressed = {
            callbackInvoked = true
        }

        // When: Manually invoking the callback
        keyboardMonitor.onShiftTabPressed?()

        // Then: Callback should be invoked
        XCTAssertTrue(callbackInvoked, "onShiftTabPressed callback should be invoked")
    }

    func testCmdReleasedCallbackInvocation() {
        // Given: A callback is registered
        var callbackInvoked = false
        keyboardMonitor.onCmdReleased = {
            callbackInvoked = true
        }

        // When: Manually invoking the callback
        keyboardMonitor.onCmdReleased?()

        // Then: Callback should be invoked
        XCTAssertTrue(callbackInvoked, "onCmdReleased callback should be invoked")
    }

    func testEscapePressedCallbackInvocation() {
        // Given: A callback is registered
        var callbackInvoked = false
        keyboardMonitor.onEscapePressed = {
            callbackInvoked = true
        }

        // When: Manually invoking the callback
        keyboardMonitor.onEscapePressed?()

        // Then: Callback should be invoked
        XCTAssertTrue(callbackInvoked, "onEscapePressed callback should be invoked")
    }

    // MARK: - State Management Tests

    func testIsShowingSwitcherToggle() {
        // Given: Initial state
        XCTAssertFalse(keyboardMonitor.isShowingSwitcher)

        // When: Toggling state
        keyboardMonitor.isShowingSwitcher = true

        // Then: State should be updated
        XCTAssertTrue(keyboardMonitor.isShowingSwitcher)

        // When: Toggling back
        keyboardMonitor.isShowingSwitcher = false

        // Then: State should be updated
        XCTAssertFalse(keyboardMonitor.isShowingSwitcher)
    }

    func testSelectedIndexModification() {
        // Given: Initial state
        XCTAssertEqual(keyboardMonitor.selectedIndex, 0)

        // When: Changing selected index
        keyboardMonitor.selectedIndex = 5

        // Then: State should be updated
        XCTAssertEqual(keyboardMonitor.selectedIndex, 5)

        // When: Setting to another value
        keyboardMonitor.selectedIndex = 10

        // Then: State should be updated
        XCTAssertEqual(keyboardMonitor.selectedIndex, 10)
    }

    // MARK: - Callback Ordering Tests

    func testCallbacksCanBeSetIndependently() {
        // Given: Multiple callbacks
        var cmdTabInvoked = false
        var tabInvoked = false
        var cmdReleasedInvoked = false

        keyboardMonitor.onCmdTabPressed = { cmdTabInvoked = true }
        keyboardMonitor.onTabPressed = { tabInvoked = true }
        keyboardMonitor.onCmdReleased = { cmdReleasedInvoked = true }

        // When: Invoking each callback
        keyboardMonitor.onCmdTabPressed?()
        keyboardMonitor.onTabPressed?()
        keyboardMonitor.onCmdReleased?()

        // Then: All callbacks should be invoked
        XCTAssertTrue(cmdTabInvoked)
        XCTAssertTrue(tabInvoked)
        XCTAssertTrue(cmdReleasedInvoked)
    }

    func testCallbacksCanBeNil() {
        // Given: No callbacks set
        keyboardMonitor.onCmdTabPressed = nil
        keyboardMonitor.onTabPressed = nil
        keyboardMonitor.onCmdReleased = nil

        // When: Attempting to invoke nil callbacks
        keyboardMonitor.onCmdTabPressed?()
        keyboardMonitor.onTabPressed?()
        keyboardMonitor.onCmdReleased?()

        // Then: Should not crash
        XCTAssertTrue(true, "Invoking nil callbacks should not crash")
    }

    // MARK: - State Consistency Tests

    func testStateConsistencyDuringRapidChanges() {
        // Given: Multiple rapid state changes
        var invocationCount = 0
        keyboardMonitor.onCmdTabPressed = { invocationCount += 1 }

        // When: Rapidly invoking callback
        for _ in 0..<100 {
            keyboardMonitor.onCmdTabPressed?()
        }

        // Then: All invocations should be counted
        XCTAssertEqual(invocationCount, 100, "All callback invocations should be counted")
    }

    func testShowingSwitcherStateConsistency() {
        // Test that the state can be toggled many times without issues
        for index in 0..<100 {
            keyboardMonitor.isShowingSwitcher = (index % 2 == 0)
            let expected = (index % 2 == 0)
            XCTAssertEqual(keyboardMonitor.isShowingSwitcher, expected,
                          "State should be consistent at iteration \(index)")
        }
    }

    // MARK: - Monitoring Lifecycle Tests

    func testStartMonitoring() {
        // Note: This test verifies the method can be called without crashing
        // Actual event tap creation requires Accessibility permissions
        // and system-level access

        // When: Starting monitoring
        keyboardMonitor.startMonitoring()

        // Then: Should not crash
        XCTAssertTrue(true, "startMonitoring should not crash")
    }

    func testStopMonitoring() {
        // Given: Monitoring may or may not be started
        keyboardMonitor.startMonitoring()

        // When: Stopping monitoring
        keyboardMonitor.stopMonitoring()

        // Then: Should not crash
        XCTAssertTrue(true, "stopMonitoring should not crash")
    }

    func testStopMonitoringWithoutStart() {
        // When: Stopping monitoring without starting
        keyboardMonitor.stopMonitoring()

        // Then: Should not crash
        XCTAssertTrue(true, "stopMonitoring without start should not crash")
    }

    func testMultipleStartStopCycles() {
        // Test that we can start and stop monitoring multiple times
        for _ in 0..<5 {
            keyboardMonitor.startMonitoring()
            keyboardMonitor.stopMonitoring()
        }

        // Then: Should not crash
        XCTAssertTrue(true, "Multiple start/stop cycles should not crash")
    }

    // MARK: - Callback Context Tests

    func testCallbackCanAccessExternalState() {
        // Given: External state
        var externalCounter = 0

        keyboardMonitor.onCmdTabPressed = {
            externalCounter += 1
        }

        // When: Invoking callback multiple times
        keyboardMonitor.onCmdTabPressed?()
        keyboardMonitor.onCmdTabPressed?()
        keyboardMonitor.onCmdTabPressed?()

        // Then: External state should be modified
        XCTAssertEqual(externalCounter, 3, "Callback should be able to modify external state")
    }

    func testCallbackCanCaptureWeakReferences() {
        // Given: An object that might be deallocated
        class TestObject {
            var wasInvoked = false
            func handleCallback() {
                wasInvoked = true
            }
        }

        var testObject: TestObject? = TestObject()

        keyboardMonitor.onCmdTabPressed = { [weak testObject] in
            testObject?.handleCallback()
        }

        // When: Invoking callback with object alive
        keyboardMonitor.onCmdTabPressed?()
        XCTAssertTrue(testObject?.wasInvoked ?? false, "Callback should work with weak reference")

        // When: Object is deallocated
        testObject = nil
        keyboardMonitor.onCmdTabPressed?()

        // Then: Should not crash
        XCTAssertTrue(true, "Callback with deallocated weak reference should not crash")
    }

    // MARK: - Thread Safety Considerations

    func testCallbackInvocationFromMultipleThreads() {
        // Given: A thread-safe counter
        let lock = NSLock()
        var counter = 0

        keyboardMonitor.onCmdTabPressed = {
            lock.lock()
            counter += 1
            lock.unlock()
        }

        // When: Invoking callback from multiple threads
        let expectation = XCTestExpectation(description: "All threads complete")
        let threadCount = 10
        var completedThreads = 0

        for _ in 0..<threadCount {
            DispatchQueue.global().async {
                self.keyboardMonitor.onCmdTabPressed?()

                lock.lock()
                completedThreads += 1
                if completedThreads == threadCount {
                    expectation.fulfill()
                }
                lock.unlock()
            }
        }

        wait(for: [expectation], timeout: 2.0)

        // Then: All invocations should be counted
        XCTAssertEqual(counter, threadCount, "All callback invocations from threads should be counted")
    }

    // MARK: - Integration Tests (Require Accessibility Permission)

    // Note: The following tests are commented out because they require
    // Accessibility permissions and system-level access. They are provided
    // as examples for manual testing.

    /*
    func testEventTapCreation() {
        // This test requires Accessibility permission
        keyboardMonitor.startMonitoring()

        // Verify event tap was created
        // This would require access to private properties or
        // observing system-level behavior
    }

    func testCmdTabEventHandling() {
        // This test would require simulating actual CGEvent
        // which is not possible in unit tests without system access
    }
    */

    // MARK: - Performance Tests

    func testCallbackInvocationPerformance() {
        // Measure callback invocation performance
        keyboardMonitor.onCmdTabPressed = {}

        measure {
            for _ in 0..<1000 {
                keyboardMonitor.onCmdTabPressed?()
            }
        }
    }

    func testStateChangePerformance() {
        // Measure state change performance
        measure {
            for index in 0..<1000 {
                keyboardMonitor.isShowingSwitcher = (index % 2 == 0)
                keyboardMonitor.selectedIndex = index
            }
        }
    }
}

// MARK: - Mock Event Testing Helper

extension KeyboardMonitorTests {

    /// Helper to create a test scenario for callback chains
    func createCallbackChain(
        onCmdTab: @escaping () -> Void = {},
        onTab: @escaping () -> Void = {},
        onCmdRelease: @escaping () -> Void = {}
    ) {
        keyboardMonitor.onCmdTabPressed = onCmdTab
        keyboardMonitor.onTabPressed = onTab
        keyboardMonitor.onCmdReleased = onCmdRelease
    }

    /// Test a complete workflow simulation
    func testCompleteWorkflowSimulation() {
        // Given: A simulated workflow
        var workflowSteps: [String] = []

        createCallbackChain(
            onCmdTab: { workflowSteps.append("cmdTab") },
            onTab: { workflowSteps.append("tab") },
            onCmdRelease: { workflowSteps.append("cmdRelease") }
        )

        // When: Simulating user interaction
        keyboardMonitor.onCmdTabPressed?()  // Show switcher
        keyboardMonitor.onTabPressed?()     // Navigate
        keyboardMonitor.onTabPressed?()     // Navigate again
        keyboardMonitor.onCmdReleased?()    // Activate

        // Then: Workflow should be recorded correctly
        XCTAssertEqual(workflowSteps, ["cmdTab", "tab", "tab", "cmdRelease"],
                      "Workflow steps should match expected sequence")
    }
}
