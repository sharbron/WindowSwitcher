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
        // Note: Cannot test isKeyWindow in unit tests (requires window server)
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
        // Note: Cannot test isKeyWindow in unit tests (requires window server)
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

        // Asserting a fixed number here is what let the About window ship clipped: its content
        // grew past 540pt and SwiftUI centre-cropped the title off the top and the email link
        // off the bottom. The window is now driven by an NSHostingController, so AppKit sizes
        // it from the content — assert that mechanism and the content's own measurements.
        // (Final window geometry needs a display cycle, so it is not observable here.)
        XCTAssertNotNil(
            window.contentViewController,
            "Window must be driven by a hosting controller so AppKit tracks the content size"
        )

        guard let contentView = window.contentView else {
            XCTFail("Window should have a content view")
            return
        }

        XCTAssertEqual(contentView.fittingSize.width, 420, accuracy: 1.0, "About is a fixed-width layout")
        XCTAssertGreaterThan(contentView.fittingSize.height, 0, "Content must report a real height")
    }

    func testPreferencesWindowSize() {
        // When: Opening preferences window
        appState.openPreferencesWindow()

        // Then: Window should have expected content size
        guard let window = appState.preferencesWindow else {
            XCTFail("Preferences window should be created")
            return
        }

        // Settings is a tabbed window that resizes to the selected tab, so it must be driven by
        // a hosting controller rather than a fixed contentRect.
        XCTAssertNotNil(window.contentViewController)

        guard let contentView = window.contentView else {
            XCTFail("Window should have a content view")
            return
        }

        XCTAssertEqual(contentView.fittingSize.width, SettingsTab.width, accuracy: 1.0)
        XCTAssertEqual(
            contentView.fittingSize.height,
            SettingsTab.general.contentHeight,
            accuracy: 1.0,
            "Should open sized to the General tab"
        )
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
