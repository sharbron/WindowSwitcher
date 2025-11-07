import XCTest
@testable import WindowSwitcher

/// Unit tests for WindowInfo model and basic operations
final class WindowInfoTests: XCTestCase {

    // MARK: - WindowInfo Model Tests

    func testWindowInfoEquality() {
        // Given: Two WindowInfo instances with the same ID
        let window1 = WindowInfo(
            id: 123,
            ownerPID: 456,
            title: "Test Window",
            appName: "TestApp",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            isOnScreen: true,
            thumbnail: nil
        )

        let window2 = WindowInfo(
            id: 123,
            ownerPID: 789, // Different PID but same ID
            title: "Different Title",
            appName: "DifferentApp",
            bounds: CGRect(x: 100, y: 100, width: 1000, height: 800),
            layer: 0,
            isOnScreen: true,
            thumbnail: nil
        )

        // Then: Windows should be equal based on ID only
        XCTAssertEqual(window1, window2, "WindowInfo equality should be based on ID only")
    }

    func testWindowInfoInequality() {
        // Given: Two WindowInfo instances with different IDs
        let window1 = WindowInfo(
            id: 123,
            ownerPID: 456,
            title: "Test Window",
            appName: "TestApp",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            isOnScreen: true,
            thumbnail: nil
        )

        let window2 = WindowInfo(
            id: 456,
            ownerPID: 456,
            title: "Test Window",
            appName: "TestApp",
            bounds: CGRect(x: 0, y: 0, width: 800, height: 600),
            layer: 0,
            isOnScreen: true,
            thumbnail: nil
        )

        // Then: Windows should not be equal
        XCTAssertNotEqual(window1, window2, "WindowInfo with different IDs should not be equal")
    }

    func testWindowInfoIdentifiable() {
        // Given: A WindowInfo instance
        let windowID: CGWindowID = 789
        let window = WindowInfo(
            id: windowID,
            ownerPID: 456,
            title: "Test",
            appName: "App",
            bounds: .zero,
            layer: 0,
            isOnScreen: true,
            thumbnail: nil
        )

        // Then: ID should match
        XCTAssertEqual(window.id, windowID, "WindowInfo.id should match the provided ID")
    }

    func testWindowInfoWithThumbnail() {
        // Given: A test image
        let testImage = NSImage(size: NSSize(width: 100, height: 100))

        let window = WindowInfo(
            id: 123,
            ownerPID: 456,
            title: "Test",
            appName: "App",
            bounds: .zero,
            layer: 0,
            isOnScreen: true,
            thumbnail: testImage
        )

        // Then: Thumbnail should be set
        XCTAssertNotNil(window.thumbnail, "WindowInfo should store thumbnail")
        XCTAssertEqual(window.thumbnail?.size, testImage.size, "Thumbnail size should match")
    }

    // MARK: - WindowInfo Array Tests

    func testWindowInfoArrayFiltering() {
        // Given: An array of windows
        let windows = [
            WindowInfo(id: 1, ownerPID: 100, title: "Window 1", appName: "App A",
                      bounds: .zero, layer: 0, isOnScreen: true, thumbnail: nil),
            WindowInfo(id: 2, ownerPID: 101, title: "Window 2", appName: "App B",
                      bounds: .zero, layer: 0, isOnScreen: false, thumbnail: nil),
            WindowInfo(id: 3, ownerPID: 102, title: "Window 3", appName: "App A",
                      bounds: .zero, layer: 0, isOnScreen: true, thumbnail: nil)
        ]

        // When: Filtering by app name
        let appAWindows = windows.filter { $0.appName == "App A" }

        // Then: Should get 2 windows
        XCTAssertEqual(appAWindows.count, 2, "Should find 2 windows from App A")
        XCTAssertTrue(appAWindows.allSatisfy { $0.appName == "App A" }, "All filtered windows should be from App A")
    }

    func testWindowInfoArraySorting() {
        // Given: An unsorted array of windows
        let windows = [
            WindowInfo(id: 3, ownerPID: 100, title: "Charlie", appName: "App C",
                      bounds: .zero, layer: 0, isOnScreen: true, thumbnail: nil),
            WindowInfo(id: 1, ownerPID: 101, title: "Alice", appName: "App A",
                      bounds: .zero, layer: 0, isOnScreen: true, thumbnail: nil),
            WindowInfo(id: 2, ownerPID: 102, title: "Bob", appName: "App B",
                      bounds: .zero, layer: 0, isOnScreen: true, thumbnail: nil)
        ]

        // When: Sorting by app name
        let sorted = windows.sorted { $0.appName < $1.appName }

        // Then: Should be in alphabetical order by app name
        XCTAssertEqual(sorted[0].appName, "App A")
        XCTAssertEqual(sorted[1].appName, "App B")
        XCTAssertEqual(sorted[2].appName, "App C")
    }
}
