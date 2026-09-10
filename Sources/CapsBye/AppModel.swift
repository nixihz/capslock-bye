import AppKit
import CapsCore
import Carbon
import Combine
import IOKit.hidsystem
import ServiceManagement

enum AppLanguage: String, CaseIterable { case system, zh, en }

final class AppModel: ObservableObject {
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled"); reconcile() } }
    @Published var mapping: Mapping {
        didSet {
            engine.mapping = mapping.validated
            if let data = try? JSONEncoder().encode(mapping.validated) { defaults.set(data, forKey: "mapping") }
        }
    }
    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: "language") } }
    @Published private(set) var accessibility = false
    @Published private(set) var inputMonitoring = false
    @Published private(set) var running = false
    @Published private(set) var usingVirtualKeyboard = false
    @Published private(set) var hasReceivedCaps = false
    @Published private(set) var secureInput = false
    @Published private(set) var failure: KeyboardEngine.Failure?
    @Published private(set) var pressed = false
    @Published private(set) var holding = false
    @Published private(set) var lastTap: String?
    @Published private(set) var launchAtLogin = false
    @Published private(set) var loginNeedsApproval = false
    @Published var loginError: String?
    @Published var recording = false { didSet { reconcile() } }
    private var sleeping = false
    private let defaults: UserDefaults
    private let engine = KeyboardEngine()
    private var permissionTimer: Timer?
    private var feedbackTimer: Timer?
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        mapping = defaults.data(forKey: "mapping").flatMap { try? JSONDecoder().decode(Mapping.self, from: $0) }?.validated ?? Mapping()
        language = AppLanguage(rawValue: defaults.string(forKey: "language") ?? "system") ?? .system
        engine.mapping = mapping
        engine.onActivity = { [weak self] activity in
            guard let self else { return }
            switch activity {
            case .pressed: self.pressed = true; self.hasReceivedCaps = true; self.lastTap = nil
            case .holding: self.holding = true
            case .released: self.pressed = false; self.holding = false
            case .tapped(let label):
                self.lastTap = label
                self.feedbackTimer?.invalidate()
                self.feedbackTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in self?.lastTap = nil }
            }
        }
        engine.onInterruption = { [weak self] in
            guard let self else { return }
            self.engine.stop()
            self.failure = nil
            self.refreshPermissions()
        }
    }

    var chinese: Bool {
        language == .zh || (language == .system && (Locale.preferredLanguages.first ?? "en").hasPrefix("zh"))
    }
    func t(_ zh: String, _ en: String) -> String { chinese ? zh : en }
    var authorized: Bool { accessibility && inputMonitoring }
    var awaitingCaps: Bool { running && usingVirtualKeyboard && !hasReceivedCaps }
    var status: String {
        if !enabled { return t("已暂停", "Paused") }
        if !authorized { return t("等待授权", "Setup needed") }
        if secureInput { return t("安全输入中", "Secure input") }
        if recording { return t("录制快捷键", "Recording") }
        if failure != nil { return t("需要检查", "Needs attention") }
        if awaitingCaps { return t("等待 Caps 输入", "Waiting for Caps") }
        return running ? t("已开启", "Active") : t("已暂停", "Paused")
    }
    var failureMessage: String {
        switch failure {
        case .eventTap:
            return t("辅助功能尚未生效。请在系统设置中重新打开 CapsLock Bye 的开关，再点重试。", "Accessibility is not active yet. Toggle CapsLock Bye off and on in System Settings, then retry.")
        case .inputMonitoring:
            return t("输入监控尚未生效。授权后请退出并重新打开 CapsLock Bye。", "Input Monitoring is not active yet. Quit and reopen CapsLock Bye after granting access.")
        case .capsLockControl:
            return t("暂时无法连接系统键盘服务，请重试。", "Could not connect to the keyboard service. Please retry.")
        case .keyboardUnavailable:
            return t("暂时无法访问键盘。请退出其他键盘改键工具，再点重试。", "Could not access the keyboard. Quit other key-remapping apps, then retry.")
        case nil: return ""
        }
    }

    func start() {
        refreshPermissions()
        permissionTimer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.refreshPermissions() }
        RunLoop.main.add(permissionTimer!, forMode: .common)
        observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.refreshPermissions() })
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = true; self?.reconcile()
        })
        observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false; self?.retry()
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = true; self?.reconcile()
        })
        observers.append(center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.sleeping = false; self?.retry()
        })
    }

    func stop() {
        permissionTimer?.invalidate()
        feedbackTimer?.invalidate()
        engine.stop()
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observers.removeAll()
    }

    func refreshPermissions() {
        let ax = AXIsProcessTrusted()
        let input = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        if ax != accessibility || input != inputMonitoring { failure = nil }
        if ax != accessibility { accessibility = ax }
        if input != inputMonitoring { inputMonitoring = input }
        let secure = IsSecureEventInputEnabled()
        if secure != secureInput { secureInput = secure }
        let loginStatus = SMAppService.mainApp.status
        let login = loginStatus == .enabled
        if launchAtLogin != login { launchAtLogin = login }
        let needsApproval = loginStatus == .requiresApproval
        if loginNeedsApproval != needsApproval { loginNeedsApproval = needsApproval }
        reconcile()
    }

    func retry() { failure = nil; refreshPermissions() }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Privacy_Accessibility")
    }

    func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openPrivacy("Privacy_ListenEvent")
    }

    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?" + pane) { NSWorkspace.shared.open(url) }
    }

    func revealApp() { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }

    func relaunch() {
        // Wait for this process to finish releasing modifiers before opening a
        // new copy. Positional arguments keep paths out of shell source.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.1; done; /usr/bin/open -n \"$2\"",
                             "capslock-bye-relaunch", String(ProcessInfo.processInfo.processIdentifier), Bundle.main.bundlePath]
        do { try process.run(); NSApp.terminate(nil) }
        catch { NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL]) }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = t("无法更新登录项。请将应用放入“应用程序”文件夹后重试。", "Could not update login items. Move the app to Applications and try again.")
        }
        refreshPermissions()
    }

    func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    func resetMapping() { mapping = Mapping() }

    private func reconcile() {
        let shouldRun = enabled && authorized && !secureInput && !sleeping && !recording
        if !shouldRun {
            if engine.isRunning { engine.stop() }
        } else if !engine.isRunning && failure == nil {
            do { try engine.start() }
            catch { failure = error as? KeyboardEngine.Failure ?? .eventTap }
        }
        if running != engine.isRunning { running = engine.isRunning }
        if usingVirtualKeyboard != engine.usingVirtualKeyboard { usingVirtualKeyboard = engine.usingVirtualKeyboard }
        if hasReceivedCaps != engine.hasReceivedCaps { hasReceivedCaps = engine.hasReceivedCaps }
    }
}
