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
    private var cmdKeyIsDown = false
    private var tabKeyWasPressed = false
    private let logger = Logger(subsystem: "com.windowswitcher", category: "KeyboardMonitor")
    private let stateLock = NSLock()

    var onCmdTabPressed: (() -> Void)?
    var onTabPressed: (() -> Void)?
    var onCmdReleased: (() -> Void)?
    var onShiftTabPressed: (() -> Void)?
    var onEscapePressed: (() -> Void)?

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
            // Use CFRunLoopGetMain() — the source was added to the main run loop in startMonitoring()
            // Using CFRunLoopGetCurrent() here would fail if called from a non-main thread (e.g. deinit)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
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
                let switcherShowing = _isShowingSwitcher
                stateLock.unlock()

                logger.info("Cmd+Tab detected. isShowingSwitcher=\(switcherShowing), hasShift=\(flags.contains(.maskShift))")

                DispatchQueue.main.async {
                    if flags.contains(.maskShift) {
                        self.logger.info("Calling onShiftTabPressed")
                        self.onShiftTabPressed?()
                    } else {
                        if !switcherShowing {
                            self.logger.info("Calling onCmdTabPressed (switcher not showing)")
                            self.onCmdTabPressed?()
                        } else {
                            self.logger.info("Calling onTabPressed (switcher already showing)")
                            self.onTabPressed?()
                        }
                    }
                }

                return nil // Consume the event to prevent default behavior
            }

            // Escape key (keycode 53) - dismiss switcher if showing
            stateLock.lock()
            let switcherShowing = _isShowingSwitcher
            stateLock.unlock()

            if keyCode == 53 && switcherShowing {
                stateLock.lock()
                cmdKeyIsDown = false
                tabKeyWasPressed = false
                stateLock.unlock()

                DispatchQueue.main.async {
                    self.onEscapePressed?()
                }

                return nil // Consume the event
            }
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        stopMonitoring()
    }
}
