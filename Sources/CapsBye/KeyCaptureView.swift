import AppKit
import CapsCore
import SwiftUI

struct KeyCaptureView: NSViewRepresentable {
    var onKey: (TapShortcut, Bool) -> Void
    var onModifiers: (Modifiers, Bool) -> Void = { _, _ in }

    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKey = onKey
        view.onModifiers = onModifiers
        return view
    }
    func updateNSView(_ view: KeyCaptureNSView, context: Context) {
        view.onKey = onKey
        view.onModifiers = onModifiers
    }
}

final class KeyCaptureNSView: NSView {
    var onKey: ((TapShortcut, Bool) -> Void)?
    var onModifiers: ((Modifiers, Bool) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }
    override func mouseDown(with event: NSEvent) { window?.makeFirstResponder(self) }
    override func keyDown(with event: NSEvent) { capture(event) }
    override func keyUp(with event: NSEvent) {}
    override func flagsChanged(with event: NSEvent) { onModifiers?(Modifiers(eventFlags: event.modifierFlags), isOwn(event)) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard window?.firstResponder === self else { return false }
        capture(event)
        return true
    }
    private func capture(_ event: NSEvent) {
        guard event.type == .keyDown, !event.isARepeat, event.keyCode != 57 else { return }
        let labels: [UInt16: String] = [53: "Esc", 48: "Tab", 36: "↩", 76: "⌤", 51: "⌫", 117: "⌦", 49: "Space",
            123: "←", 124: "→", 125: "↓", 126: "↑", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
            122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
            105: "F13", 107: "F14", 113: "F15", 106: "F16", 64: "F17", 79: "F18", 80: "F19", 90: "F20"]
        let label = labels[event.keyCode] ?? event.charactersIgnoringModifiers?.uppercased() ?? "Key \(event.keyCode)"
        guard !label.isEmpty else { return }
        onKey?(.init(keyCode: event.keyCode, label: label, modifiers: Modifiers(eventFlags: event.modifierFlags)), isOwn(event))
    }

    private func isOwn(_ event: NSEvent) -> Bool {
        event.cgEvent?.getIntegerValueField(.eventSourceUserData) == KeyboardEngine.eventTag
    }
}

struct ShortcutRecorderSheet: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var shortcut: TapShortcut?

    var body: some View {
        VStack(spacing: 18) {
            Text(model.t("按下你的快捷键", "Press your shortcut"))
                .font(.system(size: 21, weight: .semibold, design: .rounded))
            Text(model.t("支持单键或组合键，例如 ⌘K。", "Use a single key or a combination, like ⌘K."))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Text(shortcut?.display ?? model.t("等待按键…", "Listening…"))
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity).frame(height: 100)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 16))
                .overlay(KeyCaptureView(onKey: { key, _ in shortcut = key }))
                .accessibilityLabel(model.t("快捷键录制区", "Shortcut recorder"))
            HStack {
                Button(model.t("取消", "Cancel")) { dismiss() }
                Spacer()
                Button(model.t("使用此快捷键", "Use shortcut")) {
                    if let shortcut { model.mapping.tap = shortcut }
                    dismiss()
                }.buttonStyle(.borderedProminent).tint(.accentColor).disabled(shortcut == nil)
            }
        }.padding(28).frame(width: 390)
        .onAppear { model.recording = true }
        .onDisappear { model.recording = false }
    }
}

struct KeyboardTestView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var lastKey: String?
    @State private var modifiers: Modifiers = []
    @State private var lastHeld: Modifiers = []
    @State private var keyFromCapsBye = false
    @State private var holdFromCapsBye = false

    private var result: String { lastKey ?? (modifiers.isEmpty ? (lastHeld.isEmpty ? "—" : lastHeld.symbols) : modifiers.symbols) }
    private var hasResult: Bool { lastKey != nil || !lastHeld.isEmpty }
    private var fromCapsBye: Bool { lastKey == nil ? holdFromCapsBye : keyFromCapsBye }
    private var feedback: String {
        if !hasResult { return model.t("轻点 Caps，应该看到 Esc。", "Tap Caps. You should see Esc.") }
        if !fromCapsBye && model.awaitingCaps { return model.t("收到其他工具的输入，CapsLock Bye 尚未接管。", "Received another app’s input. CapsLock Bye hasn’t taken over.") }
        if fromCapsBye { return modifiers.isEmpty ? model.t("CapsLock Bye 已触发 · 按键已松开", "CapsLock Bye triggered · Keys released") : model.t("CapsLock Bye · 修饰键按住中", "CapsLock Bye · Modifiers held") }
        return model.t("系统输入", "System input")
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text(model.t("测试按键", "Test keys"))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel(model.t("关闭", "Close"))
            }
            Text(result)
                .font(.system(size: 32, weight: .regular)).lineLimit(1).minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity).frame(height: 105)
                .background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                .overlay(KeyCaptureView(onKey: { key, own in
                    lastKey = key.display
                    keyFromCapsBye = own
                }, onModifiers: { next, own in
                    if modifiers.isEmpty && !next.isEmpty { lastKey = nil; lastHeld = [] }
                    modifiers = next
                    if !next.isEmpty { lastHeld.formUnion(next); holdFromCapsBye = own }
                }))
                .accessibilityLabel(model.t("按键测试区", "Keyboard test area"))
                .accessibilityValue(result)
            Text(feedback).font(.system(size: 11))
                .foregroundStyle(hasResult && !fromCapsBye && model.awaitingCaps ? Color.orange : Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(model.t("按住 Caps + 字母，测试组合键。", "Hold Caps + a letter to test a chord."))
                .font(.system(size: 10)).foregroundStyle(.tertiary)
        }.padding(24).frame(width: 360)
        .focusEffectDisabled()
    }
}
