import Cocoa
import os.log

/// Captures window preview images and keeps a recent one for every on-screen window.
///
/// Split out of `WindowManager` so the capture pipeline — screen captures, downsampling, the
/// refresh timer and its three pieces of lock-guarded state — sits behind a small surface
/// instead of being interleaved with window enumeration and activation.
final class ThumbnailCache {
    /// Captures are downsampled to this pixel width. The largest thumbnail the UI can draw is
    /// 300pt, so this covers a 2x Retina display with headroom. Keeping the native capture
    /// instead costs roughly 20MB per window and none of it is ever visible.
    static let maxPixelWidth: CGFloat = 640

    private static let refreshInterval: TimeInterval = 1.0

    private let logger = Logger(subsystem: "com.windowswitcher", category: "ThumbnailCache")

    /// Written from the background capture queue, read during window enumeration.
    private var images: [CGWindowID: NSImage] = [:]
    private let imagesLock = NSLock()

    private var refreshTimer: Timer?
    private var isRefreshActive = false
    private let refreshStateLock = NSLock()

    /// Stops refresh passes from stacking up if one capture runs longer than the interval.
    private var refreshInFlight = false
    private let refreshInFlightLock = NSLock()

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    deinit {
        // Do NOT touch `self` here: forming a weak reference to a deallocating object traps.
        // Capture the timer itself and invalidate it on the run loop that scheduled it.
        if let timer = refreshTimer {
            DispatchQueue.main.async { timer.invalidate() }
        }
    }

    // MARK: - Cache Access

    func image(for windowID: CGWindowID) -> NSImage? {
        imagesLock.lock()
        defer { imagesLock.unlock() }
        return images[windowID]
    }

    // MARK: - Periodic Refresh

    func startPeriodicRefresh() {
        refreshStateLock.lock()
        defer { refreshStateLock.unlock() }

        guard !isRefreshActive else { return }
        isRefreshActive = true

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let interval = Self.refreshInterval
            self.refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
                self?.refresh()
            }
        }
    }

    func stopPeriodicRefresh() {
        refreshStateLock.lock()
        defer { refreshStateLock.unlock() }

        guard isRefreshActive else { return }
        isRefreshActive = false

        DispatchQueue.main.async { [weak self] in
            self?.refreshTimer?.invalidate()
            self?.refreshTimer = nil
        }
    }

    private func refresh() {
        refreshInFlightLock.lock()
        if refreshInFlight {
            refreshInFlightLock.unlock()
            return
        }
        refreshInFlight = true
        refreshInFlightLock.unlock()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            defer {
                self.refreshInFlightLock.lock()
                self.refreshInFlight = false
                self.refreshInFlightLock.unlock()
            }

            let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
            guard let windowInfoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
                return
            }

            var newImages: [CGWindowID: NSImage] = [:]

            for windowInfo in windowInfoList {
                guard let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID,
                      let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                      let layer = windowInfo[kCGWindowLayer as String] as? Int,
                      layer == 0 else {
                    continue
                }

                let placeholder = WindowInfo(
                    id: windowID,
                    ownerPID: ownerPID,
                    title: "",
                    appName: "",
                    bounds: .zero,
                    layer: layer,
                    isOnScreen: true,
                    thumbnail: nil
                )

                if let thumbnail = self.capture(placeholder) {
                    newImages[windowID] = thumbnail
                }
            }

            self.imagesLock.lock()
            self.images = newImages
            self.imagesLock.unlock()
            self.logger.debug("Thumbnail cache updated with \(newImages.count) entries")
        }
    }

    // MARK: - Capture

    func capture(_ window: WindowInfo) -> NSImage? {
        // Check user preference for using app icons
        if userDefaults.bool(forKey: "useAppIcons") {
            return Self.appIcon(for: window)
        }

        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            window.id,
            [.bestResolution, .boundsIgnoreFraming]
        ) else {
            logger.warning("Failed to capture thumbnail for window: \(window.title) (ID: \(window.id))")
            // Fall back to app icon if thumbnail capture fails (likely no Screen Recording permission)
            return Self.appIcon(for: window)
        }

        logger.debug("Successfully captured thumbnail for window: \(window.title)")
        return downsampled(cgImage, maxPixelWidth: Self.maxPixelWidth)
    }

    /// Scales a capture down to display size.
    ///
    /// Captures come back at native Retina resolution — a 1440x900pt window is a 2880x1800px,
    /// ~20MB bitmap — but the switcher never draws one wider than 300pt.
    /// Internal rather than private so the scaling behaviour can be unit tested directly.
    func downsampled(_ cgImage: CGImage, maxPixelWidth: CGFloat = ThumbnailCache.maxPixelWidth) -> NSImage {
        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)

        func fullSize() -> NSImage {
            NSImage(cgImage: cgImage, size: NSSize(width: sourceWidth, height: sourceHeight))
        }

        guard sourceWidth > maxPixelWidth, sourceHeight > 0 else {
            return fullSize()
        }

        let scale = maxPixelWidth / sourceWidth
        let targetWidth = Int(sourceWidth * scale)
        let targetHeight = max(1, Int(sourceHeight * scale))

        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return fullSize()
        }

        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let scaled = context.makeImage() else {
            return fullSize()
        }

        return NSImage(cgImage: scaled, size: NSSize(width: targetWidth, height: targetHeight))
    }

    // MARK: - App Icons

    /// The preview stand-in when captures are unavailable or the user prefers icons.
    static func appIcon(for window: WindowInfo) -> NSImage? {
        if let icon = window.appIcon {
            return icon
        }

        if let icon = NSRunningApplication(processIdentifier: window.ownerPID)?.icon {
            return icon
        }

        return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: "App")
    }
}
