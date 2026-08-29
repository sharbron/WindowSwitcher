import Cocoa
import Carbon
import os.log

class KeyboardMonitor: ObservableObject {
    // Accessed from both the event tap thread and main thread — always guarded by stateLock
    private var _isShowingSwitcher = false
    var isShowingSwitcher: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isShowingSwitcher
        }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _isShowingSwitcher = newValue
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var tabKeyWasPressed = false
    private let logger = Logger(subsystem: "com.windowswitcher", category: "KeyboardMonitor")
    private let stateLock = NSLock()

    // Key codes
    private static let tabKey: Int64 = 48
    private static let escapeKey: Int64 = 53
    private static let backspaceKey: Int64 = 51

    /// Cmd+1 through Cmd+9 mapped to zero-based window indices.
    private static let numberKeyMap: [Int64: Int] = [
        18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8
    ]

    var onCmdTabPressed: (() -> Void)?
    var onTabPressed: (() -> Void)?
    var onCmdReleased: (() -> Void)?
    var onShiftTabPressed: (() -> Void)?
    var onEscapePressed: (() -> Void)?
    var onCharacterTyped: ((String) -> Void)?
    var onBackspacePressed: (() -> Void)?
    var onNumberPressed: ((Int) -> Void)?

    /// Starts intercepting keyboard events.
    ///
    /// Must be called from the main thread — the run loop source is attached to the current
    /// run loop, and `stopMonitoring()` detaches it from the main one.
    /// - Returns: `false` if the tap could not be created, which in practice means
    ///   Accessibility permission has not been granted yet.
    @discardableResult
    func startMonitoring() -> Bool {
        // Include the tap-disabled events so a disabled tap can be revived. macOS silently
        // disables a tap whose callback overruns its time budget; without this the app stops
        // responding to Cmd+Tab for the rest of the session.
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.tapDisabledByTimeout.rawValue) |
                        (1 << CGEventType.tapDisabledByUserInput.rawValue)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            logger.error("Failed to create event tap. Check Accessibility permissions.")
            return false
        }

        stateLock.lock()
        self.eventTap = eventTap
        stateLock.unlock()

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        logger.info("Keyboard monitoring started successfully")
        return true
    }

    func stopMonitoring() {
        logger.info("Stopping keyboard monitoring")

        stateLock.lock()
        let tap = eventTap
        eventTap = nil
        stateLock.unlock()

        if let tap = tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            // Use CFRunLoopGetMain() — the source was added to the main run loop in startMonitoring()
            // Using CFRunLoopGetCurrent() here would fail if called from a non-main thread (e.g. deinit)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let tap = tap {
            CFMachPortInvalidate(tap)
        }
        runLoopSource = nil
    }

    // MARK: - Event Handling

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            reenableTap(reason: type)
            return nil
        case .flagsChanged:
            return handleFlagsChanged(event: event)
        case .keyDown:
            return handleKeyDown(event: event)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    /// The system disables an event tap if its callback is too slow, or on certain user input.
    /// Re-enabling restores Cmd+Tab instead of leaving the app permanently deaf.
    private func reenableTap(reason: CGEventType) {
        stateLock.lock()
        let tap = eventTap
        stateLock.unlock()

        guard let tap = tap else { return }
        logger.warning("Event tap was disabled (reason: \(reason.rawValue)); re-enabling")
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleFlagsChanged(event: CGEvent) -> Unmanaged<CGEvent>? {
        let cmdPressed = event.flags.contains(.maskCommand)

        // Treat any loss of Cmd after a Tab press as the commit gesture. Tracking a separate
        // "cmd is down" flag meant a missed key-down event left the switcher stuck open with
        // no way to dismiss it.
        stateLock.lock()
        let shouldRelease = !cmdPressed && tabKeyWasPressed
        if shouldRelease {
            tabKeyWasPressed = false
        }
        stateLock.unlock()

        if shouldRelease {
            DispatchQueue.main.async {
                self.onCmdReleased?()
            }
            return nil // Consume the event
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleKeyDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let hasCommand = flags.contains(.maskCommand)

        if keyCode == Self.tabKey && hasCommand {
            return handleCmdTab(hasShift: flags.contains(.maskShift))
        }

        let switcherShowing = isShowingSwitcher

        if keyCode == Self.escapeKey && switcherShowing {
            stateLock.lock()
            tabKeyWasPressed = false
            _isShowingSwitcher = false
            stateLock.unlock()

            DispatchQueue.main.async {
                self.onEscapePressed?()
            }
            return nil // Consume the event
        }

        guard switcherShowing else {
            return Unmanaged.passUnretained(event)
        }

        if keyCode == Self.backspaceKey && !hasCommand {
            DispatchQueue.main.async {
                self.onBackspacePressed?()
            }
            return nil // Consume the event
        }

        if hasCommand, let windowIndex = Self.numberKeyMap[keyCode] {
            DispatchQueue.main.async {
                self.onNumberPressed?(windowIndex)
            }
            return nil // Consume the event
        }

        if !hasCommand, let typed = searchableCharacters(from: event) {
            DispatchQueue.main.async {
                self.onCharacterTyped?(typed)
            }
            return nil // Consume the event
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleCmdTab(hasShift: Bool) -> Unmanaged<CGEvent>? {
        // Flip the "showing" flag here on the tap thread rather than waiting for the main
        // queue to run showSwitcher(). A fast Cmd+Tab+Tab would otherwise see a stale `false`
        // on the second press, route it to onCmdTabPressed, and get swallowed by the
        // already-showing guard — silently dropping the user's advance.
        stateLock.lock()
        tabKeyWasPressed = true
        let wasShowing = _isShowingSwitcher
        _isShowingSwitcher = true
        stateLock.unlock()

        logger.info("Cmd+Tab detected. wasShowing=\(wasShowing), hasShift=\(hasShift)")

        DispatchQueue.main.async {
            if hasShift {
                self.onShiftTabPressed?()
            } else if wasShowing {
                self.onTabPressed?()
            } else {
                self.onCmdTabPressed?()
            }
        }

        return nil // Consume the event to prevent default behavior
    }

    /// Extracts the typed characters usable as a search query, or nil if there are none.
    private func searchableCharacters(from event: CGEvent) -> String? {
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)

        guard length > 0 else { return nil }

        var chars = [UniChar](repeating: 0, count: length)
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &length,
            unicodeString: &chars
        )
        let string = String(utf16CodeUnits: chars, count: length)

        // Filter out control characters
        let filtered = string.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
        return filtered.isEmpty ? nil : String(filtered)
    }

    deinit {
        stopMonitoring()
    }
}
