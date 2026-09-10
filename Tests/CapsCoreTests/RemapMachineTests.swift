import XCTest
@testable import CapsCore

final class RemapMachineTests: XCTestCase {
    func testQuickTapSendsExactlyOneEscape() {
        var machine = RemapMachine()
        machine.press(at: 1, mapping: Mapping())
        XCTAssertEqual(machine.release(at: 1.08), [.tapped(.escape)])
        XCTAssertEqual(machine.release(at: 1.09), [])
    }

    func testChordActivatesImmediatelyAndNeverSendsEscape() {
        var machine = RemapMachine()
        machine.press(at: 1, mapping: Mapping())
        XCTAssertEqual(machine.chord(), [.holdBegan(.hyper)])
        XCTAssertEqual(machine.activeModifiers, .hyper)
        XCTAssertEqual(machine.chord(), [])
        XCTAssertEqual(machine.release(at: 1.02), [.holdEnded(.hyper)])
        XCTAssertEqual(machine.activeModifiers, [])
    }

    func testLongHoldAndRelease() {
        var machine = RemapMachine()
        machine.press(at: 1, mapping: Mapping())
        XCTAssertEqual(machine.tick(at: 1.1), [])
        XCTAssertEqual(machine.tick(at: 1.2), [.holdBegan(.hyper)])
        XCTAssertEqual(machine.tick(at: 1.3), [])
        XCTAssertEqual(machine.release(at: 2), [.holdEnded(.hyper)])
    }

    func testDelayedTimerDoesNotProduceEscape() {
        var machine = RemapMachine()
        machine.press(at: 0, mapping: Mapping())
        XCTAssertEqual(machine.release(at: 2), [])
    }

    func testCancellationOnSleepOrDisableReleasesModifiersWithoutTap() {
        var machine = RemapMachine()
        machine.press(at: 0, mapping: Mapping())
        XCTAssertEqual(machine.cancel(), [])
        machine.press(at: 1, mapping: Mapping())
        _ = machine.chord()
        XCTAssertEqual(machine.cancel(), [.holdEnded(.hyper)])
        XCTAssertEqual(machine.release(at: 2), [])
        XCTAssertEqual(machine.cancel(), [])
    }

    func testCustomMappingAndRepeatedDownPreserveOriginalPress() {
        var machine = RemapMachine()
        let shortcut = TapShortcut(keyCode: 8, label: "C", modifiers: .command)
        let mapping = Mapping(tap: shortcut, hold: [.control, .option], holdDelay: 0.3)
        machine.press(at: 1, mapping: mapping)
        machine.press(at: 1.1, mapping: Mapping())
        XCTAssertEqual(machine.release(at: 1.2), [.tapped(shortcut)])
        machine.press(at: 2, mapping: mapping)
        XCTAssertEqual(machine.chord(), [.holdBegan([.control, .option])])
        XCTAssertEqual(machine.release(at: 2.1), [.holdEnded([.control, .option])])
    }

    func testRapidTapsAndBoundary() {
        var machine = RemapMachine()
        for i in 0..<100 {
            machine.press(at: Double(i), mapping: Mapping())
            XCTAssertEqual(machine.release(at: Double(i) + 0.05), [.tapped(.escape)])
        }
        machine.press(at: 0, mapping: Mapping(holdDelay: 0.2))
        XCTAssertEqual(machine.release(at: 0.2), [])
    }

    func testInvalidSavedSettingsAreSanitized() throws {
        let mapping = Mapping(tap: .init(keyCode: 57, label: "Caps"), hold: .init(rawValue: 255), holdDelay: 50).validated
        XCTAssertEqual(mapping.tap, .escape)
        XCTAssertEqual(mapping.hold, .hyper)
        XCTAssertEqual(mapping.holdDelay, 0.4)
        XCTAssertEqual(try JSONDecoder().decode(Mapping.self, from: JSONEncoder().encode(mapping)), mapping)
    }
}
