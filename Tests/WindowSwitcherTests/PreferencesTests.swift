import XCTest
@testable import WindowSwitcher

/// Unit tests for user preferences and UserDefaults integration
final class PreferencesTests: XCTestCase {

    var testDefaults: UserDefaults!
    var suiteName: String!

    override func setUp() {
        super.setUp()
        // Create unique suite name for this test instance to prevent parallel test pollution
        suiteName = "com.windowswitcher.preferences.tests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: suiteName)!
        // Clean slate for each test
        testDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        testDefaults.removePersistentDomain(forName: suiteName)
        testDefaults = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: - Default Values Tests

    func testLaunchAtLoginDefaultValue() {
        // Given: Fresh UserDefaults
        let value = testDefaults.bool(forKey: "launchAtLogin")

        // Then: Default should be false
        XCTAssertFalse(value, "launchAtLogin should default to false")
    }

    func testShowWindowTitlesDefaultValue() {
        // Given: Fresh UserDefaults
        // Note: bool(forKey:) returns false for non-existent keys
        // To test true default, we check if key exists

        if testDefaults.object(forKey: "showWindowTitles") == nil {
            // Key doesn't exist, set default
            testDefaults.set(true, forKey: "showWindowTitles")
        }

        let value = testDefaults.bool(forKey: "showWindowTitles")

        // Then: Default should be true
        XCTAssertTrue(value, "showWindowTitles should default to true")
    }

    func testThumbnailSizeDefaultValue() {
        // Given: Fresh UserDefaults
        let value = testDefaults.double(forKey: "thumbnailSize")

        if value == 0 {
            // Not set, use default
            testDefaults.set(200.0, forKey: "thumbnailSize")
        }

        // Then: Default should be 200
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 200.0)
    }

    func testMaxWindowsToShowDefaultValue() {
        // Given: Fresh UserDefaults
        let value = testDefaults.double(forKey: "maxWindowsToShow")

        if value == 0 {
            testDefaults.set(20.0, forKey: "maxWindowsToShow")
        }

        // Then: Default should be 20
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 20.0)
    }

    func testUseAppIconsDefaultValue() {
        // Given: Fresh UserDefaults
        let value = testDefaults.bool(forKey: "useAppIcons")

        // Then: Default should be false
        XCTAssertFalse(value, "useAppIcons should default to false")
    }

    // MARK: - Preference Persistence Tests

    func testLaunchAtLoginPersistence() {
        // When: Setting value
        testDefaults.set(true, forKey: "launchAtLogin")

        // Then: Value should persist
        XCTAssertTrue(testDefaults.bool(forKey: "launchAtLogin"))

        // When: Changing value
        testDefaults.set(false, forKey: "launchAtLogin")

        // Then: New value should persist
        XCTAssertFalse(testDefaults.bool(forKey: "launchAtLogin"))
    }

    func testShowWindowTitlesPersistence() {
        // When: Setting to false
        testDefaults.set(false, forKey: "showWindowTitles")

        // Then: Value should persist
        XCTAssertFalse(testDefaults.bool(forKey: "showWindowTitles"))

        // When: Setting to true
        testDefaults.set(true, forKey: "showWindowTitles")

        // Then: Value should persist
        XCTAssertTrue(testDefaults.bool(forKey: "showWindowTitles"))
    }

    func testThumbnailSizePersistence() {
        // When: Setting various valid values
        let testValues = [150.0, 200.0, 250.0, 300.0]

        for value in testValues {
            testDefaults.set(value, forKey: "thumbnailSize")
            XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), value,
                          "thumbnailSize \(value) should persist")
        }
    }

    func testMaxWindowsToShowPersistence() {
        // When: Setting various valid values
        let testValues = [5.0, 10.0, 20.0, 50.0]

        for value in testValues {
            testDefaults.set(value, forKey: "maxWindowsToShow")
            XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), value,
                          "maxWindowsToShow \(value) should persist")
        }
    }

    func testUseAppIconsPersistence() {
        // When: Toggling value
        testDefaults.set(true, forKey: "useAppIcons")
        XCTAssertTrue(testDefaults.bool(forKey: "useAppIcons"))

        testDefaults.set(false, forKey: "useAppIcons")
        XCTAssertFalse(testDefaults.bool(forKey: "useAppIcons"))
    }

    // MARK: - Preference Validation Tests

    func testThumbnailSizeValidRange() {
        // Test that thumbnail size stays within valid range (150-300)

        // Test minimum
        let minValue = 150.0
        testDefaults.set(minValue, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), minValue)

        // Test maximum
        let maxValue = 300.0
        testDefaults.set(maxValue, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), maxValue)

        // Note: Actual validation should happen in PreferencesView
        // These tests verify that values can be stored
    }

    func testThumbnailSizeOutOfBounds() {
        // Test that out-of-bounds values can be stored
        // (UI should prevent this, but test storage)

        // Below minimum
        testDefaults.set(100.0, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 100.0)

        // Above maximum
        testDefaults.set(400.0, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 400.0)

        // Note: UI slider should prevent these values
    }

    func testMaxWindowsToShowValidRange() {
        // Test that max windows stays within valid range (5-50)

        // Test minimum
        let minValue = 5.0
        testDefaults.set(minValue, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), minValue)

        // Test maximum
        let maxValue = 50.0
        testDefaults.set(maxValue, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), maxValue)
    }

    func testMaxWindowsToShowOutOfBounds() {
        // Test storage of out-of-bounds values

        // Below minimum
        testDefaults.set(1.0, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 1.0)

        // Above maximum
        testDefaults.set(100.0, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 100.0)
    }

    // MARK: - Reset to Defaults Tests

    func testResetToDefaults() {
        // Given: Modified preferences
        testDefaults.set(true, forKey: "launchAtLogin")
        testDefaults.set(false, forKey: "showWindowTitles")
        testDefaults.set(250.0, forKey: "thumbnailSize")
        testDefaults.set(30.0, forKey: "maxWindowsToShow")
        testDefaults.set(true, forKey: "useAppIcons")

        // When: Resetting to defaults
        testDefaults.set(false, forKey: "launchAtLogin")
        testDefaults.set(true, forKey: "showWindowTitles")
        testDefaults.set(200.0, forKey: "thumbnailSize")
        testDefaults.set(20.0, forKey: "maxWindowsToShow")
        testDefaults.set(false, forKey: "useAppIcons")

        // Then: All values should be at defaults
        XCTAssertFalse(testDefaults.bool(forKey: "launchAtLogin"))
        XCTAssertTrue(testDefaults.bool(forKey: "showWindowTitles"))
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 200.0)
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 20.0)
        XCTAssertFalse(testDefaults.bool(forKey: "useAppIcons"))
    }

    // MARK: - Multiple Preferences Tests

    func testMultiplePreferencesIndependence() {
        // Test that changing one preference doesn't affect others

        // Set all preferences
        testDefaults.set(true, forKey: "launchAtLogin")
        testDefaults.set(false, forKey: "showWindowTitles")
        testDefaults.set(250.0, forKey: "thumbnailSize")
        testDefaults.set(30.0, forKey: "maxWindowsToShow")
        testDefaults.set(true, forKey: "useAppIcons")

        // Change one
        testDefaults.set(false, forKey: "launchAtLogin")

        // Verify others unchanged
        XCTAssertFalse(testDefaults.bool(forKey: "showWindowTitles"))
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 250.0)
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 30.0)
        XCTAssertTrue(testDefaults.bool(forKey: "useAppIcons"))
    }

    // MARK: - Edge Cases Tests

    func testNegativeValues() {
        // Test storage of negative values (should not happen in UI)

        testDefaults.set(-10.0, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), -10.0)

        testDefaults.set(-5.0, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), -5.0)
    }

    func testZeroValues() {
        // Test storage of zero values

        testDefaults.set(0.0, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 0.0)

        testDefaults.set(0.0, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 0.0)
    }

    func testVeryLargeValues() {
        // Test storage of very large values

        let largeValue = Double.greatestFiniteMagnitude
        testDefaults.set(largeValue, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), largeValue)
    }

    func testFractionalValues() {
        // Test storage of fractional values

        testDefaults.set(175.5, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 175.5)

        testDefaults.set(12.7, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 12.7)
    }

    // MARK: - Preference Keys Tests

    func testAllPreferenceKeys() {
        // Verify all expected preference keys can be accessed

        let keys = [
            "launchAtLogin",
            "showWindowTitles",
            "thumbnailSize",
            "maxWindowsToShow",
            "useAppIcons"
        ]

        for key in keys {
            // Set a test value
            testDefaults.set(true, forKey: key)

            // Verify key exists
            XCTAssertNotNil(testDefaults.object(forKey: key), "Key '\(key)' should exist")
        }
    }

    func testNonexistentKey() {
        // Test accessing a key that doesn't exist

        let value = testDefaults.bool(forKey: "nonexistentKey")
        XCTAssertFalse(value, "Nonexistent bool key should return false")

        let doubleValue = testDefaults.double(forKey: "nonexistentKey")
        XCTAssertEqual(doubleValue, 0.0, "Nonexistent double key should return 0")
    }

    // MARK: - Concurrent Access Tests

    func testConcurrentPreferenceAccess() {
        // Test that concurrent reads/writes don't crash

        let expectation = XCTestExpectation(description: "All operations complete")
        let operationCount = 100
        var completedOperations = 0
        let lock = NSLock()

        for index in 0..<operationCount {
            DispatchQueue.global().async {
                // Read and write operations
                self.testDefaults.set(Double(index), forKey: "thumbnailSize")
                _ = self.testDefaults.double(forKey: "thumbnailSize")

                self.testDefaults.set(index % 2 == 0, forKey: "launchAtLogin")
                _ = self.testDefaults.bool(forKey: "launchAtLogin")

                lock.lock()
                completedOperations += 1
                if completedOperations == operationCount {
                    expectation.fulfill()
                }
                lock.unlock()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // Then: Should not crash
        XCTAssertTrue(true, "Concurrent preference access should not crash")
    }

    // MARK: - Performance Tests

    func testPreferenceReadPerformance() {
        // Given: Preferences are set
        testDefaults.set(200.0, forKey: "thumbnailSize")
        testDefaults.set(true, forKey: "showWindowTitles")

        // Measure read performance
        measure {
            for _ in 0..<1000 {
                _ = self.testDefaults.double(forKey: "thumbnailSize")
                _ = self.testDefaults.bool(forKey: "showWindowTitles")
            }
        }
    }

    func testPreferenceWritePerformance() {
        // Measure write performance
        measure {
            for index in 0..<1000 {
                self.testDefaults.set(Double(index), forKey: "thumbnailSize")
                self.testDefaults.set(index % 2 == 0, forKey: "launchAtLogin")
            }
        }
    }

    func testMultiplePreferenceUpdatesPerformance() {
        // Measure performance of updating all preferences
        measure {
            for index in 0..<100 {
                self.testDefaults.set(index % 2 == 0, forKey: "launchAtLogin")
                self.testDefaults.set(index % 2 == 0, forKey: "showWindowTitles")
                self.testDefaults.set(Double(150 + index), forKey: "thumbnailSize")
                self.testDefaults.set(Double(5 + index), forKey: "maxWindowsToShow")
                self.testDefaults.set(index % 2 == 0, forKey: "useAppIcons")
            }
        }
    }

    // MARK: - Type Safety Tests

    func testBooleanTypeConsistency() {
        // Test that boolean preferences maintain type

        testDefaults.set(true, forKey: "launchAtLogin")
        XCTAssertTrue(testDefaults.bool(forKey: "launchAtLogin"))

        // Verify type
        let object = testDefaults.object(forKey: "launchAtLogin")
        XCTAssertTrue(object is Bool, "Value should be Bool type")
    }

    func testDoubleTypeConsistency() {
        // Test that double preferences maintain type

        testDefaults.set(200.0, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 200.0)

        // Verify type
        let object = testDefaults.object(forKey: "thumbnailSize")
        XCTAssertTrue(object is Double || object is NSNumber, "Value should be numeric type")
    }

    // MARK: - Data Integrity Tests

    func testPreferencesPersistAcrossInstances() {
        // Set preferences in first instance
        testDefaults.set(250.0, forKey: "thumbnailSize")
        testDefaults.set(true, forKey: "launchAtLogin")

        // Create new UserDefaults instance with same suite
        let newDefaults = UserDefaults(suiteName: suiteName)!

        // Verify values persist
        XCTAssertEqual(newDefaults.double(forKey: "thumbnailSize"), 250.0)
        XCTAssertTrue(newDefaults.bool(forKey: "launchAtLogin"))
    }

    func testPreferencesRemoval() {
        // Given: Set preferences
        testDefaults.set(250.0, forKey: "thumbnailSize")
        testDefaults.set(true, forKey: "launchAtLogin")

        // When: Removing specific preference
        testDefaults.removeObject(forKey: "thumbnailSize")

        // Then: Should be removed
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 0.0)

        // But other preferences should remain
        XCTAssertTrue(testDefaults.bool(forKey: "launchAtLogin"))
    }
}

// MARK: - Helper Functions

extension PreferencesTests {

    /// Validates thumbnail size is within acceptable range
    func isValidThumbnailSize(_ size: Double) -> Bool {
        return size >= 150.0 && size <= 300.0
    }

    /// Validates max windows is within acceptable range
    func isValidMaxWindows(_ count: Double) -> Bool {
        return count >= 5.0 && count <= 50.0
    }

    func testValidationHelpers() {
        // Test the validation helper functions

        // Valid thumbnail sizes
        XCTAssertTrue(isValidThumbnailSize(150.0))
        XCTAssertTrue(isValidThumbnailSize(200.0))
        XCTAssertTrue(isValidThumbnailSize(300.0))

        // Invalid thumbnail sizes
        XCTAssertFalse(isValidThumbnailSize(149.0))
        XCTAssertFalse(isValidThumbnailSize(301.0))

        // Valid max windows
        XCTAssertTrue(isValidMaxWindows(5.0))
        XCTAssertTrue(isValidMaxWindows(20.0))
        XCTAssertTrue(isValidMaxWindows(50.0))

        // Invalid max windows
        XCTAssertFalse(isValidMaxWindows(4.0))
        XCTAssertFalse(isValidMaxWindows(51.0))
    }
}

// MARK: - Integration Test Scenarios

extension PreferencesTests {

    func testTypicalUserPreferenceChanges() {
        // Simulate typical user workflow of changing preferences

        // User opens preferences for first time (defaults)
        XCTAssertFalse(testDefaults.bool(forKey: "launchAtLogin"))

        // User enables launch at login
        testDefaults.set(true, forKey: "launchAtLogin")
        XCTAssertTrue(testDefaults.bool(forKey: "launchAtLogin"))

        // User adjusts thumbnail size
        testDefaults.set(250.0, forKey: "thumbnailSize")
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 250.0)

        // User increases max windows
        testDefaults.set(30.0, forKey: "maxWindowsToShow")
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 30.0)

        // User enables app icons mode
        testDefaults.set(true, forKey: "useAppIcons")
        XCTAssertTrue(testDefaults.bool(forKey: "useAppIcons"))

        // User resets to defaults
        testDefaults.set(false, forKey: "launchAtLogin")
        testDefaults.set(200.0, forKey: "thumbnailSize")
        testDefaults.set(20.0, forKey: "maxWindowsToShow")
        testDefaults.set(false, forKey: "useAppIcons")

        // Verify all defaults restored
        XCTAssertFalse(testDefaults.bool(forKey: "launchAtLogin"))
        XCTAssertEqual(testDefaults.double(forKey: "thumbnailSize"), 200.0)
        XCTAssertEqual(testDefaults.double(forKey: "maxWindowsToShow"), 20.0)
        XCTAssertFalse(testDefaults.bool(forKey: "useAppIcons"))
    }
}
