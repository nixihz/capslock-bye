import AppKit
import Combine
import SwiftUI

@main
struct CapsByeApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    private var observation: AnyCancellable?
    private var terminationSignals: [DispatchSourceSignal] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second launch should focus the existing copy instead of installing
        // two keyboard event taps (also applies to login-item launches).
        let other = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "tech.keli.capslock-bye")
            .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let other { other.activate(); NSApp.terminate(nil); return }
        NSApp.setActivationPolicy(.accessory)
        for number in [SIGTERM, SIGINT] {
            signal(number, SIG_IGN)
            let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
            source.setEventHandler { NSApp.terminate(nil) }
            source.resume()
            terminationSignals.append(source)
        }
        configureMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "capslock", accessibilityDescription: "CapsLock Bye")
            button.target = self
            button.action = #selector(statusClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in self?.updateStatus() }
        }
        model.start()
        updateStatus()
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin || !model.authorized { showWindow() }
    }

    func applicationWillTerminate(_ notification: Notification) { model.stop() }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateNow }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }

    private func configureMenu() {
        let menu = NSMenu()
        let item = NSMenuItem()
        let appMenu = NSMenu()
        let quit = NSMenuItem(title: model.t("退出 CapsLock Bye", "Quit CapsLock Bye"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        appMenu.addItem(quit)
        item.submenu = appMenu
        menu.addItem(item)
        NSApp.mainMenu = menu
    }

    private func updateStatus() {
        statusItem?.button?.appearsDisabled = !model.running
        statusItem?.button?.toolTip = "CapsLock Bye · " + model.status
        NSApp.mainMenu?.items.first?.submenu?.items.first?.title = model.t("退出 CapsLock Bye", "Quit CapsLock Bye")
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: model.enabled ? model.t("暂停映射", "Pause mapping") : model.t("开启映射", "Enable mapping"), action: #selector(toggleEnabled), keyEquivalent: "").target = self
            menu.addItem(withTitle: model.t("打开 CapsLock Bye", "Open CapsLock Bye"), action: #selector(showWindow), keyEquivalent: "").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: model.t("退出", "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
        } else { showWindow() }
    }

    @objc private func toggleEnabled() { model.enabled.toggle() }

    @objc private func showWindow() {
        if window == nil {
            let content = MainView(model: model)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 360, height: 310),
                styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            window.title = "CapsLock Bye"
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isReleasedWhenClosed = false
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.isOpaque = false
            window.contentView = NSHostingView(rootView: content)
            window.center()
            window.setFrameAutosaveName("CapsByeCompact")
            window.setContentSize(NSSize(width: 360, height: 310))
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
