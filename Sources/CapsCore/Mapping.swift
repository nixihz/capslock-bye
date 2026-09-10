import Foundation

public struct Modifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let command = Self(rawValue: 1 << 0)
    public static let control = Self(rawValue: 1 << 1)
    public static let option = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
    public static let hyper: Self = [.command, .control, .option, .shift]
    public static let ordered: [(Self, String)] = [(.command, "⌘"), (.control, "⌃"), (.option, "⌥"), (.shift, "⇧")]
    public var symbols: String { Self.ordered.filter { contains($0.0) }.map(\.1).joined() }
}

public struct TapShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var label: String
    public var modifiers: Modifiers

    public init(keyCode: UInt16, label: String, modifiers: Modifiers = []) {
        self.keyCode = keyCode
        self.label = label
        self.modifiers = modifiers
    }

    public static let escape = Self(keyCode: 53, label: "Esc")
    public static let presets: [Self] = [
        .escape, .init(keyCode: 48, label: "Tab"), .init(keyCode: 36, label: "↩"),
        .init(keyCode: 51, label: "⌫"), .init(keyCode: 49, label: "Space")
    ]
    public var display: String { modifiers.symbols + label }
}

public struct Mapping: Codable, Equatable, Sendable {
    public var tap: TapShortcut
    public var hold: Modifiers
    public var holdDelay: Double

    public init(tap: TapShortcut = .escape, hold: Modifiers = .hyper, holdDelay: Double = 0.18) {
        self.tap = tap
        self.hold = hold
        self.holdDelay = holdDelay
    }

    public var validated: Self {
        var result = self
        result.holdDelay = holdDelay.isFinite ? min(0.4, max(0.1, holdDelay)) : 0.18
        result.hold = hold.intersection(.hyper)
        result.tap.modifiers = tap.modifiers.intersection(.hyper)
        if tap.keyCode > 127 || tap.keyCode == 57 || tap.label.isEmpty { result.tap = .escape }
        return result
    }
}
