import AppKit
import CapsCore
import IOKit.hid
import IOKit.hidsystem
import OSLog

/// All callbacks are scheduled on the main run loop. Only Caps Lock HID values
/// are requested. No keyboard remapping property, driver, or global preference
/// is installed: closing the event tap restores normal keyboard behavior.
final class KeyboardEngine {
    enum Failure: Error, Equatable { case eventTap, inputMonitoring, capsLockControl, keyboardUnavailable }
    enum Activity { case pressed, tapped(String), holding, released }

    var mapping = Mapping()
    var onActivity: ((Activity) -> Void)?
    var onInterruption: (() -> Void)?
    private(set) var isRunning = false
    private(set) var usingVirtualKeyboard = false
    private(set) var hasReceivedCaps = false
    private var machine = RemapMachine()
    private var tap: CFMachPort?
    private var tapSource: CFRunLoopSource?
    private var manager: IOHIDManager?
    private struct Keyboard {
        let device: IOHIDDevice
        let elements: [IOHIDElement]
        let modifiers: [IOHIDElement]
        let virtual: Bool
    }
    private var keyboards: [UInt64: Keyboard] = [:]
    private var selectedDevices: Set<UInt64> = []
    private var capsElements: [IOHIDElement] = []
    private var modifierElements: [IOHIDElement] = []
    private var downDevices: Set<UInt64> = []
    private var holdTimer: Timer?
    private var hidConnection: io_connect_t = 0
    private var emittedModifiers: Modifiers = []
    private let eventSource = CGEventSource(stateID: .privateState)
    static let eventTag: Int64 = 0x43415053425945
    private let logger = Logger(subsystem: "tech.keli.capslock-bye", category: "Keyboard")
    private let eventSink: ((CGEvent, CGEventTapProxy?) -> Void)?
    private let now: () -> TimeInterval
    private let modifierSnapshot: (() -> Modifiers)?

    init(eventSink: ((CGEvent, CGEventTapProxy?) -> Void)? = nil,
         now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         modifierSnapshot: (() -> Modifiers)? = nil) {
        self.eventSink = eventSink
        self.now = now
        self.modifierSnapshot = modifierSnapshot
    }

    func start() throws {
        guard !isRunning else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        let mask: CGEventMask = [CGEventType.keyDown, .keyUp, .flagsChanged,
            .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp,
            .otherMouseDown, .otherMouseUp, .leftMouseDragged, .rightMouseDragged,
            .otherMouseDragged, .scrollWheel].reduce(0) { $0 | (1 << $1.rawValue) }
        guard let eventTap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask, callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<KeyboardEngine>.fromOpaque(context).takeUnretainedValue()
                    .handle(proxy: proxy, type: type, event: event)
            }, userInfo: context) else { throw Failure.eventTap }
        tap = eventTap

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(kIOHIDSystemClass))
        if service != 0 {
            let result = IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &hidConnection)
            IOObjectRelease(service)
            if result != KERN_SUCCESS { hidConnection = 0 }
        }
        guard hidConnection != 0 else { stop(); throw Failure.capsLockControl }

        // Independent devices let us ignore a seized physical keyboard while
        // still listening to another available (including virtual) keyboard.
        let hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
        manager = hidManager
        IOHIDManagerSetDeviceMatching(hidManager, [
            kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard
        ] as CFDictionary)
        IOHIDManagerRegisterDeviceMatchingCallback(hidManager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<KeyboardEngine>.fromOpaque(context).takeUnretainedValue().connect(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(hidManager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<KeyboardEngine>.fromOpaque(context).takeUnretainedValue().disconnect(device)
        }, context)
        IOHIDManagerScheduleWithRunLoop(hidManager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let openResult = IOHIDManagerOpen(hidManager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            logger.error("Could not open HID manager: \(openResult, privacy: .public)")
            stop()
            throw openResult == kIOReturnNotPermitted ? Failure.inputMonitoring : Failure.keyboardUnavailable
        }
        for device in (IOHIDManagerCopyDevices(hidManager) as? Set<IOHIDDevice>) ?? [] { connect(device) }
        guard !capsElements.isEmpty else {
            stop()
            throw IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted ? Failure.keyboardUnavailable : Failure.inputMonitoring
        }

        tapSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), tapSource, .commonModes)
        isRunning = true
        clearCapsLock()
        CGEvent.tapEnable(tap: eventTap, enable: true)
        logger.info("Keyboard mapping started with \(self.capsElements.count, privacy: .public) Caps elements")
    }

    func stop() {
        cancelPress()
        isRunning = false
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let tapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), tapSource, .commonModes) }
        tap = nil
        tapSource = nil
        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        manager = nil
        for keyboard in keyboards.values {
            IOHIDDeviceUnscheduleFromRunLoop(keyboard.device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
            IOHIDDeviceClose(keyboard.device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        keyboards.removeAll()
        selectedDevices.removeAll()
        usingVirtualKeyboard = false
        hasReceivedCaps = false
        capsElements = []
        modifierElements = []
        clearCapsLock()
        if hidConnection != 0 { IOServiceClose(hidConnection); hidConnection = 0 }
    }

    private func connect(_ device: IOHIDDevice) {
        guard manager != nil, keyboards[deviceID(device)] == nil else { return }
        let matching = [kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad,
                        kIOHIDElementUsageKey: kHIDUsage_KeyboardCapsLock] as CFDictionary
        let elements = (IOHIDDeviceCopyMatchingElements(device, matching, IOOptionBits(kIOHIDOptionsTypeNone)) as? [IOHIDElement]) ?? []
        guard !elements.isEmpty else { return }
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            logger.notice("Skipping unavailable keyboard: \(result, privacy: .public)")
            return
        }
        IOHIDDeviceSetInputValueMatching(device, matching)
        IOHIDDeviceRegisterInputValueCallback(device, { context, result, _, value in
            guard result == kIOReturnSuccess, let context else { return }
            Unmanaged<KeyboardEngine>.fromOpaque(context).takeUnretainedValue().receive(value)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let product = (IOHIDDeviceGetProperty(device, kIOHIDProductKey as CFString) as? String) ?? ""
        let virtual = product.localizedCaseInsensitiveContains("virtual")
        let keys = (IOHIDDeviceCopyMatchingElements(device, [kIOHIDElementUsagePageKey: kHIDPage_KeyboardOrKeypad] as CFDictionary, 0) as? [IOHIDElement]) ?? []
        let modifiers = keys.filter { (0xE0...0xE7).contains(IOHIDElementGetUsage($0)) }
        keyboards[deviceID(device)] = Keyboard(device: device, elements: elements, modifiers: modifiers, virtual: virtual)
        selectDevices()
    }

    private func disconnect(_ device: IOHIDDevice) {
        let id = deviceID(device)
        guard let keyboard = keyboards.removeValue(forKey: id) else { return }
        cancelPress()
        IOHIDDeviceUnscheduleFromRunLoop(keyboard.device, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDDeviceClose(keyboard.device, IOOptionBits(kIOHIDOptionsTypeNone))
        selectDevices()
        if isRunning && capsElements.isEmpty {
            DispatchQueue.main.async { [weak self] in self?.onInterruption?() }
        }
    }

    private func selectDevices() {
        // Do not count the same press twice via a real and a virtual keyboard.
        let physical = keyboards.filter { !$0.value.virtual }
        let selected = physical.isEmpty ? keyboards : physical
        let next = Set(selected.keys)
        if next != selectedDevices { cancelPress(); hasReceivedCaps = false }
        selectedDevices = next
        capsElements = selected.values.flatMap(\.elements)
        modifierElements = selected.values.flatMap(\.modifiers)
        usingVirtualKeyboard = physical.isEmpty && !selected.isEmpty
    }

    private func deviceID(_ device: IOHIDDevice) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id)
        return id
    }

    private func receive(_ value: IOHIDValue) {
        guard isRunning else { return }
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == kHIDPage_KeyboardOrKeypad,
              IOHIDElementGetUsage(element) == kHIDUsage_KeyboardCapsLock else { return }
        let device = IOHIDElementGetDevice(element)
        let id = deviceID(device)
        guard selectedDevices.contains(id) else { return }
        if IOHIDValueGetIntegerValue(value) != 0 { downDevices.insert(id) }
        else { downDevices.remove(id) }
        updatePress(isDown: !downDevices.isEmpty)
    }

    /// Sample Caps before a chord as HID and Quartz callbacks can be delivered
    /// in either order. A physical key value, never the sticky alphaShift flag,
    /// is the source of truth.
    private func synchronizeCaps() {
        var pressed: Set<UInt64> = []
        for element in capsElements where isDown(element) {
            pressed.insert(deviceID(IOHIDElementGetDevice(element)))
        }
        // Only advance presses here. Releases stay ordered with their HID
        // callback so a fast rolled chord cannot accidentally produce Escape.
        if !pressed.isEmpty {
            downDevices.formUnion(pressed)
            updatePress(isDown: true)
        }
    }

    func updatePress(isDown: Bool) {
        if isDown {
            guard !machine.isPressed else { return }
            hasReceivedCaps = true
            machine.press(at: now(), mapping: mapping)
            clearCapsLock()
            onActivity?(.pressed)
            holdTimer = Timer(timeInterval: mapping.holdDelay, repeats: false) { [weak self] _ in
                guard let self, self.isRunning else { return }
                self.perform(self.machine.tick(at: self.now()))
            }
            RunLoop.main.add(holdTimer!, forMode: .common)
        } else {
            guard machine.isPressed else { return }
            holdTimer?.invalidate()
            holdTimer = nil
            perform(machine.release(at: now()))
            clearCapsLock()
            onActivity?(.released)
        }
    }

    private func cancelPress() {
        holdTimer?.invalidate()
        holdTimer = nil
        perform(machine.cancel())
        downDevices.removeAll()
        onActivity?(.released)
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cancelPress()
            // Let the owner re-check permissions and rebuild both listeners.
            DispatchQueue.main.async { [weak self] in self?.onInterruption?() }
            return Unmanaged.passUnretained(event)
        }
        guard isRunning else { return Unmanaged.passUnretained(event) }
        return process(type: type, event: event, proxy: proxy)
    }

    /// Shared by the event tap and deterministic event-sequence tests. Tests
    /// replace the output sink; they never post events into the user's session.
    func process(type: CGEventType, event: CGEvent, proxy: CGEventTapProxy? = nil) -> Unmanaged<CGEvent>? {
        guard event.getIntegerValueField(.eventSourceUserData) != Self.eventTag else { return Unmanaged.passUnretained(event) }
        let isKeyboard = type == .keyDown || type == .keyUp || type == .flagsChanged
        if isKeyboard && event.getIntegerValueField(.keyboardEventKeycode) == 57 {
            clearCapsLock()
            return nil
        }
        // Only an actual modifier DOWN is a chord. A lock-state notification
        // (often key code 0), or releasing a modifier, must not consume a tap.
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let modifierDown = type == .flagsChanged && Modifiers.deviceKeyMasks[code].map {
            event.flags.rawValue & $0 != 0
        } == true
        let startsChord = type == .keyDown || modifierDown || type == .leftMouseDown ||
            type == .rightMouseDown || type == .otherMouseDown || type == .scrollWheel
        if startsChord {
            synchronizeCaps()
            // Posting at this tap preserves modifier-before-key ordering.
            perform(machine.chord(), proxy: proxy)
        }
        var flags = event.flags
        flags.remove(.maskAlphaShift)
        flags.formUnion(machine.activeModifiers.cgFlags)
        event.flags = flags
        return Unmanaged.passUnretained(event)
    }

    private func perform(_ effects: [RemapMachine.Effect], proxy: CGEventTapProxy? = nil) {
        for effect in effects {
            switch effect {
            case .holdBegan(let modifiers):
                setModifiers(modifiers, proxy: proxy)
                onActivity?(.holding)
            case .holdEnded:
                setModifiers([], proxy: proxy)
            case .tapped(let shortcut):
                send(shortcut)
                onActivity?(.tapped(shortcut.display))
            }
        }
    }

    private func setModifiers(_ next: Modifiers, proxy: CGEventTapProxy?) {
        let physical = physicalModifiers()
        for (modifier, keyCode) in Modifiers.keyCodes where emittedModifiers.contains(modifier) != next.contains(modifier) {
            if next.contains(modifier) { emittedModifiers.insert(modifier) }
            else { emittedModifiers.remove(modifier) }
            // A synthetic release must never release the user's real modifier.
            if physical.contains(modifier) { continue }
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: keyCode,
                                      keyDown: next.contains(modifier)) else { continue }
            event.type = .flagsChanged
            event.flags = physical.union(emittedModifiers).cgFlags
            post(event, proxy: proxy)
        }
    }

    private func send(_ shortcut: TapShortcut) {
        let physical = physicalModifiers()
        setModifiers(shortcut.modifiers, proxy: nil)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: eventSource, virtualKey: shortcut.keyCode, keyDown: down) else { continue }
            event.flags = physical.union(shortcut.modifiers).cgFlags
            post(event, proxy: nil)
        }
        setModifiers([], proxy: nil)
    }

    private func post(_ event: CGEvent, proxy: CGEventTapProxy?) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.eventTag)
        if let eventSink { eventSink(event, proxy); return }
        if let proxy { event.tapPostEvent(proxy) }
        else { event.post(tap: .cghidEventTap) }
    }

    private func physicalModifiers() -> Modifiers {
        if let modifierSnapshot { return modifierSnapshot() }
        // Read the selected HID devices, not CGEventSource's global state.
        // Global state can include our posted modifiers and then suppress the
        // very key-up events needed to release them.
        var result: Modifiers = []
        for element in modifierElements where isDown(element) {
            if let modifier = Modifiers.hidUsages[IOHIDElementGetUsage(element)] { result.insert(modifier) }
        }
        return result
    }

    private func isDown(_ element: IOHIDElement) -> Bool {
        withUnsafeTemporaryAllocation(of: Unmanaged<IOHIDValue>.self, capacity: 1) { buffer in
            guard IOHIDDeviceGetValue(IOHIDElementGetDevice(element), element, buffer.baseAddress!) == kIOReturnSuccess else { return false }
            return IOHIDValueGetIntegerValue(buffer[0].takeUnretainedValue()) != 0
        }
    }

    private func clearCapsLock() {
        guard hidConnection != 0 else { return }
        var locked = false
        if IOHIDGetModifierLockState(hidConnection, Int32(kIOHIDCapsLockState), &locked) == KERN_SUCCESS, locked {
            IOHIDSetModifierLockState(hidConnection, Int32(kIOHIDCapsLockState), false)
        }
    }
}

extension Modifiers {
    // Device-dependent flags identify left/right modifier down transitions.
    static let deviceKeyMasks: [UInt16: UInt64] = [
        59: UInt64(NX_DEVICELCTLKEYMASK), 62: UInt64(NX_DEVICERCTLKEYMASK),
        56: UInt64(NX_DEVICELSHIFTKEYMASK), 60: UInt64(NX_DEVICERSHIFTKEYMASK),
        55: UInt64(NX_DEVICELCMDKEYMASK), 54: UInt64(NX_DEVICERCMDKEYMASK),
        58: UInt64(NX_DEVICELALTKEYMASK), 61: UInt64(NX_DEVICERALTKEYMASK)
    ]
    static let hidUsages: [UInt32: Modifiers] = [0xE0: .control, 0xE1: .shift, 0xE2: .option, 0xE3: .command,
                                              0xE4: .control, 0xE5: .shift, 0xE6: .option, 0xE7: .command]
    static let keyCodes: [(Modifiers, CGKeyCode)] = [(.command, 55), (.control, 59), (.option, 58), (.shift, 56)]
    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for (modifier, flag) in [(Modifiers.command, CGEventFlags.maskCommand), (.control, .maskControl), (.option, .maskAlternate), (.shift, .maskShift)] {
            if contains(modifier) { flags.insert(flag) }
        }
        return flags
    }
    init(eventFlags: NSEvent.ModifierFlags) {
        self = []
        if eventFlags.contains(.command) { insert(.command) }
        if eventFlags.contains(.control) { insert(.control) }
        if eventFlags.contains(.option) { insert(.option) }
        if eventFlags.contains(.shift) { insert(.shift) }
    }
}
