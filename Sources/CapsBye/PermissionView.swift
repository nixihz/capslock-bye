import SwiftUI

struct PermissionView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text(model.t("权限与键盘", "Permissions & keyboard")).font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("\(Int(model.accessibility) + Int(model.inputMonitoring)) / 2")
                    .font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            }
            Text(model.t("开启以下两项权限，返回后自动检查。", "Enable both permissions. We’ll check when you return."))
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(spacing: 0) {
                permissionRow(number: "1", title: model.t("辅助功能", "Accessibility"),
                    subtitle: model.t("把 Caps 转换为 Esc 和组合键。", "Lets Caps send Escape and modifier keys."),
                    granted: model.accessibility, action: model.requestAccessibility)
                Divider().padding(.leading, 44).padding(.vertical, 18)
                permissionRow(number: "2", title: model.t("输入监控", "Input Monitoring"),
                    subtitle: model.t("识别 Caps 的按下与松开。", "Detects when Caps is pressed and released."),
                    granted: model.inputMonitoring, action: model.requestInputMonitoring)
            }.padding(18).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 9) {
                Text(model.t("在系统设置中，打开 CapsLock Bye 旁的开关。", "In System Settings, turn on the switch next to CapsLock Bye."))
                    .font(.system(size: 12, weight: .medium))
                Text(model.t("列表里没有？点“+”添加当前应用。输入监控授权后，macOS 可能要求退出并重新打开。", "Not listed? Use + to add this app. macOS may ask you to quit and reopen after enabling Input Monitoring."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(model.t("在 Finder 中显示应用", "Show app in Finder"), action: model.revealApp).buttonStyle(.link).font(.system(size: 11))
            }
            if model.failure != nil {
                Text(model.failureMessage).font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                if model.authorized {
                    Button(model.t("重新打开 CapsLock Bye", "Reopen CapsLock Bye"), action: model.relaunch)
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
            if model.usingVirtualKeyboard {
                Text(model.t("其他键盘工具仍在处理 Caps。请停用它的 Caps 映射，或退出该工具后重新测试。", "Another keyboard app is handling Caps. Disable its Caps mapping, or quit that app, then test again."))
                    .font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 7) {
                Image(systemName: "lock.shield").font(.system(size: 12))
                Text(model.t("不保存输入内容，不连接网络。", "No keystroke storage. No network access."))
                    .font(.system(size: 10))
            }.foregroundStyle(.secondary)
            HStack {
                Button(model.t("重新检查", "Check again"), action: model.retry).buttonStyle(.plain)
                Spacer()
                Button(model.authorized ? model.t("完成", "Done") : model.t("稍后设置", "Set up later")) { dismiss() }
                    .keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
                    .tint(.accentColor)
            }.controlSize(.regular)
        }.padding(24).frame(width: 390).tint(.primary)
        .focusEffectDisabled()
    }

    private func permissionRow(number: String, title: String, subtitle: String, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.system(size: 12, weight: .medium, design: .rounded))
                .frame(width: 26, height: 26).background(.primary.opacity(0.05), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    if granted {
                        Label(model.t("已授权", "Allowed"), systemImage: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(.green)
                    } else {
                        Button(model.t("去授权", "Allow"), action: action).controlSize(.small).buttonStyle(.bordered)
                    }
                }
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private extension Int { init(_ value: Bool) { self = value ? 1 : 0 } }
