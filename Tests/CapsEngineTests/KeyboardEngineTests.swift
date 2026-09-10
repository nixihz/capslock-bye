import AppKit
import CapsCore
import XCTest
@testable import CapsBye

final class KeyboardEngineTests: XCTestCase {
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
