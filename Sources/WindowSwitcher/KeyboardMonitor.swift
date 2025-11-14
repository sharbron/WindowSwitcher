import Cocoa
import Carbon
import os.log

class KeyboardMonitor: ObservableObject {
    @Published var isShowingSwitcher = false
    @Published var selectedIndex = 0

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var cmdKeyIsDown = false
    private var tabKeyWasPressed = false
    private let logger = Logger(subsystem: "com.windowswitcher", category: "KeyboardMonitor")
    private let stateLock = NSLock()

    var onCmdTabPressed: (() -> Void)?
    var onTabPressed: (() -> Void)?
    var onCmdReleased: (() -> Void)?
    var onShiftTabPressed: (() -> Void)?
    var onEscapePressed: (() -> Void)?
    var onCharacterTyped: ((String) -> Void)?
    var onBackspacePressed: (() -> Void)?
    var onNumberPressed: ((Int) -> Void)?

    func startMonitoring() {
        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue)

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
            return
        }

        self.eventTap = eventTap

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        logger.info("Keyboard monitoring started successfully")
    }

    func stopMonitoring() {
        logger.info("Stopping keyboard monitoring")
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Handle flags changed (for Cmd key)
        if type == .flagsChanged {
            let flags = event.flags
            let cmdPressed = flags.contains(.maskCommand)

            stateLock.lock()
            let shouldRelease = cmdKeyIsDown && !cmdPressed && tabKeyWasPressed
            if shouldRelease {
                cmdKeyIsDown = false
                tabKeyWasPressed = false
            } else {
                cmdKeyIsDown = cmdPressed
            }
            stateLock.unlock()

            // Cmd key was released
            if shouldRelease {
                DispatchQueue.main.async {
                    self.onCmdReleased?()
                }
                return nil // Consume the event
            }
        }

        // Handle key down events
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Tab key (keycode 48)
            if keyCode == 48 && flags.contains(.maskCommand) {
                stateLock.lock()
                tabKeyWasPressed = true
                stateLock.unlock()

                DispatchQueue.main.async {
                    if flags.contains(.maskShift) {
                        self.onShiftTabPressed?()
                    } else {
                        if !self.isShowingSwitcher {
                            self.onCmdTabPressed?()
                        } else {
                            self.onTabPressed?()
                        }
                    }
                }

                return nil // Consume the event to prevent default behavior
            }

            // Escape key (keycode 53) - dismiss switcher if showing
            if keyCode == 53 && isShowingSwitcher {
                stateLock.lock()
                cmdKeyIsDown = false
                tabKeyWasPressed = false
                stateLock.unlock()

                DispatchQueue.main.async {
                    self.onEscapePressed?()
                }

                return nil // Consume the event
            }

            // Backspace key (keycode 51) - handle search backspace
            if keyCode == 51 && isShowingSwitcher && !flags.contains(.maskCommand) {
                DispatchQueue.main.async {
                    self.onBackspacePressed?()
                }

                return nil // Consume the event
            }

            // Number keys (Cmd+1 through Cmd+9) for direct window access
            // Keycodes: 18=1, 19=2, 20=3, 21=4, 23=5, 22=6, 26=7, 28=8, 25=9
            if isShowingSwitcher && flags.contains(.maskCommand) {
                let numberKeyMap: [Int64: Int] = [
                    18: 0, // Cmd+1 -> index 0
                    19: 1, // Cmd+2 -> index 1
                    20: 2, // Cmd+3 -> index 2
                    21: 3, // Cmd+4 -> index 3
                    23: 4, // Cmd+5 -> index 4
                    22: 5, // Cmd+6 -> index 5
                    26: 6, // Cmd+7 -> index 6
                    28: 7, // Cmd+8 -> index 7
                    25: 8  // Cmd+9 -> index 8
                ]

                if let windowIndex = numberKeyMap[keyCode] {
                    DispatchQueue.main.async {
                        self.onNumberPressed?(windowIndex)
                    }

                    return nil // Consume the event
                }
            }

            // Character typing for search (when switcher is showing, no Cmd key)
            if isShowingSwitcher && !flags.contains(.maskCommand) {
                // Get Unicode string from keyboard event
                var length = 0
                event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: nil)

                if length > 0 {
                    var chars = [UniChar](repeating: 0, count: length)
                    event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)
                    let string = String(utf16CodeUnits: chars, count: length)

                    // Filter out control characters
                    let filtered = string.filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
                    if !filtered.isEmpty {
                        DispatchQueue.main.async {
                            self.onCharacterTyped?(String(filtered))
                        }

                        return nil // Consume the event
                    }
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        stopMonitoring()
    }
}
