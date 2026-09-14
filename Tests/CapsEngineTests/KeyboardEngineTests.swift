import AppKit
import CapsCore
import XCTest
@testable import CapsBye

final class KeyboardEngineTests: XCTestCase {
    func testQuartzChordBeforeHIDCallbackStillReceivesHyper() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time },
                                    modifierSnapshot: { [] }, capsSnapshot: { [1] })
        engine.updateDevices(physical: [2], virtual: [1])
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        key.flags = []
        // The cached device value is down, but its HID callback is still queued.
        _ = engine.process(type: .keyDown, event: key)
        XCTAssertEqual(key.flags, Modifiers.hyper.cgFlags)
        engine.receiveCaps(deviceID: 1, isDown: true)
        time = 0.05
        engine.receiveCaps(deviceID: 1, isDown: false)
        XCTAssertEqual(sent.filter { $0.type == .flagsChanged }.count, 8)
        XCTAssertEqual(sent.last?.flags, [])
        XCTAssertFalse(sent.contains { $0.type == .keyDown })
    }

    func testReadablePhysicalAndVirtualInputsBothWork() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updateDevices(physical: [2], virtual: [1])
        for id: UInt64 in [1, 2, 1, 2] {
            engine.receiveCaps(deviceID: id, isDown: true)
            time += 0.05
            engine.receiveCaps(deviceID: id, isDown: false)
            time += 0.05
        }
        XCTAssertEqual(sent.filter { $0.type == .keyDown }.count, 4)
    }

    func testOverlappingCapsSourcesEmitOneTap() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updateDevices(physical: [2], virtual: [1])
        engine.receiveCaps(deviceID: 2, isDown: true)
        engine.receiveCaps(deviceID: 1, isDown: true)
        time = 0.05
        engine.receiveCaps(deviceID: 2, isDown: false)
        XCTAssertTrue(sent.isEmpty)
        engine.receiveCaps(deviceID: 1, isDown: false)
        XCTAssertEqual(sent.filter { $0.type == .keyDown }.count, 1)
    }

    func testDisconnectReleasesOnlyWhenLastHeldSourceIsGone() {
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, modifierSnapshot: { [] })
        engine.updateDevices(physical: [2, 3], virtual: [1])
        engine.receiveCaps(deviceID: 1, isDown: true)
        engine.receiveCaps(deviceID: 2, isDown: true)
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        _ = engine.process(type: .keyDown, event: key)
        let beforeRemoval = sent.count
        engine.updateDevices(physical: [2], virtual: [])
        XCTAssertEqual(sent.count, beforeRemoval)
        engine.updateDevices(physical: [], virtual: [])
        XCTAssertEqual(sent.filter { $0.type == .flagsChanged }.count, 8)
        XCTAssertEqual(sent.last?.flags, [])
        XCTAssertFalse(sent.contains { $0.type == .keyDown })
    }

    func testDisconnectedPendingPressAndLateCallbacksDoNotEmitEscape() {
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, modifierSnapshot: { [] })
        engine.updateDevices(physical: [], virtual: [1])
        engine.receiveCaps(deviceID: 1, isDown: true)
        engine.updateDevices(physical: [2], virtual: [])
        engine.receiveCaps(deviceID: 1, isDown: false)
        engine.receiveCaps(deviceID: 1, isDown: true)
        engine.receiveCaps(deviceID: 1, isDown: false)
        XCTAssertTrue(sent.isEmpty)
    }

    func testMouseKeyboardInterfaceDoesNotHideVirtualCapsInput() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        // Captured setup: Q11 is seized, Karabiner forwards Caps, and the
        // MX Master 3 advertises an accessible keyboard interface of its own.
        let karabiner: UInt64 = 4295021274
        let mouse: UInt64 = 4295534939
        engine.updateDevices(physical: [mouse], virtual: [karabiner])
        for _ in 0..<3 {
            engine.receiveCaps(deviceID: karabiner, isDown: true)
            time += 0.05
            engine.receiveCaps(deviceID: karabiner, isDown: false)
            time += 0.05
        }
        XCTAssertEqual(sent.filter { $0.type == .keyDown }.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [53, 53, 53], "A mouse keyboard interface must not make Caps permanently silent")
    }

    func testMouseReconnectDoesNotCancelVirtualHyperHold() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updateDevices(physical: [], virtual: [1])
        engine.receiveCaps(deviceID: 1, isDown: true)
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        key.flags = []
        _ = engine.process(type: .keyDown, event: key)
        let beforeReconnect = sent.count
        engine.updateDevices(physical: [2], virtual: [1])
        XCTAssertEqual(sent.count, beforeReconnect, "Adding a mouse must not release a hold on another device")
        let secondKey = CGEvent(keyboardEventSource: nil, virtualKey: 1, keyDown: true)!
        secondKey.flags = []
        _ = engine.process(type: .keyDown, event: secondKey)
        XCTAssertEqual(secondKey.flags, Modifiers.hyper.cgFlags)
        time = 0.1
        engine.receiveCaps(deviceID: 1, isDown: false)
        XCTAssertEqual(sent.last?.flags, [])
        XCTAssertFalse(sent.contains { $0.type == .keyDown })
    }

    func testCapsLockStateResetDoesNotTurnQuickTapIntoHyper() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updatePress(isDown: true)
        // Clearing the lock can generate a flagsChanged notification without
        // a physical modifier key. This is not a chord with another key.
        let reset = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
        reset.type = .flagsChanged
        reset.flags = []
        _ = engine.process(type: .flagsChanged, event: reset)
        time = 0.07
        engine.updatePress(isDown: false)
        XCTAssertEqual(sent.filter { $0.type == .keyDown }.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [53])
        XCTAssertFalse(sent.contains { $0.flags.contains(.maskCommand) }, "A quick tap must never emit Hyper")
    }

    func testReleasingAnExistingModifierDoesNotTurnTapIntoHold() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updatePress(isDown: true)
        let release = CGEvent(keyboardEventSource: nil, virtualKey: 55, keyDown: false)!
        release.type = .flagsChanged
        release.flags = []
        _ = engine.process(type: .flagsChanged, event: release)
        time = 0.07
        engine.updatePress(isDown: false)
        XCTAssertEqual(sent.filter { $0.type == .keyDown }.map { $0.getIntegerValueField(.keyboardEventKeycode) }, [53])
    }

    func testChordAddsHyperAndReleasesEverySyntheticModifier() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updatePress(isDown: true)
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        key.flags = []
        _ = engine.process(type: .keyDown, event: key)
        XCTAssertEqual(key.flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]), Modifiers.hyper.cgFlags)
        time = 0.1
        engine.updatePress(isDown: false)
        XCTAssertEqual(sent.filter { $0.type == .flagsChanged }.count, 8)
        XCTAssertEqual(sent.last?.flags, [])
        XCTAssertFalse(sent.contains { $0.type == .keyDown && $0.getIntegerValueField(.keyboardEventKeycode) == 53 })
    }

    func testHeldPhysicalShiftSurvivesSyntheticHyperRelease() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { .shift })
        engine.updatePress(isDown: true)
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        key.flags = .maskShift
        _ = engine.process(type: .keyDown, event: key)
        time = 0.1
        engine.updatePress(isDown: false)
        XCTAssertEqual(sent.last?.flags, .maskShift)
        XCTAssertFalse(sent.contains { $0.getIntegerValueField(.keyboardEventKeycode) == 56 }, "Never synthesize a release for the user's held Shift")
    }

    func testOwnModifierEventsCannotCreateASecondChord() {
        var time = 0.0
        var sent: [CGEvent] = []
        let engine = KeyboardEngine(eventSink: { event, _ in sent.append(event.copy()!) }, now: { time }, modifierSnapshot: { [] })
        engine.updatePress(isDown: true)
        let key = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        _ = engine.process(type: .keyDown, event: key)
        let ownEvents = sent
        for event in ownEvents { _ = engine.process(type: event.type, event: event) }
        XCTAssertEqual(sent.count, ownEvents.count)
        time = 0.1
        engine.updatePress(isDown: false)
        XCTAssertEqual(sent.last?.flags, [])
    }
}
