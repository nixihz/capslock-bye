import Foundation

/// The physical Caps key is momentary here; its macOS lock flag is never used
/// to infer key-up. Configuration is captured for the duration of a press.
public struct RemapMachine {
    public enum Effect: Equatable {
        case holdBegan(Modifiers)
        case holdEnded(Modifiers)
        case tapped(TapShortcut)
    }

    private enum State {
        case idle
        case pending(since: TimeInterval, mapping: Mapping)
        case holding(Mapping)
    }
    private var state: State = .idle
    public init() {}

    public var isPressed: Bool {
        if case .idle = state { return false }
        return true
    }

    public var activeModifiers: Modifiers {
        if case .holding(let mapping) = state { return mapping.hold }
        return []
    }

    public mutating func press(at time: TimeInterval, mapping: Mapping) {
        guard !isPressed else { return }
        state = .pending(since: time, mapping: mapping.validated)
    }

    public mutating func tick(at time: TimeInterval) -> [Effect] {
        guard case .pending(let since, let mapping) = state,
              time - since >= mapping.holdDelay else { return [] }
        return beginHold(mapping)
    }

    public mutating func chord() -> [Effect] {
        guard case .pending(_, let mapping) = state else { return [] }
        return beginHold(mapping)
    }

    public mutating func release(at time: TimeInterval) -> [Effect] {
        let previous = state
        state = .idle
        switch previous {
        case .idle: return []
        case .holding(let mapping): return [.holdEnded(mapping.hold)]
        case .pending(let since, let mapping):
            // A delayed timer must never turn a long press into Escape.
            return time - since < mapping.holdDelay ? [.tapped(mapping.tap)] : []
        }
    }

    public mutating func cancel() -> [Effect] {
        defer { state = .idle }
        guard case .holding(let mapping) = state else { return [] }
        return [.holdEnded(mapping.hold)]
    }

    private mutating func beginHold(_ mapping: Mapping) -> [Effect] {
        state = .holding(mapping)
        return [.holdBegan(mapping.hold)]
    }
}
