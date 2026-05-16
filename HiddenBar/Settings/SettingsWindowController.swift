import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let settings: SettingsStore
    private let launchAtLogin: LaunchAtLoginManager

    init(settings: SettingsStore, launchAtLogin: LaunchAtLoginManager) {
        self.settings = settings
        self.launchAtLogin = launchAtLogin

        let rootView = SettingsView(settings: settings, launchAtLogin: launchAtLogin)
        let hosting = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hosting)
        window.title = "HiddenBar Preferences"
        window.styleMask = [.titled, .closable, .resizable, .miniaturizable]
        window.setContentSize(NSSize(width: 500, height: 420))
        window.isReleasedWhenClosed = false
        window.center()
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .preference

        super.init(window: window)

        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func present() {
        launchAtLogin.refresh()
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
