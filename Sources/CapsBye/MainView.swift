import SwiftUI
import AppKit
import CapsCore

struct MainView: View {
    @ObservedObject var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSettings = false
    @State private var showPermissions = false
    @State private var showTest = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: NSImage(named: "AppIcon") ?? NSApplication.shared.applicationIconImage)
                    .resizable().interpolation(.high).scaledToFit()
                    .frame(width: 32, height: 24).accessibilityHidden(true)
                Text("CapsLock Bye").font(.system(size: 15, weight: .semibold)).tracking(-0.4)
                Spacer()
                Toggle(model.t("开启映射", "Enable mapping"), isOn: $model.enabled)
                    .labelsHidden().toggleStyle(.switch).controlSize(.mini)
            }
            mapping.padding(.top, 27).padding(.bottom, 25)
            Divider().opacity(0.6)
            connection.padding(.top, 14)
            Spacer(minLength: 18)
            HStack {
                Button { showTest = true } label: {
                    Label(model.t("测试按键", "Test keys"), systemImage: "keyboard")
                }
                .disabled(!model.authorized)
                Spacer()
                Button { showSettings = true } label: {
                    Label(model.t("设置", "Settings"), systemImage: "slider.horizontal.3")
                }
            }
            .font(.system(size: 11)).buttonStyle(.plain).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 23).padding(.top, 16).padding(.bottom, 20)
        .frame(width: 360, height: 310)
        .background(WindowMaterial().ignoresSafeArea())
        .tint(.primary)
        .sheet(isPresented: $showSettings) { SettingsView(model: model) }
        .sheet(isPresented: $showPermissions) { PermissionView(model: model) }
        .sheet(isPresented: $showTest) { KeyboardTestView(model: model) }
        .focusEffectDisabled()
        .environment(\.locale, Locale(identifier: model.chinese ? "zh-Hans" : "en"))
    }

    private var mapping: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 13) {
                Text("⇪").font(.system(size: 33, weight: .regular))
                Text("caps lock").font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
            }
            .padding(.leading, 17).frame(width: 91, height: 94, alignment: .leading)
            .modifier(GlassPlate(radius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(.primary.opacity(model.pressed ? 0.35 : 0.06), lineWidth: 1))
            .scaleEffect(model.pressed ? 0.95 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: model.pressed)
            Image(systemName: "arrow.right").font(.system(size: 11, weight: .regular)).foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 17) {
                output(model.t("轻点", "Tap"), value: model.mapping.tap.display, active: model.lastTap != nil)
                output(model.t("按住", "Hold"), value: model.mapping.hold.isEmpty ? "—" : model.mapping.hold.symbols, active: model.holding)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(model.t("Caps Lock，轻点", "Caps Lock, tap for ") + model.mapping.tap.display + model.t("，按住", ", hold for ") + model.mapping.hold.symbols)
    }

    private func output(_ label: String, value: String, active: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 21, weight: .medium)).tracking(value == model.mapping.hold.symbols ? 2 : 0)
                .lineLimit(1).minimumScaleFactor(0.6)
                .foregroundStyle(active ? Color.green : Color.primary)
        }
    }

    private var connection: some View {
        Button { showPermissions = true } label: {
            HStack(alignment: .top, spacing: 8) {
                Circle().fill(statusColor).frame(width: 5, height: 5).padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.status).font(.system(size: 11, weight: .medium))
                    if model.awaitingCaps {
                        Text(model.t("其他改键工具可能已转换 Caps。", "Another app may be remapping Caps."))
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if !model.authorized || model.failure != nil || model.awaitingCaps {
                    Text(model.t("检查", "Review")).font(.system(size: 10)).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(.tertiary)
                } else {
                    Image(systemName: "checkmark.shield").font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityHint(model.t("检查权限和键盘连接", "Review permissions and keyboard connection"))
    }

    private var statusColor: Color {
        if !model.enabled { return .secondary }
        return model.running && !model.awaitingCaps ? .green : .orange
    }
}

struct GlassPlate: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

struct WindowMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
