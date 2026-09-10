import CapsCore
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showRecorder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(model.t("设置", "Settings"))
                        .font(.system(size: 18, weight: .semibold))
                    Text(model.t("设置即时保存，即刻生效。", "Saved automatically. Ready immediately."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)) }
                    .buttonStyle(.plain).accessibilityLabel(model.t("关闭", "Close"))
            }
            VStack(alignment: .leading, spacing: 15) {
                caption(model.t("轻点 CAPS LOCK", "TAP CAPS LOCK"))
                HStack {
                    Menu {
                        ForEach(TapShortcut.presets, id: \.keyCode) { shortcut in
                            Button(shortcut.display) { model.mapping.tap = shortcut }
                        }
                        Divider()
                        Button(model.t("录制快捷键…", "Record shortcut…")) { showRecorder = true }
                    } label: {
                        HStack {
                            Text(model.mapping.tap.display).font(.system(size: 17, weight: .medium, design: .rounded))
                            Spacer()
                        }.padding(.vertical, 4)
                    }.menuStyle(.borderedButton)
                    Button { showRecorder = true } label: { Image(systemName: "record.circle").font(.system(size: 18)) }
                        .buttonStyle(.plain).help(model.t("录制自定义快捷键", "Record a custom shortcut"))
                        .accessibilityLabel(model.t("录制自定义快捷键", "Record a custom shortcut"))
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    caption(model.t("按住 CAPS LOCK", "HOLD CAPS LOCK"))
                    Spacer()
                    Text(model.mapping.hold == .hyper ? "Hyper" : (model.mapping.hold.isEmpty ? model.t("不执行", "No action") : model.t("自定义", "Custom")))
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    modifierButton(.command, symbol: "⌘", name: "Command")
                    modifierButton(.control, symbol: "⌃", name: "Control")
                    modifierButton(.option, symbol: "⌥", name: "Option")
                    modifierButton(.shift, symbol: "⇧", name: "Shift")
                }
                Text(model.t("选中的修饰键会一起按下；松开 Caps 即释放。", "Selected modifiers stay down until you release Caps."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(model.t("长按判定", "Hold delay")).font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(Int((model.mapping.holdDelay * 1_000).rounded())) ms")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: $model.mapping.holdDelay, in: 0.1...0.4, step: 0.01)
                    .accessibilityLabel(model.t("长按判定时间", "Hold delay"))
                    .accessibilityValue("\(Int(model.mapping.holdDelay * 1000)) ms")
                HStack {
                    Text(model.t("更灵敏", "Quicker"))
                    Spacer()
                    Text(model.t("更从容", "More forgiving"))
                }.font(.system(size: 10)).foregroundStyle(.tertiary)
                Text(model.t("接其他键时立即触发，无需等待。", "Chords activate instantly, without waiting."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Divider()
            VStack(spacing: 17) {
                HStack {
                    Text(model.t("登录时启动", "Open at login")).font(.system(size: 12))
                    Spacer()
                    Toggle(model.t("登录时启动", "Open at login"), isOn: Binding(get: { model.launchAtLogin }, set: model.setLaunchAtLogin))
                        .labelsHidden().toggleStyle(.switch).controlSize(.mini)
                }
                if model.loginNeedsApproval {
                    Button(model.t("在系统设置中允许登录启动", "Allow in Login Items"), action: model.openLoginSettings)
                        .font(.system(size: 11)).buttonStyle(.link)
                }
                if let error = model.loginError { Text(error).font(.system(size: 11)).foregroundStyle(.orange) }
                HStack {
                    Label(model.t("语言", "Language"), systemImage: "globe").font(.system(size: 12))
                    Spacer()
                    Picker(model.t("语言", "Language"), selection: $model.language) {
                        Text(model.t("跟随系统", "System")).tag(AppLanguage.system)
                        Text("简体中文").tag(AppLanguage.zh)
                        Text("English").tag(AppLanguage.en)
                    }.labelsHidden().frame(width: 145)
                }
            }
            HStack {
                Button(model.t("恢复默认映射", "Reset mapping"), action: model.resetMapping)
                    .buttonStyle(.plain).font(.system(size: 11)).disabled(model.mapping == Mapping())
                Spacer()
                Text("CapsLock Bye 1.0").font(.system(size: 10)).foregroundStyle(.tertiary)
            }.padding(.top, 2)
        }
        .padding(24).frame(width: 390)
        .tint(.primary)
        .sheet(isPresented: $showRecorder) { ShortcutRecorderSheet(model: model) }
        .focusEffectDisabled()
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
    }

    private func modifierButton(_ modifier: Modifiers, symbol: String, name: String) -> some View {
        let selected = model.mapping.hold.contains(modifier)
        return Button {
            if selected { model.mapping.hold.remove(modifier) }
            else { model.mapping.hold.insert(modifier) }
        } label: {
            VStack(spacing: 5) {
                Text(symbol).font(.system(size: 23, weight: .regular))
                Text(name).font(.system(size: 9))
            }.frame(maxWidth: .infinity).padding(.vertical, 11)
                .foregroundStyle(selected ? Color.primary : .secondary)
                .background(Color.primary.opacity(selected ? 0.06 : 0.02), in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(selected ? 0.18 : 0), lineWidth: 1))
        }.buttonStyle(.plain).accessibilityLabel(name)
            .accessibilityValue(selected ? model.t("已选中", "Selected") : model.t("未选中", "Not selected"))
            .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
