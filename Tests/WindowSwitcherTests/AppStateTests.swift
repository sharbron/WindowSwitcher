import XCTest
import SwiftUI
@testable import WindowSwitcher

/// Unit tests for AppState class
@MainActor
final class AppStateTests: XCTestCase {

    var appState: AppState!

    override func setUp() async throws {
        await MainActor.run {
            appState = AppState()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            // Clean up any open windows
            appState.aboutWindow?.close()
            appState.preferencesWindow?.close()
            appState = nil
        }
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Then: Initial state should be correct
        XCTAssertFalse(appState.isAboutWindowOpen, "About window should not be open initially")
        XCTAssertFalse(appState.isPreferencesWindowOpen, "Preferences window should not be open initially")
        XCTAssertNil(appState.aboutWindow, "About window reference should be nil initially")
        XCTAssertNil(appState.preferencesWindow, "Preferences window reference should be nil initially")
    }

    // MARK: - About Window Tests

    func testOpenAboutWindow() {
        // When: Opening about window
        appState.openAboutWindow()

        // Then: About window should be open
        XCTAssertTrue(appState.isAboutWindowOpen, "About window flag should be true")
        XCTAssertNotNil(appState.aboutWindow, "About window reference should be set")
        XCTAssertTrue(appState.aboutWindow?.isVisible ?? false, "About window should be visible")
    }

    func testOpenAboutWindowMultipleTimes() {
        // Given: About window is already open
        appState.openAboutWindow()
        let firstWindow = appState.aboutWindow

        // When: Opening about window again
        appState.openAboutWindow()

        // Then: Should reuse the same window
        XCTAssertEqual(appState.aboutWindow, firstWindow, "Should not create multiple about windows")
        XCTAssertTrue(appState.aboutWindow?.isKeyWindow ?? false, "Window should be brought to front")
    }

    func testAboutWindowTitle() {
        // When: Opening about window
        appState.openAboutWindow()

        // Then: Window should have correct title
        XCTAssertEqual(appState.aboutWindow?.title, "About Window Switcher")
    }

    // MARK: - Preferences Window Tests

    func testOpenPreferencesWindow() {
        // When: Opening preferences window
        appState.openPreferencesWindow()

        // Then: Preferences window should be open
        XCTAssertTrue(appState.isPreferencesWindowOpen, "Preferences window flag should be true")
        XCTAssertNotNil(appState.preferencesWindow, "Preferences window reference should be set")
        XCTAssertTrue(appState.preferencesWindow?.isVisible ?? false, "Preferences window should be visible")
    }

    func testOpenPreferencesWindowMultipleTimes() {
        // Given: Preferences window is already open
        appState.openPreferencesWindow()
        let firstWindow = appState.preferencesWindow

        // When: Opening preferences window again
        appState.openPreferencesWindow()

        // Then: Should reuse the same window
        XCTAssertEqual(appState.preferencesWindow, firstWindow, "Should not create multiple preferences windows")
        XCTAssertTrue(appState.preferencesWindow?.isKeyWindow ?? false, "Window should be brought to front")
    }

    func testPreferencesWindowTitle() {
        // When: Opening preferences window
        appState.openPreferencesWindow()

        // Then: Window should have correct title
        XCTAssertEqual(appState.preferencesWindow?.title, "Window Switcher Preferences")
    }

    // MARK: - Multiple Windows Tests

    func testOpenBothWindows() {
        // When: Opening both windows
        appState.openAboutWindow()
        appState.openPreferencesWindow()

        // Then: Both windows should be open
        XCTAssertTrue(appState.isAboutWindowOpen)
        XCTAssertTrue(appState.isPreferencesWindowOpen)
        XCTAssertNotNil(appState.aboutWindow)
        XCTAssertNotNil(appState.preferencesWindow)
        XCTAssertNotEqual(appState.aboutWindow, appState.preferencesWindow, "Windows should be different")
    }

    // MARK: - Window Close Notification Tests

    func testAboutWindowCloseNotification() async {
        // Given: About window is open
        appState.openAboutWindow()
        guard let window = appState.aboutWindow else {
            XCTFail("About window should be created")
            return
        }

        // When: Closing the window
        window.close()

        // Wait for notification to be processed
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: State should be updated
        XCTAssertFalse(appState.isAboutWindowOpen, "About window flag should be false after closing")
    }

    func testPreferencesWindowCloseNotification() async {
        // Given: Preferences window is open
        appState.openPreferencesWindow()
        guard let window = appState.preferencesWindow else {
            XCTFail("Preferences window should be created")
            return
        }

        // When: Closing the window
        window.close()

        // Wait for notification to be processed
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

        // Then: State should be updated
        XCTAssertFalse(appState.isPreferencesWindowOpen, "Preferences window flag should be false after closing")
    }

    // MARK: - Window Size Tests

    func testAboutWindowSize() {
        // When: Opening about window
        appState.openAboutWindow()

        // Then: Window should have expected content size
        guard let window = appState.aboutWindow else {
            XCTFail("About window should be created")
            return
        }

        // Check content size (excludes title bar)
        let expectedContentSize = NSSize(width: 420, height: 540)
        let contentFrame = window.contentView?.frame ?? .zero
        XCTAssertEqual(contentFrame.size.width, expectedContentSize.width, accuracy: 1.0)
        XCTAssertEqual(contentFrame.size.height, expectedContentSize.height, accuracy: 1.0)
    }

    func testPreferencesWindowSize() {
        // When: Opening preferences window
        appState.openPreferencesWindow()

        // Then: Window should have expected content size
        guard let window = appState.preferencesWindow else {
            XCTFail("Preferences window should be created")
            return
        }

        // Check content size (excludes title bar)
        let expectedContentSize = NSSize(width: 600, height: 650)
        let contentFrame = window.contentView?.frame ?? .zero
        XCTAssertEqual(contentFrame.size.width, expectedContentSize.width, accuracy: 1.0)
        XCTAssertEqual(contentFrame.size.height, expectedContentSize.height, accuracy: 1.0)
    }

    // MARK: - Window Style Tests

    func testAboutWindowStyle() {
        // When: Opening about window
        appState.openAboutWindow()

        // Then: Window should have correct style
        guard let window = appState.aboutWindow else {
            XCTFail("About window should be created")
            return
        }

        XCTAssertTrue(window.styleMask.contains(.titled), "Window should have title bar")
        XCTAssertTrue(window.styleMask.contains(.closable), "Window should be closable")
        XCTAssertTrue(window.styleMask.contains(.miniaturizable), "Window should be miniaturizable")
        XCTAssertFalse(window.styleMask.contains(.resizable), "Window should not be resizable")
    }
}
